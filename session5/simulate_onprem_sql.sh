#!/bin/bash
set -e

echo "🚀 Simulating on-prem SQL Server setup in Docker..."

# Load environment variables
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found. Run ./init_env.sh first."
  exit 1
fi

# Validate required variables
for var in SQL_SA_USER SQL_SA_PASSWORD SQL_DB_NAME; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing $var in .env. Please run ./init_env.sh."
    exit 1
  fi
done

# Clean up previous runs
docker rm -f sqlsource 2>/dev/null || true
docker network rm sqlnet 2>/dev/null || true

# Step 1: Create Docker network
echo "🌐 Creating Docker network 'sqlnet'..."
docker network create sqlnet
echo "✅ Docker network 'sqlnet' created."

# Step 2: Start SQL Server container
echo "🐳 Starting SQL Server container..."
docker run -d \
  --name sqlsource \
  --network sqlnet \
  -e "ACCEPT_EULA=Y" \
  -e "SA_PASSWORD=$SQL_SA_PASSWORD" \
  -p 1433:1433 \
  mcr.microsoft.com/mssql/server:2019-latest
echo "✅ SQL Server container started."

# Wait for SQL Server to start
echo "⏳ Waiting for SQL Server to initialize..."
sleep 10

# Step 3: Create database
echo "📦 Creating $SQL_DB_NAME..."
docker run --rm \
  --network host \
  mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U "$SQL_SA_USER" -P "$SQL_SA_PASSWORD" \
  -Q "CREATE DATABASE [$SQL_DB_NAME];"
echo "✅ Database $SQL_DB_NAME created."

# Step 4: Insert sample data
echo "🛠️ Inserting sample data into $SQL_DB_NAME..."
docker run --rm \
  --network host \
  mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U "$SQL_SA_USER" -P "$SQL_SA_PASSWORD" -d "$SQL_DB_NAME" -Q "
    CREATE TABLE Users (id INT, name NVARCHAR(50));
    INSERT INTO Users VALUES (1, 'Alice'), (2, 'Bob');"
echo "✅ Test data inserted into $SQL_DB_NAME.Users."

# Step 5: Query inserted data
echo "🔎 Testing $SQL_DB_NAME.Users contents..."
echo "🔎 Testing $SQL_DB_NAME.Users contents..."
docker run --rm \
  --network host \
  mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U "$SQL_SA_USER" -P "$SQL_SA_PASSWORD" -d "$SQL_DB_NAME" -Q "SELECT * FROM Users;"
echo "✅ Post-deployment test completed."
