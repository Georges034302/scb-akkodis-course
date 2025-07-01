#!/bin/bash
set -e

echo "🚀 Provisioning Azure SQL DB migration infrastructure using Azure DMS..."
sleep 1

# Load environment variables
echo "📦 Loading environment variables from .env..."
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found. Run ./init_env.sh first."
  exit 1
fi

# Validate required .env variables
echo "🔎 Validating required environment variables..."
for var in RESOURCE_GROUP LOCATION SQL_SERVER_NAME DMS_NAME PROJECT_NAME TASK_NAME SQL_SA_USER SQL_SA_PASSWORD SQL_MI_ADMIN_USER SQL_MI_PASSWORD SQL_DB_NAME MIGRATION_SERVICE_ID SQL_SCOPE; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing $var in .env. Run ./init_env.sh first."
    exit 1
  fi
done

# Register Microsoft.DataMigration provider
echo "🛡️ Registering Microsoft.DataMigration provider..."
az provider register --namespace Microsoft.DataMigration --wait
echo "✅ Provider registered."

# Create Azure DMS instance
echo "🛠️ Creating Azure DMS instance..."
az dms create \
  --location "$LOCATION" \
  --name "$DMS_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sku-name Standard_2vCores \
  --subnet "$SUBNET_ID"
echo "✅ DMS instance created."

# Create migration project
echo "📂 Creating migration project..."
az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataMigration/services/$DMS_NAME/projects/$PROJECT_NAME?api-version=2022-03-30-preview" \
  --body "{\"location\": \"$LOCATION\", \"properties\": {\"sourcePlatform\": \"SQL\", \"targetPlatform\": \"SQLDB\"}}" \
  --headers "Content-Type=application/json"
echo "✅ Migration project created."

# Verify migration project creation
echo "🔍 Verifying migration project creation..."
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataMigration/services/$DMS_NAME/projects?api-version=2022-03-30-preview" \
  --query "value[].name"
echo "✅ Project verification complete."

echo "🎉 DMS provisioning and migration project setup completed successfully."
