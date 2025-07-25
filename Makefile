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
BRONZE_BUCKET := $(or $(BRONZE_BUCKET),lakepulse-bronze)
SILVER_BUCKET := $(or $(SILVER_BUCKET),lakepulse-silver)
GOLD_BUCKET := $(or $(GOLD_BUCKET),lakepulse-gold)

# Kafka Configuration
KAFKA_BROKER_HOST := $(or $(KAFKA_BROKER_HOST),kafka)
KAFKA_BROKER_PORT := $(or $(KAFKA_BROKER_PORT),9092)

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

## =================================================================
##@ Database Operations
## =================================================================

start-postgres: ## Start only PostgreSQL service
	@docker compose up -d postgres
	@echo "$(GREEN)Waiting for PostgreSQL to be ready...$(RESET)"
	@sleep 5

load-sample-data: ## Load sample data into PostgreSQL
	@if [ ! -f data/wide_world_importers_pg.dump ]; then \
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
		/data/wide_world_importers_pg.dump 2>&1 | grep -v "already exists\|does not exist"; then \
		echo "$(GREEN)✓ Sample data loaded successfully$(RESET)"; \
	else \
		echo "$(YELLOW)Database may already be loaded or restore completed with warnings$(RESET)"; \
	fi

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