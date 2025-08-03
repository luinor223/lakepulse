FROM apache/airflow:slim-3.0.3-python3.12
# Install system dependencies as root
USER root
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    g++ \
    openjdk-17-jdk-headless \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Copy requirements and install as airflow user
USER airflow
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

WORKDIR /opt/airflow