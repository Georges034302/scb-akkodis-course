#!/bin/bash

RG="Demo-RG"
LOCATION="australiaeast"

echo "🛠️  Creating resource group: $RG in $LOCATION..."
az group create \
  --name "$RG" \
  --location "$LOCATION"

echo "🔑 Registering Microsoft.KeyVault resource provider..."
az provider register \
  --namespace Microsoft.KeyVault

KV_NAME="DemoVault$(date +%s)"
echo "🏗️  Creating Key Vault: $KV_NAME in $RG..."
az keyvault create \
  --name "$KV_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION"

echo "✅ Environment setup complete! Key Vault: $KV_NAME"
