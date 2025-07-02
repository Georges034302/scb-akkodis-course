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

# Master admin user and password
ADMIN_USER="sqladmin"
ADMIN_PASSWORD="P@ssw0rd$RANDOM"

SQL_SOURCE_SERVER="sqlsource$RANDOM"
SQL_SOURCE_DB="sqldb$(date +%s%N | sha256sum | head -c 8)"
VNET_NAME="dms-vnet"
SUBNET_NAME="dms-subnet"

# VM/SQL VM variables
SQL_VM_NAME="sqlvmdemo$RANDOM"
SQL_IMAGE="MicrosoftSQLServer:sql2019-ws2022:sqldev:15.0.250227"

# Storage variables for sql backups
STORAGE_NAME="sourcesqlbackup$RANDOM"
STORAGE_CONTAINER="sqlcontainerbackup$RANDOM"

# Backup folder variable for blob storage
BACKUP_FOLDER="backupfolder$(date +%Y%m%d)"

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
export ADMIN_USER=$ADMIN_USER
export ADMIN_PASSWORD=$ADMIN_PASSWORD
export SQL_SOURCE_SERVER=$SQL_SOURCE_SERVER
export SQL_SOURCE_DB=$SQL_SOURCE_DB
export VNET_NAME=$VNET_NAME
export SUBNET_NAME=$SUBNET_NAME
export SUBNET_ID=$SUBNET_ID
export SUBSCRIPTION_ID=$SUBSCRIPTION_ID
export SQL_VM_NAME=$SQL_VM_NAME
export SQL_IMAGE=$SQL_IMAGE
export STORAGE_NAME=$STORAGE_NAME
export STORAGE_CONTAINER=$STORAGE_CONTAINER
export BACKUP_FOLDER=$BACKUP_FOLDER
EOF

echo "✅ All environment variables initialized and saved to .env"
