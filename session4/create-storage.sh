#!/bin/bash

# ========================================
# 🧩 Variables
# ========================================
RG_NAME="rg-immutable-demo"
LOCATION="australiaeast"
CONTAINER_NAME="audit-logs"
STORAGE_NAME="auditstore$(date +%s)"

# Save for reuse
echo "export RG_NAME=$RG_NAME" >> .env
echo "export STORAGE_NAME=$STORAGE_NAME" > .env
echo "export CONTAINER_NAME=$CONTAINER_NAME" >> .env

# ========================================
# 🔐 Login
# ========================================
echo "🔐 Logging into Azure..."
# az login --use-device-code || { echo "❌ Login failed. Exiting."; exit 1; }

# ========================================
# 📦 Create Resource Group
# ========================================
echo "📦 Creating resource group: $RG_NAME in $LOCATION..."
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION" \
  --output none

# ========================================
# 📁 Create Storage Account
# ========================================
echo "📁 Creating storage account: $STORAGE_NAME..."
az storage account create \
  --name "$STORAGE_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_GRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --output none

# ========================================
# 📂 Create Blob Container
# ========================================
echo "📂 Creating blob container: $CONTAINER_NAME..."
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_NAME" \
  --auth-mode login \
  --output none

echo "✅ Done. Now run: bash immutable-storage.sh"
