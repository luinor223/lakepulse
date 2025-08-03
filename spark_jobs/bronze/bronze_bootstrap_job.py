from pyspark.sql import SparkSession
import argparse
import sys
import logging

def create_spark_session(app_name: str = "LakepulseBronzeBootstrapFromJDBC") -> SparkSession:
    
    return SparkSession.builder \
        .appName(app_name) \
        .getOrCreate() \

def read_table_from_jdbc(spark: SparkSession, jdbc_url: str, dbtable: str, user: str, password: str, driver: str):
    
    return (
        spark.read
        .format("jdbc")
        .option("url", jdbc_url)
        .option("dbtable", dbtable)
        .option("user", user)
        .option("password", password)
        .option("driver", driver)
        .load()
    )

def add_cdc_columns(df):
    from pyspark.sql.functions import current_timestamp, lit

    return df.withColumn("operation", lit("insert")) \
        .withColumn("created_at", current_timestamp()) \
        .withColumn("updated_at", current_timestamp()) \
        .withColumn("is_deleted", lit(False))

def write_to_bronze(df, output_path: str, partition_by: str = ""):
    writer = df.write.format("delta").mode("overwrite")
    
    if partition_by and partition_by.strip():
        writer = writer.partitionBy(partition_by)
    
    writer.save(output_path)

def main(args):
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    logger = logging.getLogger("bronze_bootstrap_jdbc")

    logger.info("Creating Spark session...")
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")

    logger.info(f"Reading table `{args.dbtable}` from `{args.jdbc_url}`")
    df = read_table_from_jdbc(
        spark=spark,
        jdbc_url=args.jdbc_url,
        dbtable=args.dbtable,
        user=args.user,
        password=args.password,
        driver=args.driver
    )

    logger.info("Adding CDC columns...")
    df = add_cdc_columns(df)
    logger.info(f"DataFrame schema after adding CDC columns:\n{df.printSchema()}")

    logger.info(f"Writing to Delta path: {args.output_path}")
    write_to_bronze(df, args.output_path)

    logger.info("Bronze bootstrap completed.")
    spark.stop()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Bootstrap OLTP table into Delta Bronze via JDBC")
    parser.add_argument("--jdbc_url", required=True, help="JDBC URL of source database")
    parser.add_argument("--dbtable", required=True, help="Table name to extract")
    parser.add_argument("--user", required=True, help="Database username")
    parser.add_argument("--password", required=True, help="Database password")
    parser.add_argument("--driver", required=True, help="JDBC driver class (e.g., org.postgresql.Driver)")
    parser.add_argument("--output_path", required=True, help="Delta Lake bronze output path")
    parser.add_argument("--partition_by", default="", help="Partitioning column(s) for the delta table")
    args = parser.parse_args()

    main(args)