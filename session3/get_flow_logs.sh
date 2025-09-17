#!/bin/bash

# filepath: get_flow_logs.sh
# Description: Fetch and download the latest NSG Flow Log blob

# ===============================
# Variables
# ===============================
RG="rg-flow-lab"                      # Resource Group
CONTAINER="insights-nsg-flow-logs"    # Flow log container
OUTPUT_FILE="./flowlog.json"          # Local file to save the log

# ===============================
# Get storage account dynamically
# ===============================
echo "🔎 Fetching storage account name from resource group: $RG..."
STORAGE_ACCOUNT=$(az storage account list -g $RG --query "[0].name" -o tsv)

if [[ -z "$STORAGE_ACCOUNT" ]]; then
  echo "❌ ERROR: No storage account found in resource group $RG"
  exit 1
fi

echo "📦 Using storage account: $STORAGE_ACCOUNT"
echo "📂 Using container: $CONTAINER"

# ===============================
# Get the most recent blob path
# ===============================
BLOB_PATH=$(az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --auth-mode login \
  --query "[-1].name" -o tsv)

if [[ -z "$BLOB_PATH" ]]; then
  echo "❌ ERROR: No blobs found in container $CONTAINER"
  exit 1
fi

echo "🆕 Latest flow log blob: $BLOB_PATH"

# ===============================
# Download the blob locally
# ===============================
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $BLOB_PATH \
  --file $OUTPUT_FILE \
  --auth-mode login

echo "✅ Flow log downloaded to $OUTPUT_FILE"
