CREATE ROLE debezium WITH REPLICATION LOGIN PASSWORD 'dbz';

GRANT ALL PRIVILEGES ON DATABASE wideworldimporters TO debezium;

-- Connect to the target database and grant schema permissions
\c wideworldimporters;

-- Grant permissions to debezium user for CDC
GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO debezium;

-- Create a publication for all tables (required for logical replication)
CREATE PUBLICATION dbz_publication FOR ALL TABLES;