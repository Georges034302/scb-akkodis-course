#!/bin/bash
set -e

# Load timer function
source ./timer_utils.sh

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

# Register Microsoft.DataMigration provider
echo "🛡️ Registering Microsoft.DataMigration provider..."
az provider register --namespace Microsoft.DataMigration --wait
echo "✅ Provider registered."

# Create Azure DMS instance
echo "🛠️ Creating Azure DMS instance..."
run_with_timer bash -c "
  az dms create \
    --location \"$LOCATION\" \
    --name \"$DMS_NAME\" \
    --resource-group \"$RESOURCE_GROUP\" \
    --sku-name Standard_2vCores \
    --subnet \"$SUBNET_ID\"
"
echo "✅ DMS instance created."

# Create migration project (Target: SQLMI)
echo "📂 Creating migration project targeting SQL Managed Instance..."
az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataMigration/services/$DMS_NAME/projects/$PROJECT_NAME?api-version=2022-03-30-preview" \
  --body "{
    \"location\": \"$LOCATION\",
    \"properties\": {
      \"sourcePlatform\": \"SQL\",
      \"targetPlatform\": \"SQLMI\"
    }
  }" \
  --headers "Content-Type=application/json"
echo "✅ Migration project created."

# Verify migration project creation
echo "🔍 Verifying migration project creation..."
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataMigration/services/$DMS_NAME/projects?api-version=2022-03-30-preview" \
  --query "value[].name" -o tsv
echo "✅ Project verification complete."

echo "🎉 DMS provisioning and migration project setup completed successfully."
