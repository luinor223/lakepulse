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
	@echo "$(GREEN)Initializing LakePulse project...$(RESET)"
	@$(MAKE) build-spark
	@$(MAKE) build-airflow
	@$(MAKE) build-kafka-connect
	@echo "$(GREEN)✓ All images built$(RESET)"
	@echo "$(GREEN)✓ Project initialized$(RESET)"
	@$(MAKE) build-all

start: ## Start all services
	@echo "$(GREEN)Starting LakePulse services...$(RESET)"
	@docker compose up -d
	@echo "$(GREEN)✓ Services started$(RESET)"
	@$(MAKE) status

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

## =================================================================
##@ Database Operations
## =================================================================

start-postgres: ## Start only PostgreSQL service
	@docker compose up -d postgres
	@echo "$(GREEN)Waiting for PostgreSQL to be ready...$(RESET)"
	@sleep 10
	@$(MAKE) verify-database-setup

db-shell: ## Connect to database shell
	@docker exec -it $$(docker compose ps -q postgres) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

verify-database-setup: ## Verify database initialization completed (data + CDC setup)
	@echo "$(GREEN)Verifying database setup...$(RESET)"
	@echo "$(CYAN)Tables loaded per schema:$(RESET)"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT schemaname, COUNT(*) as table_count FROM pg_tables WHERE schemaname NOT IN ('information_schema', 'pg_catalog') GROUP BY schemaname ORDER BY schemaname;" || echo "No tables found"
	@echo "$(CYAN)Debezium user and replication:$(RESET)"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT rolname, rolreplication, rolcanlogin FROM pg_roles WHERE rolname = 'debezium';" || echo "Debezium user not found"
	@echo "$(CYAN)CDC Publication:$(RESET)"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SELECT pubname, puballtables FROM pg_publication WHERE pubname = 'dbz_publication';" || echo "Publication not found"
	@echo "$(CYAN)WAL Level:$(RESET)"
	@docker exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) \
		-c "SHOW wal_level;" || echo "WAL level not found"
	@echo "$(GREEN)✓ Database verification complete$(RESET)"

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

list-dags: ## List all Airflow DAGs
	@echo "$(CYAN)Airflow DAGs:$(RESET)"
	@docker exec lakepulse-airflow-scheduler airflow dags list


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
	@docker exec -it spark-master \
		spark-submit --master spark://$(SPARK_MASTER_HOST):7077 \
		--conf spark.jars.ivy=/tmp/.ivy \
		/opt/spark_jobs/$(JOB)

submit-bronze-cdc: ## Submit the Bronze CDC ingestion job
	@echo "$(GREEN)Submitting Bronze CDC ingestion job...$(RESET)"
	@docker exec -it spark-master \
		spark-submit --master spark://$(SPARK_MASTER_HOST):7077 \
		--conf spark.jars.ivy=/tmp/.ivy \
		/opt/spark_jobs/bronze/bronze_cdc_ingest_job.py

stop-spark: ## Stop Spark services
	@echo "$(YELLOW)Stopping Spark services...$(RESET)"
	@docker compose down spark-master spark-worker
	@echo "$(GREEN)✓ Spark services stopped$(RESET)"

## =================================================================
##@ Kafka Operations
## =================================================================
start-kafka: ## Start Kafka service
	@echo "$(GREEN)Starting Kafka service...$(RESET)"
	@docker compose up -d broker schema-registry kafka-connect kafka-ui
	@echo "$(GREEN)Waiting for Kafka to be ready...$(RESET)"
	@sleep 10  # Wait for Kafka to initialize
	@echo "$(GREEN)✓ Kafka service started$(RESET)"

stop-kafka: ## Stop Kafka service
	@echo "$(YELLOW)Stopping Kafka service...$(RESET)"
	@docker compose down broker schema-registry kafka-connect kafka-ui
	@echo "$(GREEN)✓ Kafka service stopped$(RESET)"

register-all-connectors: ## Register all connectors in kafka/connectors/ directory
	@echo "$(GREEN)Registering all connectors...$(RESET)"
	@for connector in kafka/connectors/*.json; do \
		echo "$(GREEN)Registering: $$connector$(RESET)"; \
		curl -s -X POST \
			http://localhost:8083/connectors \
			-H 'Content-Type: application/json' \
			-d @$$connector | jq '.' || echo "$(RED)Failed to register $$connector$(RESET)"; \
		sleep 2; \
	done
	@echo "$(GREEN)✓ All connectors registered$(RESET)"