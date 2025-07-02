#!/bin/bash
set -e

echo "🏗️ Provisioning target Azure SQL Server and Database (PaaS)..."
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
echo "🛠️ Creating Azure SQL Server: $SQL_TARGET_NAME ..."
az sql server create \
  --name "$SQL_TARGET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$SQL_ADMIN_USER" \
  --admin-password "$SQL_ADMIN_PASSWORD"
echo "✅ Azure SQL Server created."

# Create target database
echo "📂 Creating target database: $SQL_DB_NAME ..."
az sql db create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_TARGET_NAME" \
  --name "$SQL_DB_NAME" \
  --service-objective S0
echo "✅ Target database created."

# Allow Azure services to access
echo "🌐 Creating firewall rule to allow Azure services to access target..."
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_TARGET_NAME" \
  --name AllowAllAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
echo "✅ Firewall rule applied to target server."

echo "🎉 Target Azure SQL Server and database setup completed successfully."
