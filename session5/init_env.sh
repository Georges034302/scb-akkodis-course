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
sed -i '/^export RESOURCE_GROUP=/d' .env
sed -i '/^export LOCATION=/d' .env
sed -i '/^export SQL_SOURCE_NAME=/d' .env
sed -i '/^export SQL_TARGET_NAME=/d' .env
sed -i '/^export SQL_ADMIN_USER=/d' .env
sed -i '/^export SQL_ADMIN_PASSWORD=/d' .env
sed -i '/^export SQL_DB_NAME=/d' .env
sed -i '/^export VNET_NAME=/d' .env
sed -i '/^export SUBNET_NAME=/d' .env
sed -i '/^export SUBNET_ID=/d' .env
sed -i '/^export DMS_NAME=/d' .env
sed -i '/^export PROJECT_NAME=/d' .env
sed -i '/^export TASK_NAME=/d' .env
sed -i '/^export SUBSCRIPTION_ID=/d' .env

# Generate values
echo "🔑 Generating randomized values..."
RESOURCE_GROUP="rg-dms-demo"
LOCATION="australiaeast"
SQL_SOURCE_NAME="sqlsource$RANDOM"
SQL_TARGET_NAME="sqltarget$RANDOM"
SQL_ADMIN_USER="sqladmin"
SQL_ADMIN_PASSWORD="P@ssw0rd$RANDOM"
SQL_DB_NAME="sqldb$(date +%s%N | sha256sum | head -c 8)"
VNET_NAME="dms-vnet"
SUBNET_NAME="dms-subnet"
DMS_NAME="dms-demo"
PROJECT_NAME="sqlmig-project"
TASK_NAME="sqlmig-task"

# Get subscription and subnet ID
echo "🔍 Getting subscription ID..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create VNet and Subnet
echo "🌐 Creating VNet and Subnet for DMS..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --location "$LOCATION" \
  --address-prefix 10.10.0.0/16 \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix 10.10.1.0/24

# Delegate Subnet
echo "📌 Delegating subnet for DMS..."
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --delegations Microsoft.DataMigration/services

# Get subnet ID
echo "🔎 Fetching subnet ID..."
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --query "id" -o tsv)

# Save to .env
echo "💾 Saving environment variables to .env..."
{
  echo "export RESOURCE_GROUP=$RESOURCE_GROUP"
  echo "export LOCATION=$LOCATION"
  echo "export SQL_SOURCE_NAME=$SQL_SOURCE_NAME"
  echo "export SQL_TARGET_NAME=$SQL_TARGET_NAME"
  echo "export SQL_ADMIN_USER=$SQL_ADMIN_USER"
  echo "export SQL_ADMIN_PASSWORD=$SQL_ADMIN_PASSWORD"
  echo "export SQL_DB_NAME=$SQL_DB_NAME"
  echo "export VNET_NAME=$VNET_NAME"
  echo "export SUBNET_NAME=$SUBNET_NAME"
  echo "export SUBNET_ID=$SUBNET_ID"
  echo "export DMS_NAME=$DMS_NAME"
  echo "export PROJECT_NAME=$PROJECT_NAME"
  echo "export TASK_NAME=$TASK_NAME"
  echo "export SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
} >> .env

echo "✅ All environment variables initialized and saved to .env"
