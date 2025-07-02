#!/bin/bash
set -e

echo "🏗️ Provisioning target Azure SQL Server and database..."
sleep 1

# Load environment variables
echo "📦 Loading environment variables from .env..."
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found. Run ./init_env.sh first."
  exit 1
fi

# Create target SQL Server
echo "🛠️ Creating target SQL Server: $SQL_TARGET_NAME ..."
az sql server create \
  --name "$SQL_TARGET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$SQL_ADMIN_USER" \
  --admin-password "$SQL_ADMIN_PASSWORD"
echo "✅ Target SQL Server created."

# Create empty target DB
echo "🗄️ Creating target database: $SQL_DB_NAME ..."
az sql db create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_TARGET_NAME" \
  --name "$SQL_DB_NAME" \
  --service-objective S0
echo "✅ Target database created."

# Allow Azure access
echo "🌐 Creating firewall rule to allow Azure services..."
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_TARGET_NAME" \
  --name AllowAllAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
echo "✅ Firewall rule created."

echo "🎉 Target SQL Server and database