#!/bin/bash

# Load environment variables
if [ -f .env ]; then
  source .env
fi

# Set defaults if not already set
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-demo}"
VNET_NAME="${VNET_NAME:-dms-vnet}"
SUBNET_NAME="${SUBNET_NAME:-dms-subnet}"
LOCATION="${LOCATION:-australiaeast}"

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create resource group
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

# Create virtual network and subnet
az network vnet create \
  --name "$VNET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --address-prefixes 10.10.0.0/16 \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefixes 10.10.1.0/24

# Delegate subnet to Microsoft.DataMigration
az network vnet subnet update \
  --name "$SUBNET_NAME" \
  --vnet-name "$VNET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --delegations Microsoft.DataMigration/services

# Get subnet resource ID
SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"

# Create Azure DMS instance
az dms create \
  --location "$LOCATION" \
  --name dms-demo \
  --resource-group "$RESOURCE_GROUP" \
  --sku-name "Standard_1vCore" \
  --subnet "$SUBNET_ID"

# Create DMS project
az dms project create \
  --resource-group "$RESOURCE_GROUP" \
  --service-name dms-demo \
  --name sqlmig-project \
  --source-platform SQL \
  --target-platform SQLMI

# Create DMS migration task
az dms task create \
  --resource-group "$RESOURCE_GROUP" \
  --project-name sqlmig-project \
  --service-name dms-demo \
  --name sqlmig-task \
  --task-type OnlineMigration \
  --source-connection-json source.json \
  --target-connection-json target.json \
  --database-options-json db-options.json

echo "✅ Azure DMS migration