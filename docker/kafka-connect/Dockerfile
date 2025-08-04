FROM confluentinc/cp-kafka-connect:8.0.0

LABEL org.opencontainers.image.source=https://github.com/luinor223/lakepulse
LABEL org.opencontainers.image.description="Kafka Connect with Debezium for CDC in LakePulse data platform"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="luinor223"
LABEL org.opencontainers.image.licenses="Apache-2.0"

RUN echo "INFO: Installing Debezium and S3 connectors"
RUN confluent-hub install --no-prompt debezium/debezium-connector-postgresql:3.1.2

CMD [ "/etc/confluent/docker/run" ]