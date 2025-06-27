#!/bin/bash

# Prompt for SQL Server SA password
read -s -p "Enter SQL Server 'sa' password: " SQL_SA_PASSWORD && echo

# Export to .env for later use
sed -i '/^export SQL_SA_PASSWORD=/d' .env 2>/dev/null
echo "export SQL_SA_PASSWORD=$SQL_SA_PASSWORD" >> .env

# Start SQL Server 2019 in Docker
docker run \
  -e "ACCEPT_EULA=Y" \
  -e "SA_PASSWORD=$SQL_SA_PASSWORD" \
  -p 1433:1433 \
  --name sqlsource \
  -d mcr.microsoft.com/mssql/server:2019-latest

# Create test database and insert data
docker exec -it sqlsource /opt/mssql-tools/bin/sqlcmd \
  -S localhost \
  -U sa \
  -P "$SQL_SA_PASSWORD" \
  -Q "CREATE DATABASE MyDatabase;
      USE MyDatabase;
      CREATE TABLE Users (id INT, name NVARCHAR(50));
      INSERT INTO Users VALUES (1, 'Alice'), (2, 'Bob');"

echo "✅ SQL Server Docker container started and test data