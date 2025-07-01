#!/bin/bash
set -e

echo "🔧 Initializing environment variables..."
sleep 2

# Ensure .env exists
if [ ! -f .env ]; then
  echo "📝 .env file does not exist. Creating .env..."
  touch .env
fi

# Clean up previous values
echo "🧹 Cleaning up previous environment variables in .env..."
sed -i '/^export SQL_SA_USER=/d' .env
sed -i '/^export SQL_SA_PASSWORD=/d' .env
sed -i '/^export SQL_MI_NAME=/d' .env
sed -i '/^export SQL_MI_PASSWORD=/d' .env
sed -i '/^export SQL_MI_ADMIN_USER=/d' .env
sed -i '/^export SQL_DB_NAME=/d' .env
sed -i '/^export SUBSCRIPTION_ID=/d' .env
sed -i '/^export MIGRATION_SERVICE_ID=/d' .env
sed -i '/^export SQL_SCOPE=/d' .env
sed -i '/^export RESOURCE_GROUP=/d' .env
sed -i '/^export LOCATION=/d' .env
sed -i '/^export SQL_SERVER_NAME=/d' .env
sed -i '/^export DMS_NAME=/d' .env
sed -i '/^export PROJECT_NAME=/d' .env
sed -i '/^export TASK_NAME=/d' .env
sed -i '/^export VNET_NAME=/d' .env
sed -i '/^export SUBNET_NAME=/d' .env
sed -i '/^export SUBNET_ID=/d' .env

# Generate values
echo "🔑 Generating randomized values..."
SQL_DB_NAME="onpremsqldb"
SQL_SA_USER="sa"
SQL_SA_PASSWORD="P@ssw0rd$(date +%s%N | sha256sum | head -c 8)"
SQL_MI_NAME="sqlmi$(date +%s%N | sha256sum | head -c 5)"
SQL_MI_ADMIN_USER="sqladmin$(date +%s%N | sha256sum | head -c 4)"
SQL_MI_PASSWORD="P@ssw0rd$(date +%s%N | sha256sum | head -c 12)"
RESOURCE_GROUP="rg-dms-demo"
LOCATION="australiaeast"
SQL_SERVER_NAME="sqllogicdemo$RANDOM"
DMS_NAME="dms-demo"
PROJECT_NAME="sqlmig-project"
TASK_NAME="sqlmig-task"
VNET_NAME="dms-vnet"
SUBNET_NAME="dms-subnet"

# Get subscription and construct resource IDs
echo "🔍 Getting subscription and resource identifiers..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
MIGRATION_SERVICE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataMigration/services/$DMS_NAME"
SQL_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Sql/servers/$SQL_SERVER_NAME"

# Create VNet and Subnet
echo "🌐 Creating VNet and Subnet for DMS..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --location "$LOCATION" \
  --address-prefix 10.10.0.0/16 \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix 10.10.1.0/24

echo "🔎 Fetching subnet ID..."
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --query "id" -o tsv)

# Save to .env
echo "💾 Saving environment variables to .env..."
{
  echo "export SQL_SA_USER=$SQL_SA_USER"
  echo "export SQL_SA_PASSWORD=$SQL_SA_PASSWORD"
  echo "export SQL_MI_NAME=$SQL_MI_NAME"
  echo "export SQL_MI_ADMIN_USER=$SQL_MI_ADMIN_USER"
  echo "export SQL_MI_PASSWORD=$SQL_MI_PASSWORD"
  echo "export SQL_DB_NAME=$SQL_DB_NAME"
  echo "export RESOURCE_GROUP=$RESOURCE_GROUP"
  echo "export LOCATION=$LOCATION"
  echo "export SQL_SERVER_NAME=$SQL_SERVER_NAME"
  echo "export DMS_NAME=$DMS_NAME"
  echo "export PROJECT_NAME=$PROJECT_NAME"
  echo "export TASK_NAME=$TASK_NAME"
  echo "export VNET_NAME=$VNET_NAME"
  echo "export SUBNET_NAME=$SUBNET_NAME"
  echo "export SUBNET_ID=$SUBNET_ID"
  echo "export SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
  echo "export MIGRATION_SERVICE_ID=$MIGRATION_SERVICE_ID"
  echo "export SQL_SCOPE=$SQL_SCOPE"
} >> .env

echo "✅ All environment variables initialized and saved to .env"
