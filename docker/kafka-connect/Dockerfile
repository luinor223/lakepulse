FROM confluentinc/cp-kafka-connect:8.0.0

LABEL org.opencontainers.image.source=https://github.com/luinor223/lakepulse
LABEL org.opencontainers.image.description="Kafka Connect with Debezium for CDC in LakePulse data platform"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="luinor223"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Install connectors
RUN echo "INFO: Installing Debezium and S3 connectors"
RUN confluent-hub install --no-prompt debezium/debezium-connector-postgresql:3.1.2
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-s3:10.6.7

# Performance optimizations
ENV KAFKA_HEAP_OPTS="-Xmx2g -Xms2g"
ENV KAFKA_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=20"

CMD [ "/etc/confluent/docker/run" ]