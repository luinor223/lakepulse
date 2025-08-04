include .env
.PHONY: help start stop logs clean restart
.DEFAULT_GOAL := help

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

## =================================================================
##@ Configuration
## =================================================================

COMPOSE_FILE := docker compose.yml
POSTGRES_DB := $(or $(POSTGRES_DB),wideworldimporters)
POSTGRES_USER := $(or $(POSTGRES_USER),user)
POSTGRES_PASSWORD := $(or $(POSTGRES_PASSWORD),password)

# MinIO Configuration
MINIO_ROOT_USER := $(or $(MINIO_ROOT_USER),minio)
MINIO_ROOT_PASSWORD := $(or $(MINIO_ROOT_PASSWORD),minio123)

# Spark Configuration
SPARK_MASTER_HOST := $(or $(SPARK_MASTER_HOST),spark-master)

# Airflow Configuration
AIRFLOW_USERNAME := $(or $(AIRFLOW_USERNAME),admin)
AIRFLOW_PASSWORD := $(or $(AIRFLOW_PASSWORD),admin)

help: ## Show this help message
	@echo "$(CYAN)LakePulse - Data Lakehouse Pipeline$(RESET)"
	@echo ""
	@echo "$(GREEN)Available commands:$(RESET)"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

## =================================================================
##@ Service Management
## =================================================================

init: ## Initialize the project
	@echo "$(GREEN)Downloading dependencies...$(RESET)"
	@wget ./docker/kafka/plugins https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/3.2.0.Final/debezium-connector-postgres-3.2.0.Final-plugin.tar.gz
	@echo "$(GREEN)Initializing LakePulse project...$(RESET)"
	@docker compose pull
	@echo "$(GREEN)✓ Project initialized$(RESET)"
	@$(MAKE) build-all

start: ## Start all services
	@echo "$(GREEN)Starting LakePulse services...$(RESET)"
	@docker compose up -d
	@echo "$(GREEN)✓ Services started$(RESET)"
	@$(MAKE) status
	@$(MAKE) services-info

stop: ## Stop all services
	@echo "$(YELLOW)Stopping LakePulse services...$(RESET)"
	@docker compose down
	@echo "$(GREEN)✓ Services stopped$(RESET)"

clean-volumes: ## Remove all project volumes
	@echo "$(RED)WARNING: This will DELETE ALL DATA!$(RESET)"
	@echo "$(RED)This includes PostgreSQL database and MinIO files$(RESET)"
	@read -p "Are you absolutely sure? Type 'DELETE' to confirm: " confirm; \
    if [ "$$confirm" = "DELETE" ]; then \
        echo "$(YELLOW)Removing all volumes...$(RESET)"; \
        docker compose down -v --remove-orphans; \
        echo "$(GREEN)✓ All volumes removed$(RESET)"; \
    else \
        echo "$(GREEN)Operation cancelled$(RESET)"; \
    fi

restart: stop start ## Restart all services

status: ## Show service status
	@echo "$(CYAN)Service Status:$(RESET)"
	@docker compose ps

logs: ## Show logs for all services
	@docker compose logs -f

logs-service: ## Show logs for specific service (usage: make logs-service SERVICE=postgres)
	@docker compose logs -f $(SERVICE)

build-all: ## Build all custom images
	@echo "$(GREEN)Building all images...$(RESET)"
	@$(MAKE) build-spark
	@$(MAKE) build-airflow
	@$(MAKE) build-kafka-connect
	@echo "$(GREEN)✓ All images built$(RESET)"

build-spark: ## Build Spark image
	@echo "$(GREEN)Building Spark image...$(RESET)"
	@docker build -t lakepulse/spark:latest docker/spark/
	@echo "$(GREEN)✓ Spark image built$(RESET)"

build-airflow: ## Build Airflow image
	@echo "$(GREEN)Building Airflow image...$(RESET)"
	@docker build -t lakepulse/airflow:latest docker/airflow/
	@echo "$(GREEN)✓ Airflow image built$(RESET)"

build-kafka-connect: ## Build Kafka Connect image
	@echo "$(GREEN)Building Kafka Connect image...$(RESET)"
	@docker build -t lakepulse/kafka-connect:latest docker/kafka-connect/
	@echo "$(GREEN)✓ Kafka Connect image built$(RESET)"

