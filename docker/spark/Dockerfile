FROM bitnami/spark:4.0.0-debian-12-r3

LABEL org.opencontainers.image.source=https://github.com/luinor223/lakepulse
LABEL org.opencontainers.image.description="Apache Spark with Delta Lake and S3 support for LakePulse data platform"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="luinor223"
LABEL org.opencontainers.image.licenses="Apache-2.0"

USER root

# Install prerequisites
RUN apt-get update && apt-get install -y wget
# Add Delta Lake & S3 support

ENV SCALA_VERSION=2.13 SPARK_VERSION=4.0.0 DELTA_VERSION=4.0.0 HADOOP_AWS_VERSION=3.4.1 KAFKA_VERSION=3.9.0
ENV SPARK_HOME=/opt/bitnami/spark
RUN mkdir -p ${SPARK_HOME}/jars && \
    # Delta Lake JARs
    wget -qO ${SPARK_HOME}/jars/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar \
      https://repo1.maven.org/maven2/io/delta/delta-spark_${SCALA_VERSION}/${DELTA_VERSION}/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar && \
    wget -qO ${SPARK_HOME}/jars/delta-storage-${DELTA_VERSION}.jar \
      https://repo1.maven.org/maven2/io/delta/delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar && \
    # AWS S3 (Minio) Support
    wget -qO ${SPARK_HOME}/jars/bundle-2.32.10.jar \
      https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.32.10/bundle-2.32.10.jar && \
    # PostgreSQL Driver
    wget -qO ${SPARK_HOME}/jars/postgresql-42.7.7.jar \
      https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.7/postgresql-42.7.7.jar && \
    # Kafka Dependencies
    wget -qO ${SPARK_HOME}/jars/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar && \
    wget -qO ${SPARK_HOME}/jars/kafka-clients-${KAFKA_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/${KAFKA_VERSION}/kafka-clients-${KAFKA_VERSION}.jar && \
    wget -qO ${SPARK_HOME}/jars/spark-token-provider-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-token-provider-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar && \
    wget -qO ${SPARK_HOME}/jars/commons-pool2-2.12.0.jar \
      https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.12.0/commons-pool2-2.12.0.jar
    # Avro Support
    
RUN wget -qO ${SPARK_HOME}/jars/spark-avro_${SCALA_VERSION}-${SPARK_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/spark/spark-avro_${SCALA_VERSION}/${SPARK_VERSION}/spark-avro_${SCALA_VERSION}-${SPARK_VERSION}.jar

COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt