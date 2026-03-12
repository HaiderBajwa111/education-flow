#!/bin/bash

echo "Verifying database connection..."

if command -v docker >/dev/null 2>&1 && docker compose ps | grep -q 'education_flow_db'; then
    echo "Docker container education_flow_db is running."
    
    # Check if postgres is accepting connections
    if docker exec education_flow_db pg_isready -U dev_user -d education_flow > /dev/null 2>&1; then
        echo "✅ Database connection successful! PostgreSQL is ready to accept connections."
        exit 0
    else
        echo "❌ Database container is running, but PostgreSQL is not ready."
        exit 1
    fi
else
    echo "⚠️  Docker container 'education_flow_db' is not running."
    echo "Please run 'docker compose up -d db' to start the database."
    exit 1
fi
