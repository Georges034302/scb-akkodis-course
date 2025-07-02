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
sed -i '/^export /d' .env

# Generate values
echo "🔑 Generating randomized values..."
RESOURCE_GROUP="rg-dms-demo"
LOCATION="australiaeast"
SQL_SOURCE_NAME="sqlsource$RANDOM"
SQL_TARGET_NAME="sqltarget$RANDOM"  # Azure SQL DB target
SQL_ADMIN_USER="sqladmin"
SQL_ADMIN_PASSWORD="P@ssw0rd$RANDOM"
SQL_DB_NAME="sqldb$(date +%s%N | sha256sum | head -c 8)"
VNET_NAME="dms-vnet"
SUBNET_NAME="dms-subnet"
DMS_NAME="dms-demo"
PROJECT_NAME="sqlmig-project"
TASK_NAME="sqlmig-task"
SQL_SA_USER="$SQL_ADMIN_USER"
SQL_SA_PASSWORD="$SQL_ADMIN_PASSWORD"

# Get subscription ID
echo "🔍 Getting subscription ID..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create resource group
echo "📁 Creating resource group: $RESOURCE_GROUP ..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# Create VNet and Subnet
echo "🌐 Creating VNet and Subnet for DMS..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --location "$LOCATION" \
  --address-prefix 10.10.0.0/16 \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix 10.10.1.0/24

# Get subnet ID
echo "🔎 Fetching subnet ID..."
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --query "id" -o tsv)

# Save to .env
echo "💾 Saving environment variables to .env..."
cat <<EOF >> .env
export RESOURCE_GROUP=$RESOURCE_GROUP
export LOCATION=$LOCATION
export SQL_SOURCE_NAME=$SQL_SOURCE_NAME
export SQL_TARGET_NAME=$SQL_TARGET_NAME
export SQL_ADMIN_USER=$SQL_ADMIN_USER
export SQL_ADMIN_PASSWORD=$SQL_ADMIN_PASSWORD
export SQL_SA_USER=$SQL_SA_USER
export SQL_SA_PASSWORD=$SQL_SA_PASSWORD
export SQL_DB_NAME=$SQL_DB_NAME
export VNET_NAME=$VNET_NAME
export SUBNET_NAME=$SUBNET_NAME
export SUBNET_ID=$SUBNET_ID
export DMS_NAME=$DMS_NAME
export PROJECT_NAME=$PROJECT_NAME
export TASK_NAME=$TASK_NAME
export SUBSCRIPTION_ID=$SUBSCRIPTION_ID
EOF

echo "✅ All environment variables initialized and saved to .env"
