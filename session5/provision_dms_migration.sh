#!/bin/bash
set -e

echo "🚀 Provisioning Azure SQL DB migration infrastructure using Azure DMS..."
sleep 1

# Load environment variables
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found. Run ./init_env.sh first."
  exit 1
fi

# Validate required .env variables
for var in RESOURCE_GROUP LOCATION SQL_SERVER_NAME DMS_NAME PROJECT_NAME TASK_NAME SQL_SA_USER SQL_SA_PASSWORD SQL_MI_ADMIN_USER SQL_MI_PASSWORD SQL_DB_NAME MIGRATION_SERVICE_ID SQL_SCOPE; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing $var in .env. Run ./init_env.sh first."
    exit 1
  fi
done

# Create resource group
echo "📦 Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# Register Data Migration provider
echo "🛡️ Registering Microsoft.DataMigration provider..."
az provider register --namespace Microsoft.DataMigration --wait

# Create logical SQL Server
echo "🧐 Creating logical Azure SQL Server..."
az sql server create \
  --name "$SQL_SERVER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$SQL_MI_ADMIN_USER" \
  --admin-password "$SQL_MI_PASSWORD"

# Create target SQL DB
echo "📂 Creating Azure SQL Database '$SQL_DB_NAME'..."
az sql db create \
  --name "$SQL_DB_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SERVER_NAME" \
  --service-objective S0

echo "🌐 Creating VNet and Subnet for DMS..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "dms-vnet" \
  --address-prefix 10.10.0.0/16 \
  --subnet-name "dms-subnet" \
  --subnet-prefix 10.10.1.0/24

echo "🔎 Fetching subnet ID..."
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "dms-vnet" \
  --name "dms-subnet" \
  --query "id" -o tsv)

echo "🛠️ Creating Azure DMS instance ..."
az dms create \
  --name "$DMS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku-name "Standard_2vCores" \
  --subnet "$SUBNET_ID"

# Wait for DMS to be provisioned
echo "⏳ Waiting for DMS provisioning to complete..."
for i in {1..30}; do
  STATUS=$(az dms show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DMS_NAME" \
    --query "provisioningState" -o tsv 2>/dev/null || echo "Pending")
  echo "   🔄 Status: $STATUS"
  if [[ "$STATUS" == "Succeeded" ]]; then
    echo "✅ Azure DMS is ready."
    break
  elif [[ "$STATUS" == "Failed" ]]; then
    echo "❌ DMS provisioning failed."
    exit 1
  fi
  sleep 10
done

# Create project via REST
echo "📂 Creating migration project..."
az rest --method PUT \
  --uri "https://management.azure.com$MIGRATION_SERVICE_ID/projects/$PROJECT_NAME?api-version=2022-03-30-preview" \
  --body "{\"location\": \"$LOCATION\", \"properties\": {\"sourcePlatform\": \"SQL\", \"targetPlatform\": \"SQLDB\"}}" \
  --headers "Content-Type=application/json"
echo "✅ Project created."

# Trigger migration task
echo "🚚 Creating SQL DB migration task..."
az datamigration sql-db create \
  --resource-group "$RESOURCE_GROUP" \
  --sqldb-instance-name "$SQL_SERVER_NAME" \
  --target-db-name "$SQL_DB_NAME" \
  --migration-service "$MIGRATION_SERVICE_ID" \
  --scope "$SQL_SCOPE" \
  --source-database-name "$SQL_DB_NAME" \
  --source-sql-connection authentication="SqlAuthentication" data-source="sqlsource" user-name="$SQL_SA_USER" password="$SQL_SA_PASSWORD" encrypt-connection=true trust-server-certificate=true \
  --target-sql-connection authentication="SqlAuthentication" data-source="$SQL_SERVER_NAME.database.windows.net" user-name="$SQL_MI_ADMIN_USER" password="$SQL_MI_PASSWORD" encrypt-connection=true trust-server-certificate=true

echo "🎉 Migration task initiated successfully."
