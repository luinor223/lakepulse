-- Create debezium user with replication privileges
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'debezium') THEN
        CREATE ROLE debezium WITH REPLICATION LOGIN PASSWORD 'dbz';
        RAISE NOTICE 'Created debezium user';
    ELSE
        RAISE NOTICE 'debezium user already exists';
    END IF;
END
$$;

-- Grant database permissions (this script runs in the context of POSTGRES_DB)
GRANT ALL PRIVILEGES ON DATABASE wideworldimporters TO debezium;

-- Grant permissions for all schemas that exist in Wide World Importers
DO $$
DECLARE
    schema_name TEXT;
BEGIN
    -- Loop through all non-system schemas
    FOR schema_name IN 
        SELECT nspname 
        FROM pg_namespace 
        WHERE nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO debezium', schema_name);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO debezium', schema_name);
        EXECUTE format('GRANT SELECT ON ALL SEQUENCES IN SCHEMA %I TO debezium', schema_name);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO debezium', schema_name);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON SEQUENCES TO debezium', schema_name);
        
        RAISE NOTICE 'Granted permissions on schema: %', schema_name;
    END LOOP;
END
$$;

-- Create publication for logical replication (CDC)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_publication WHERE pubname = 'dbz_publication') THEN
        CREATE PUBLICATION dbz_publication FOR ALL TABLES;
        RAISE NOTICE 'Created publication dbz_publication';
    ELSE
        RAISE NOTICE 'Publication dbz_publication already exists';
    END IF;
END
$$;

-- Verify setup
SELECT 'Debezium CDC setup completed successfully!' as status;

-- Show summary of tables per schema
SELECT 
    schemaname,
    COUNT(*) as table_count
FROM pg_tables 
WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
GROUP BY schemaname
ORDER BY schemaname;
