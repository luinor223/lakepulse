#!/bin/bash
set -e

echo "Loading Wide World Importers sample data..."

# Wait for PostgreSQL to be ready
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
done

# Check if data is already loaded
TABLES_COUNT=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'pg_catalog');")

if [ "$TABLES_COUNT" -gt 10 ]; then
    echo "Sample data already loaded (found $TABLES_COUNT tables), skipping..."
    exit 0
fi

# Load the dump file if it exists
if [ -f /data/oltp/wide_world_importers_pg.dump ]; then
    echo "Restoring Wide World Importers database..."
    
    # Restore the dump file
    pg_restore \
        --username="$POSTGRES_USER" \
        --dbname="$POSTGRES_DB" \
        --verbose \
        --clean \
        --no-acl \
        --no-owner \
        --if-exists \
        /data/oltp/wide_world_importers_pg.dump 2>&1 | grep -v "does not exist, skipping"
    
    echo "Sample data loaded successfully!"
    
    # Verify the load
    FINAL_COUNT=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('information_schema', 'pg_catalog');")
    echo "Loaded $FINAL_COUNT tables total"
    
else
    echo "Sample data dump not found at /data/oltp/wide_world_importers_pg.dump"
    echo "Please check data/README.md for download instructions"
    echo "Continuing without sample data..."
fi