services-info: ## Show all service URLs and credentials
	@echo "$(CYAN)LakePulse Services:$(RESET)"
	@echo "• PostgreSQL:     localhost:5432 (user/password)"
	@echo "• MinIO API:      localhost:9000 (minio/minio123)"
	@echo "• MinIO Console:  localhost:9001 (minio/minio123)"
	@echo "• Airflow:        localhost:8080 (admin/admin)"
	@echo "• Spark UI:       localhost:4040"
	@echo "• Trino:          localhost:8081 (admin/no password)"
	@echo "• Jupyter:        localhost:8888 (use token from logs)"
	@echo "• Kafka:          localhost:9092"

## =================================================================
##@ Database Operations
## =================================================================

start-postgres: ## Start only PostgreSQL service
	@docker compose up -d postgres
	@echo "$(GREEN)Waiting for PostgreSQL to be ready...$(RESET)"
	@sleep 5

load-sample-data: ## Load sample data into PostgreSQL
	@if [ ! -f data/oltp/wide_world_importers_pg.dump ]; then \
        echo "$(YELLOW)Sample data dump not found, please check data/README.md to download it.$(RESET)"; \
        exit 1; \
    fi
	@echo "$(GREEN)Loading Wide World Importers database...$(RESET)"
	@sleep 5  # Wait for PostgreSQL to be ready
	@if docker exec -i $$(docker compose ps -q postgres) pg_restore \
		--username=$(POSTGRES_USER) \
		--dbname=$(POSTGRES_DB) \
		--verbose \
		--clean \
		--no-acl \
		--no-owner \
		/data/oltp/wide_world_importers_pg.dump 2>&1 | grep -v "already exists\|does not exist"; then \
		echo "$(GREEN)✓ Sample data loaded successfully$(RESET)"; \
	else \
		echo "$(YELLOW)Database may already be loaded or restore completed with warnings$(RESET)"; \
	fi
	@$(MAKE) grant-permissions

grant-permissions: ## Grant permissions to debezium user
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "GRANT USAGE ON SCHEMA application TO debezium;"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "GRANT USAGE ON SCHEMA purchasing TO debezium;"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "GRANT USAGE ON SCHEMA sales TO debezium;"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "GRANT USAGE ON SCHEMA warehouse TO debezium;"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "GRANT SELECT ON ALL TABLES IN SCHEMA application TO debezium;"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "GRANT SELECT ON ALL TABLES IN SCHEMA purchasing TO debezium;"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "GRANT SELECT ON ALL TABLES IN SCHEMA sales TO debezium;"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "GRANT SELECT ON ALL TABLES IN SCHEMA warehouse TO debezium;"

test-db-connection: ## Test database connectivity
	@echo "$(GREEN)Testing database connection...$(RESET)"
	@docker exec $$(docker compose ps -q postgres) psql \
		-U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT 'Connection successful!' as status;"

verify-data: ## Verify loaded data
	@echo "$(GREEN)Verifying data load...$(RESET)"
	@docker exec $$(docker compose ps -q postgres) psql \
		-U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT schemaname, relname, n_tup_ins FROM pg_stat_user_tables WHERE n_tup_ins > 0 ORDER BY schemaname;"

db-shell: ## Connect to database shell
	@docker exec -it $$(docker compose ps -q postgres) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

## =================================================================
##@ Airflow Operations
## =================================================================

init-airflow: ## Initialize Airflow database and create admin user
	@echo "$(GREEN)Initializing Airflow...$(RESET)"
	@docker compose up -d airflow-init
	@echo "$(GREEN)✓ Airflow initialized$(RESET)"

start-airflow: ## Start Airflow services
	@echo "$(GREEN)Starting Airflow services...$(RESET)"
	@docker compose up -d airflow-apiserver airflow-scheduler airflow-dag-processor airflow-worker airflow-triggerer
	@echo "$(GREEN)✓ Airflow services started$(RESET)"

trigger-dag: ## Trigger a DAG (usage: make trigger-dag DAG=bronze_bootstrap_load)
	@if [ -z "$(DAG)" ]; then \
		echo "$(RED)Please specify a DAG: make trigger-dag DAG=bronze_bootstrap_load$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Triggering DAG: $(DAG)$(RESET)"
	@docker exec $$(docker compose ps -q airflow-api-server) airflow dags trigger $(DAG)

