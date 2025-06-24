#!/bin/bash

# ========================================
# 🧩 Variables
# ========================================
RG_NAME="rg-immutable-demo"
LOCATION="australiaeast"
CONTAINER_NAME="audit-logs"
STORAGE_NAME="auditstore$(date +%s)"
SAS_EXPIRY=$(date -u -d "1 hour" '+%Y-%m-%dT%H:%MZ')

# ========================================
# 🔐 Login to Azure
# ========================================
echo "🔐 Logging into Azure..."
az login --use-device-code || { echo "❌ Login failed. Exiting."; exit 1; }

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

# ========================================
# 🔒 Apply Immutability Policy (Unlocked)
# ========================================
echo "🔒 Setting 7-year WORM policy (unlocked)..."
az storage container immutability-policy set \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --period 2555 \
  --allow-protected-append-writes true \
  --auth-mode login \
  --output none

# ========================================
# 📝 Upload Log File
# ========================================
echo "📝 Creating sample log file..."
echo "SECURITY LOG: $(date)" > log1.txt

echo "🔐 Generating SAS token..."
SAS_TOKEN=$(az storage container generate-sas \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_NAME" \
  --permissions acw \
  --expiry "$SAS_EXPIRY" \
  --auth-mode login \
  -o tsv)

if [ -z "$SAS_TOKEN" ]; then
  echo "❌ SAS token generation failed. Exiting."
  exit 1
fi

echo "🚀 Uploading file to blob container..."
azcopy copy "log1.txt" \
  "https://$STORAGE_NAME.blob.core.windows.net/$CONTAINER_NAME/log1.txt?$SAS_TOKEN" \
  --overwrite=false

# ========================================
# 🔐 Lock Immutability Policy
# ========================================
echo "🔐 Locking the immutability policy..."
az storage container immutability-policy lock \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --if-match "*" \
  --output none

# ========================================
# 🛡️ Apply Legal Hold
# ========================================
echo "🛡️ Applying legal hold tags..."
az storage container legal-hold set \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --tags "APRA-CPS234" "SOX-2024-Audit" \
  --output none

# ========================================
# 🔍 Final Validation
# ========================================
echo "🔍 Verifying immutability policy state..."
az storage container show \
  --account-name "$STORAGE_NAME" \
  --name "$CONTAINER_NAME" \
  --query "immutabilityPolicy"

echo "🧪 Testing delete operation (expected to fail)..."
az storage blob delete \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --name log1.txt \
  --auth-mode login

echo "✅ Immutable Storage Lab Complete!"
