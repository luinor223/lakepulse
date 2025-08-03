from datetime import datetime, timedelta
from airflow import DAG
from airflow.utils.task_group import TaskGroup
from airflow.operators.bash import BashOperator #type: ignore
from airflow.models.baseoperator import chain
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator #type: ignore
from airflow.models import Variable
import os
import yaml
import json
import logging

# ---------------------- Config ---------------------- #
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configuration
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres")
POSTGRES_PORT = os.getenv("POSTGRES_PORT", "5432")
POSTGRES_DB = os.getenv("POSTGRES_DB", "wideworldimporters")
POSTGRES_USER = os.getenv("POSTGRES_USER", "user")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "password")
JDBC_URL = f"jdbc:postgresql://{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
JDBC_DRIVER = "org.postgresql.Driver"

# MinIO/S3 configuration
S3_ENDPOINT = os.getenv("S3_ENDPOINT", "http://minio:9000")

def load_bronze_config():
    with open("/opt/airflow/config/bronze_schema.yml", "r") as f:
        config = yaml.safe_load(f)
    return config

# ------------------------- DAG Definition ------------------------- #
# Default arguments
default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

def task_failure_alert(context):
    """Send alert when task fails"""
    print(f"ALERT: Task {context['task_instance'].task_id} failed!")
    print(f"DAG: {context['dag'].dag_id}")
    print(f"Execution Date: {context['execution_date']}")
    # TODO: Add discord alert logic


# Define the DAG
dag = DAG(
    dag_id='bronze_bootstrap_load',
    default_args=default_args,
    description='Ingest data from OLTP Database into the Bronze layer using Spark',
    schedule=timedelta(days=1),
    catchup=False,
    tags=['lakepulse', 'bronze', 'bootstrap'],
    max_active_tasks=1,
    on_failure_callback=task_failure_alert
)

# Health check task to verify Spark cluster is ready
spark_health_check = BashOperator(
    task_id='spark_health_check',
    bash_command='''
    echo "Checking Spark cluster health..."
    curl -f http://spark-master:8080/json/ || exit 1
    echo "Spark cluster is healthy"
    ''',
    dag=dag,
)

# Health check task to verify MinIO is ready
minio_health_check = BashOperator(
    task_id='minio_health_check',
    bash_command='''
    echo "Checking MinIO health..."
    curl -f http://minio:9000/minio/health/live ||
    exit 1
    echo "MinIO is healthy"
    ''',
    dag=dag,
)

def create_spark_task(table_name: str, partition_by: str) -> SparkSubmitOperator:
    """Create SparkSubmitOperator with default configuration"""
    
    # Load default configurations from Airflow Variables
    try:
        spark_config = json.loads(Variable.get("spark_config", "{}"))
        spark_resources = json.loads(Variable.get("spark_resources", "{}"))
        spark_jars = Variable.get("spark_jars", "")
        logger.info(f"Using Spark config: {spark_config}")
    except Exception as e:
        logger.warning(f"Warning: Could not load Spark defaults from Variables: {e}")
        raise ValueError(f"Spark configuration variables not found: {e}") from e
    
    task_id = f"bronze_load_{table_name.replace('.', '_')}"
    output_path = f"s3a://lakepulse-dev/bronze/{table_name.replace('.', '/')}"
    
    return SparkSubmitOperator(
        task_id=task_id,
        application="/opt/spark_jobs/bronze/bronze_bootstrap_job.py",
        conn_id="spark_default",
        conf=spark_config,
        jars=spark_jars,
        verbose=True,
        application_args=[
            "--jdbc_url", JDBC_URL,
            "--dbtable", table_name,
            "--user", POSTGRES_USER,
            "--password", POSTGRES_PASSWORD,
            "--driver", JDBC_DRIVER,
            "--output_path", output_path,
            "--partition_by", partition_by if partition_by is not None else ""
        ],
        **spark_resources,  # Unpack executor_cores, executor_memory, etc.
        dag=dag,
    )

def create_bronze_load_tasks():
    """Create tasks for loading bronze tables based on configuration"""
    config = load_bronze_config()
    TABLES = config.get('tables', [])
    
    if not TABLES:
        raise ValueError("No tables found in bronze_tables.yml configuration")
    
    grouped_tasks = {}
    
    for t in TABLES:
        full_name = t["name"]
        schema, table = full_name.split(".")
        partition_by = t.get("partition_by", "")
        
        if schema not in grouped_tasks:
            grouped_tasks[schema] = []
        
        grouped_tasks[schema].append((table, partition_by))
    
    table_tasks = []
    
    for schema, tables in grouped_tasks.items():
        with TaskGroup(group_id=f"bronze_load_{schema}", dag=dag) as schema_group:
            for table_name, partition_by in tables:
                full_table = f"{schema}.{table_name}"
                task = create_spark_task(full_table, partition_by)
        table_tasks.append(schema_group)
    
    return table_tasks

# Create tasks for each table
bronze_load_tasks = create_bronze_load_tasks()
chain(*bronze_load_tasks)

spark_health_check >> minio_health_check >> bronze_load_tasks[0] #type: ignore