airflow-refresh-dags: ## Refresh Airflow DAG cache
	@echo "$(GREEN)Refreshing Airflow DAGs...$(RESET)"
	@docker exec lakepulse-airflow-1 airflow dags reserialize
	@echo "$(GREEN)✓ DAGs refreshed$(RESET)"

airflow-reset: ## Reset Airflow completely
	@echo "$(YELLOW)Resetting Airflow...$(RESET)"
	@docker stop lakepulse-airflow-scheduler lakepulse-airflow-api-server || true
	@docker rm lakepulse-airflow-init lakepulse-airflow-scheduler lakepulse-airflow-api-server || true
	@docker compose up airflow-init
	@docker compose up -d airflow-api-server airflow-scheduler
	@echo "$(GREEN)✓ Airflow reset completed$(RESET)"

list-dags: ## List all Airflow DAGs
	@echo "$(CYAN)Airflow DAGs:$(RESET)"
	@docker exec lakepulse-airflow-scheduler airflow dags list

check-dag-errors: ## Check for DAG import errors
	@echo "$(CYAN)Checking DAG import errors...$(RESET)"
	@docker exec lakepulse-airflow-scheduler airflow dags list-import-errors

dag-status: check-dag-errors list-dags ## Check DAG status (errors + list)

dag-logs: ## View DAG logs (usage: make dag-logs DAG=bronze_bootstrap_load TASK=run_bronze_bootstrap_spark)
	@if [ -z "$(DAG)" ] || [ -z "$(TASK)" ]; then \
		echo "$(RED)Please specify DAG and TASK: make dag-logs DAG=bronze_bootstrap_load TASK=run_bronze_bootstrap_spark$(RESET)"; \
		exit 1; \
	fi
	@docker exec $$(docker compose ps -q airflow-api-server) airflow tasks logs $(DAG) $(TASK) $$(date +%Y-%m-%d)

test-dag: ## Test a DAG without scheduling (usage: make test-dag DAG=bronze_bootstrap_load)
	@if [ -z "$(DAG)" ]; then \
		echo "$(RED)Please specify a DAG: make test-dag DAG=bronze_bootstrap_load$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Testing DAG: $(DAG)$(RESET)"
	@docker exec $$(docker compose ps -q airflow-api-server) airflow dags test $(DAG) $$(date +%Y-%m-%d)

## =================================================================
##@ Spark Operations
## =================================================================

start-spark:
	@echo "$(GREEN)Starting Spark services...$(RESET)"
	@docker compose up -d spark-master spark-worker
	@echo "$(GREEN)✓ Spark services started$(RESET)"

spark-shell: ## Connect to Spark master shell
	@docker exec -it $$(docker compose ps -q spark-master) /bin/bash

spark-submit: ## Submit a Spark job (usage: make spark-submit JOB=your_job.py)
	@echo "$(GREEN)Submitting Spark job: $(JOB)$(RESET)"
	@docker exec -it lakepulse-spark-master \
		spark-submit --master spark://$(SPARK_MASTER_HOST):7077 \
		--conf spark.jars.ivy=/tmp/.ivy \
		/opt/spark_jobs/$(JOB)


## =================================================================
##@ Kafka Operations
## =================================================================
start-kafka: ## Start Kafka service
	@echo "$(GREEN)Starting Kafka service...$(RESET)"
	@docker compose up -d broker schema-registry kafka-connect kafka-ui
	@echo "$(GREEN)Waiting for Kafka to be ready...$(RESET)"
	@sleep 10  # Wait for Kafka to initialize
	@echo "$(GREEN)✓ Kafka service started$(RESET)"

register-connector: ## Register a Kafka connector (usage: make register-connector CONNECTOR=your_connector.json)
	@if [ -z "$(CONNECTOR)" ]; then \
		echo "$(RED)Please specify a connector file: make register-connector CONNECTOR=your_connector.json$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Registering connector: $(CONNECTOR)$(RESET)"
	@curl -X POST \
	  http://localhost:8083/connectors \
	  -H 'Content-Type: application/json' \
	  -d @kafka/connectors/$(CONNECTOR)