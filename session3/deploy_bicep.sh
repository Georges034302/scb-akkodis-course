#!/bin/bash

# filepath: deploy_bicep.sh

echo "🗂️  Creating resource group: rg-flow-lab..."
az group create \
  --name rg-flow-lab \
  --location australiaeast


echo "👁️  Enabling Network Watcher in australiaeast..."
az network watcher configure \
  --locations australiaeast \
  --resource-group rg-flow-lab \
  --enabled true

echo "🚀 Deploying bicep template..."
echo "🔑 Please enter the VM admin password:"
read -s -p "🔒 Password: " PASSWORD
echo
az deployment group create \
  --resource-group rg-flow-lab \
  --template-file nsg_flow.bicep \
  --parameters adminPassword="$PASSWORD" \

echo "✅ Deployment complete!"