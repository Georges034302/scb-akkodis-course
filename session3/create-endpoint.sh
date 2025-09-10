#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: create-endpoint.sh
# Description: Creates a private endpoint to a blob storage account using Azure CLI.
# Usage:       ./create-endpoint.sh
# -----------------------------------------------------------------------------
export MSYS_NO_PATHCONV=1

# Step 1: Fetch the storage account name in the resource group (suppress warnings)
echo "Fetching storage accounts in resource group 'secure-logging-rg'..."
STORAGE_NAME=$(az storage account list \
  --resource-group secure-logging-rg \
  --query "[0].name" \
  -o tsv 2>/dev/null)

echo "Using storage account: $STORAGE_NAME"

# Step 2: Fetch the storage account resource ID (suppress warnings)
echo "Fetching storage account resource ID..."
STORAGE_ID=$(az storage account show \
  --name "$STORAGE_NAME" \
  --resource-group secure-logging-rg \
  --query id \
  -o tsv 2>/dev/null)

echo "Fetched storage account resource ID: $STORAGE_ID"

# Step 3: Create the private endpoint
echo "Creating private endpoint..."
az network private-endpoint create \
  --name storage-pe \
  --resource-group secure-logging-rg \
  --vnet-name core-vnet \
  --subnet AppSubnet \
  --private-connection-resource-id "$STORAGE_ID" \
  --group-id blob \
  --connection-name storage-pe-conn
echo "Private endpoint 'storage-pe' created successfully."

