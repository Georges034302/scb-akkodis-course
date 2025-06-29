#!/bin/bash
set -e

echo "🚀 Provisioning Azure DMS migration infrastructure..."

# Load environment variables
if [ -f .env ]; then
  source .env
fi

# Set default values if not defined
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-demo}"
VNET_NAME="${VNET_NAME:-dms-vnet}"
SUBNET_NAME="${SUBNET_NAME:-dms-subnet}"
LOCATION="${LOCATION:-australiaeast}"

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create resource group
echo "📦 Creating resource group: $RESOURCE_GROUP in $LOCATION..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"
echo "✅ Resource group created."

# Register required provider
echo "🛡️ Registering Azure DMS resource provider..."
az provider register --namespace Microsoft.DataMigration
echo "✅ Provider registered (or already active)."

# Create virtual network and subnet
echo "🌐 Creating virtual network and subnet..."
az network vnet create \
  --name "$VNET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --address-prefixes 10.10.0.0/16 \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefixes 10.10.1.0/24
echo "✅ Virtual network and subnet created."

# Get subnet resource ID
SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"
echo "🆔 Subnet resource ID: $SUBNET_ID"

# Create Azure DMS instance
echo "🛠️ Creating Azure Database Migration Service instance..."
az dms create \
  --location "$LOCATION" \
  --name dms-demo \
  --resource-group "$RESOURCE_GROUP" \
  --sku-name "Standard_2vCores" \
  --subnet "$SUBNET_ID"
echo "✅ DMS instance created."

# Create DMS project
echo "📂 Creating DMS project..."
az dms project create \
  --resource-group "$RESOURCE_GROUP" \
  --service-name dms-demo \
  --name sqlmig-project \
  --source-platform SQL \
  --target-platform SQLMI
echo "✅ DMS project created."

# Create DMS online migration task
echo "🚚 Creating DMS migration task..."
az dms task create \
  --resource-group "$RESOURCE_GROUP" \
  --project-name sqlmig-project \
  --service-name dms-demo \
  --name sqlmig-task \
  --task-type OnlineMigration \
  --source-connection-json source.json \
  --target-connection-json target.json \
  --database-options-json db-options.json
echo "✅ DMS migration task created."

echo "🎉 Azure DMS migration setup complete."
