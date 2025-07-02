#!/bin/bash
set -e

echo "🗄️ Creating source Azure SQL Server and populating database..."

# Load environment variables
echo "📦 Loading environment variables from .env..."
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found. Run ./init_env.sh first."
  exit 1
fi

# Create source SQL Server
echo "🛠️ Creating source SQL Server: $SQL_SOURCE_NAME ..."
az sql server create \
  --name "$SQL_SOURCE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$SQL_ADMIN_USER" \
  --admin-password "$SQL_ADMIN_PASSWORD"
echo "✅ Source SQL Server created."

# Create source DB
echo "🗄️ Creating source database: $SQL_DB_NAME ..."
az sql db create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SOURCE_NAME" \
  --name "$SQL_DB_NAME" \
  --service-objective S0
echo "✅ Source database created."

# Allow Azure services to access
echo "🌐 Creating firewall rule to allow Azure services..."
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SOURCE_NAME" \
  --name AllowAllAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
echo "✅ Firewall rule created."

# Insert demo data
echo "📝 Inserting demo data into $SQL_DB_NAME ..."
docker run --rm mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd -S "${SQL_SOURCE_NAME}.database.windows.net" \
  -U "$SQL_ADMIN_USER" -P "$SQL_ADMIN_PASSWORD" \
  -d "$SQL_DB_NAME" \
  -Q "CREATE TABLE Users (id INT PRIMARY KEY, name NVARCHAR(50)); INSERT INTO Users VALUES (1,'Alice'), (2,'Bob');"
echo "✅ Demo data inserted."

# Verify demo data
echo "🔎 Verifying demo data in $SQL_DB_NAME ..."
docker run --rm mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd -S "${SQL_SOURCE_NAME}.database.windows.net" \
  -U "$SQL_ADMIN_USER" -P "$SQL_ADMIN_PASSWORD" \
  -d "$SQL_DB_NAME" \
  -Q "SELECT * FROM Users;"
echo "✅ Data verification complete."

echo "🎉 Source SQL Server and database setup completed successfully."
