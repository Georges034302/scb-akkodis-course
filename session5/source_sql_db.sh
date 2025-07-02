#!/bin/bash
set -e

echo "🗄️ Creating source Azure SQL Server and populating database..."

echo "📦 Loading environment variables from .env..."
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found. Run ./init_env.sh first."
  exit 1
fi

echo "🛠️ Creating source SQL Server: $SQL_SOURCE_SERVER ..."
az sql server create \
  --name "$SQL_SOURCE_SERVER" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$ADMIN_USER" \
  --admin-password "$ADMIN_PASSWORD"
echo "✅ Source SQL Server created."

echo "🗄️ Creating source database: $SQL_SOURCE_DB ..."
az sql db create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SOURCE_SERVER" \
  --name "$SQL_SOURCE_DB" \
  --service-objective S0
echo "✅ Source database created."

echo "🌐 Creating firewall rule to allow Azure services..."
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SOURCE_SERVER" \
  --name AllowAllAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
echo "✅ Firewall rule created."

echo "📝 Inserting demo data into $SQL_SOURCE_DB ..."
docker run --rm mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd -S "${SQL_SOURCE_SERVER}.database.windows.net" \
  -U "$ADMIN_USER" -P "$ADMIN_PASSWORD" \
  -d "$SQL_SOURCE_DB" \
  -Q "CREATE TABLE Users (id INT PRIMARY KEY, name NVARCHAR(50)); INSERT INTO Users VALUES (1,'Alice'), (2,'Bob');"
echo "✅ Demo data inserted."

echo "🔎 Verifying demo data in $SQL_SOURCE_DB ..."
docker run --rm mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd -S "${SQL_SOURCE_SERVER}.database.windows.net" \
  -U "$ADMIN_USER" -P "$ADMIN_PASSWORD" \
  -d "$SQL_SOURCE_DB" \
  -Q "SELECT * FROM Users;"
echo "✅ Data verification complete."

echo "🎉 Source SQL Server and database setup completed successfully."
