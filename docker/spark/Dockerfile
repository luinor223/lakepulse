FROM bitnami/spark:4.0.0-debian-12-r3

USER root

# Install prerequisites
RUN apt-get update && apt-get install -y wget
# Add Delta Lake & S3 support

ENV DELTA_VERSION=4.0.0 HADOOP_AWS_VERSION=3.4.1 SPARK_HOME=/opt/bitnami/spark
RUN mkdir -p ${SPARK_HOME}/jars && \
    wget -qO ${SPARK_HOME}/jars/delta-spark_2.13-${DELTA_VERSION}.jar \
      https://repo1.maven.org/maven2/io/delta/delta-spark_2.13/${DELTA_VERSION}/delta-spark_2.13-${DELTA_VERSION}.jar && \
      wget -qO ${SPARK_HOME}/jars/delta-storage-${DELTA_VERSION}.jar \
      https://repo1.maven.org/maven2/io/delta/delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar && \
    wget -qO ${SPARK_HOME}/jars/bundle-2.32.10.jar \
      https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.32.10/bundle-2.32.10.jar && \
    wget -qO ${SPARK_HOME}/jars/postgresql-42.7.7.jar \
      https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.7/postgresql-42.7.7.jar