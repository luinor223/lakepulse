FROM apache/airflow:slim-3.0.3-python3.12
# Install system dependencies as root
USER root
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    g++ \
    openjdk-17-jdk-headless \
    wget \
    tar \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install Spark
ENV SPARK_VERSION=4.0.0 \
    HADOOP_VERSION=3 \
    SPARK_HOME=/opt/spark

RUN wget -qO spark.tgz https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && tar -xzf spark.tgz -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} ${SPARK_HOME} \
    && rm spark.tgz

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH="$PATH:${SPARK_HOME}/bin:${SPARK_HOME}/sbin"

# Copy requirements and install as airflow user
USER airflow
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

WORKDIR /opt/airflow