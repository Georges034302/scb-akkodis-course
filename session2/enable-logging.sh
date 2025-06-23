#!/bin/bash

set -e  # Exit immediately if a command fails

RG="Demo-RG"
LOCATION="australiaeast"
WORKSPACE_NAME="log-demoworkspace"

echo "📝 Creating Log Analytics Workspace '$WORKSPACE_NAME' in $RG..."
az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "$WORKSPACE_NAME" \
  --location "$LOCATION"
echo "✅ Log Analytics Workspace created successfully."

echo "🔍 Fetching Log Analytics Workspace resource ID..."
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RG" \
  --workspace-name "$WORKSPACE_NAME" \
  --query id -o tsv)
echo "Workspace ID: $WORKSPACE_ID"

echo "🔑 Fetching Key Vault name in $RG..."
KV_NAME=$(az keyvault list --resource-group "$RG" --query "[0].name" -o tsv)
echo "Key Vault Name: $KV_NAME"

echo "🔐 Adding a test secret to the Key Vault..."
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name testsecret \
  --value "demo-value"

echo "📊 Enabling diagnostic logging for Key Vault: $KV_NAME..."
az monitor diagnostic-settings create \
  --resource "$KV_NAME" \
  --resource-group "$RG" \
  --resource-type "vaults" \
  --resource-namespace "Microsoft.KeyVault" \
  --workspace "$WORKSPACE_ID" \
  --name "LogToSentinel" \
  --logs '[{"category": "AuditEvent","enabled": true}]'

echo "✅ Diagnostic logging enabled and sent to Log Analytics Workspace."
