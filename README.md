# LakePulse

> A production-grade, fully local data lakehouse pipeline implementing modern data engineering patterns

LakePulse is a comprehensive data lakehouse solution that demonstrates real-world data engineering practices using industry-standard technologies. Built for local development and learning, it implements Change Data Capture (CDC) simulation, real-time data processing, and the modern Bronze-Silver-Gold medallion architecture.

## Overview

LakePulse showcases a complete end-to-end data pipeline that:
- **Ingests** data from OLTP databases using simulated CDC
- **Processes** data through multiple layers (Bronze, Silver, Gold) 
- **Stores** data in Delta Lake format for ACID transactions
- **Orchestrates** workflows with Apache Airflow
- **Enables** analytics through SQL interfaces

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   OLTP Source   │───▶│    Kafka     │───▶│   Spark Jobs    │
│ (PostgreSQL)    │    │   (CDC)      │    │ (Bronze Layer)  │
└─────────────────┘    └──────────────┘    └─────────────────┘
                                                     │
                                                     ▼
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Analytics     │◀───│   Trino      │◀───│  Delta Lake     │
│  (Notebooks)    │    │  (Query)     │    │ Silver & Gold   │
└─────────────────┘    └──────────────┘    └─────────────────┘
                                                     ▲
                                                     │
                                            ┌─────────────────┐
                                            │     MinIO       │
                                            │  (S3 Storage)   │
                                            └─────────────────┘
```

## Quick Start

### Prerequisites

- Docker and Docker Compose
- 8GB+ RAM recommended
- 10GB+ free disk space

### 1. Clone and Setup

```bash
git clone https://github.com/yourusername/lakepulse.git
cd lakepulse
```

### 2. Environment Configuration

```bash
# Copy and customize environment variables
cp .env.example .env
```

### 3. Start the Stack

```bash
# Start all services
docker-compose up -d

# Check service health
docker-compose ps
```

### 4. Load Sample Data

```bash
# Load Wide World Importers database
make load-sample-data

# Verify data loading
make verify-setup
```

### 5. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Airflow | http://localhost:8080 | admin/admin |
| MinIO Console | http://localhost:9001 | minio/minio123 |
| Trino | http://localhost:8081 | admin/(no password) |
| Jupyter | http://localhost:8888 | (token in logs) |

## Data Flow

### Bronze Layer (Raw Data Ingestion)
- **Source**: PostgreSQL Wide World Importers database
- **Method**: Kafka-based CDC simulation
- **Format**: Parquet files in Delta Lake
- **Location**: `s3://lakepulse-bronze/`

### Silver Layer (Cleaned & Validated)
- **Transformations**: Data quality checks, schema enforcement
- **Deduplication**: Handling CDC duplicates and late arrivals
- **Format**: Delta Lake tables with history
- **Location**: `s3://lakepulse-silver/`

### Gold Layer (Business Ready)
- **Purpose**: Aggregated, business-focused datasets
- **Optimizations**: Partitioning, Z-ordering for query performance
- **Access**: Via Trino SQL interface
- **Location**: `s3://lakepulse-gold/`

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Storage** | MinIO | S3-compatible object storage |
| **Data Format** | Delta Lake | ACID transactions, time travel |
| **Processing** | Apache Spark | Distributed data processing |
| **Orchestration** | Apache Airflow | Workflow management |
| **Streaming** | Apache Kafka | Change data capture simulation |
| **Analytics** | Trino | Distributed SQL query engine |
| **Source DB** | PostgreSQL | OLTP database (Wide World Importers) |
| **Notebooks** | Jupyter | Interactive data analysis |

## Project Structure

```
lakepulse/
├── 📁 airflow/                 # Airflow DAGs and configuration
│   ├── dags/                   # Pipeline definitions
│   └── plugins/                 # Airflow settings
├── 📁 docker/                  # Service configurations
│   ├── airflow/                # Airflow Docker setup
│   ├── spark/                  # Spark cluster configuration
│   └── minio/                  # MinIO storage setup
├── 📁 spark_jobs/              # Data processing jobs
│   ├── bronze/                 # Raw data ingestion
│   ├── silver/                 # Data cleaning & validation
│   ├── gold/                   # Business aggregations
│   └── utils/                  # Shared utilities
├── 📁 data/                    # Sample datasets
├── 📁 great_expectations/      # GE project config, expectation suites, checkpoints
├── 📁 trinio/                  # Trino catalog configs (e.g. catalog/delta.properties)
├── 📁 notebooks/               # Jupyter notebooks for analysis
├── 📁 scripts/                 # Utility scripts
├── 🐳 docker-compose.yml       # Multi-service orchestration
├── 📋 Makefile                 # Common commands
└── 📖 README.md               # This file
```

## Development

### Running Individual Components

```bash
# Start only the database
docker-compose up postgres

# Run a specific Spark job
make run-bronze-job table=customers

# Monitor Kafka topics
make kafka-topics-list
```

### Data Pipeline Commands

```bash
# Trigger CDC simulation
make simulate-cdc table=customers

# Run medallion architecture pipeline
make run-pipeline table=customers

# Check data quality metrics
make data-quality-report
```

### Debugging and Monitoring

```bash
# View service logs
docker-compose logs -f spark-master

# Access Spark UI
open http://localhost:4040

# Monitor resource usage
docker stats
```

## Learning Objectives

This project demonstrates:

1. **Modern Data Architecture**: Medallion architecture with Bronze-Silver-Gold layers
2. **Real-time Processing**: Kafka-based streaming and CDC patterns  
3. **Data Lake Technologies**: Delta Lake, Parquet, and S3-compatible storage
4. **Workflow Orchestration**: Airflow DAGs for complex data pipelines
5. **Data Quality**: Validation, deduplication, and monitoring techniques
6. **Performance Optimization**: Partitioning, indexing, and query optimization
7. **DevOps Practices**: Containerization, infrastructure as code

### Development Setup

```bash
# Install development dependencies
make dev-setup

# Run tests
make test

# Format code
make format

# Run linting
make lint
```

## Troubleshooting

### Common Issues

**Services won't start:**
```bash
# Check available resources
docker system df
docker system prune  # Free up space if needed
```

**Data loading fails:**
```bash
# Verify database connection
make test-db-connection

# Check MinIO access
make test-minio-connection
```

**Performance issues:**
```bash
# Increase Docker resources in Docker Desktop
# Recommended: 4 CPUs, 8GB RAM

# Monitor resource usage
make monitor-resources
```

⭐ **Star this repository if you find it helpful!**
