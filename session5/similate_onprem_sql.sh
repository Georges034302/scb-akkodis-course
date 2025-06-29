#!/bin/bash

echo "🚀 Simulating on-prem SQL Server setup in Docker..."
sleep 2
# Generate a random strong password for SQL Server 'sa'
SQL_SA_PASSWORD="P@ssw0rd$(date +%s%N | sha256sum | head -c 8)"
echo "🔑 Generated SQL Server 'sa' password: $SQL_SA_PASSWORD"

# Save to .env
sed -i '/^export SQL_SA_PASSWORD=/d' .env 2>/dev/null
echo "export SQL_SA_PASSWORD=$SQL_SA_PASSWORD" >> .env
echo "💾 Saved SQL_SA_PASSWORD to .env"

# Clean up
docker rm -f sqlsource 2>/dev/null
docker network rm sqlnet 2>/dev/null

# Step 1: Create Docker network
docker network create sqlnet

# Step: Start SQL Server
echo "🐳 Starting SQL Server container..."
docker run -d \
  --name sqlsource \
  --network sqlnet \
  -e "ACCEPT_EULA=Y" \
  -e "SA_PASSWORD=$SQL_SA_PASSWORD" \
  mcr.microsoft.com/mssql/server:2019-latest
echo "✅ SQL Server container started."

# Wait for startup
echo "⏳ Waiting for SQL Server to initialize..."
sleep 10

# Step 3: Create the database
echo "📦 Creating MyDatabase..."
docker run --rm \
  --network sqlnet \
  mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd \
  -S sqlsource -U sa -P "$SQL_SA_PASSWORD" -Q "CREATE DATABASE MyDatabase;"
echo "✅ MyDatabase created."

# Step 4: Create table + insert data inside MyDatabase
echo "🛠️ Inserting sample data into MyDatabase..."
docker run --rm \
  --network sqlnet \
  mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd \
  -S sqlsource -U sa -P "$SQL_SA_PASSWORD" -d MyDatabase -Q "
    CREATE TABLE Users (id INT, name NVARCHAR(50));
    INSERT INTO Users VALUES (1, 'Alice'), (2, 'Bob');"
echo "✅ Test data inserted into MyDatabase.Users."

# Step 5: Post-deployment test - query the Users table
echo "🔎 Testing MyDatabase.Users contents..."
docker run --rm \
  --network sqlnet \
  mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd \
  -S sqlsource -U sa -P "$SQL_SA_PASSWORD" -d MyDatabase -Q "SELECT * FROM Users;"
echo "✅ Post-deployment test completed."
