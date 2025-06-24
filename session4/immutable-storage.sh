#!/bin/bash

# ========================================
# 🧩 Load Variables
# ========================================
source .env
SAS_EXPIRY=$(date -u -d "1 hour" '+%Y-%m-%dT%H:%MZ')

echo "Storage: $STORAGE_NAME"
echo "Container: $CONTAINER_NAME"
echo "Expiry: $SAS_EXPIRY"

# ========================================
# 🔒 Apply Immutability Policy (Unlocked Only)
# ========================================
echo "🔒 Setting 7-year WORM policy (unlocked)..."
az storage container immutability-policy create \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --period 2555 \
  --allow-protected-append-writes true \
  --output none

# ========================================
# 📝 Upload Log File (Unique Name)
# ========================================
FILENAME="log-$(date +%s)-entry.txt"
echo "📝 Creating sample log file: $FILENAME"
echo "SECURITY LOG: $(date)" > "$FILENAME"
echo "export FILENAME=$FILENAME" >> .env

echo "🔐 Generating SAS token..."
SAS_TOKEN=$(az storage container generate-sas \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_NAME" \
  --permissions acwl \
  --expiry "$SAS_EXPIRY" \
  --auth-mode login \
  --as-user \
  -o tsv)

if [[ -z "$SAS_TOKEN" || "$SAS_TOKEN" != *sig=* ]]; then
  echo "❌ SAS token generation failed or malformed. Exiting."
  exit 1
fi

SAS_URL="https://${STORAGE_NAME}.blob.core.windows.net/${CONTAINER_NAME}/${FILENAME}?${SAS_TOKEN}"
echo "🔗 Upload URL: $SAS_URL"

echo "🚀 Uploading file with AzCopy..."
if ! command -v azcopy &> /dev/null; then
  echo "❌ AzCopy is not installed. Install from: https://aka.ms/downloadazcopy"
  exit 1
fi

azcopy copy "$FILENAME" "$SAS_URL" --overwrite=false --log-level=INFO
if [[ $? -ne 0 ]]; then
  echo "⚠️ AzCopy upload failed. Falling back to Azure CLI upload..."
  az storage blob upload \
    --account-name "$STORAGE_NAME" \
    --container-name "$CONTAINER_NAME" \
    --name "$FILENAME" \
    --file "$FILENAME" \
    --auth-mode login || {
      echo "❌ CLI upload also failed. Exiting."
      exit 1
    }
  echo "✅ File uploaded via Azure CLI fallback."
else
  echo "✅ File uploaded successfully with AzCopy."
fi

# ========================================
# 🛡️ Apply Legal Hold (Optional)
# ========================================
echo "🛡️ Applying legal hold tags..."
az storage container legal-hold set \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --tags APRACPS234 SOX2024Audit \
  --output none

# ========================================
# 🔍 Final Validation
# ========================================
echo "🔍 Verifying immutability policy state..."
az storage container immutability-policy show \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME"

echo "🧪 Testing delete operation (should succeed)..."
az storage blob delete \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --name "$FILENAME" \
  --auth-mode login && echo "✅ Delete succeeded as expected (unlocked)."

echo "✅ Immutable Storage Lab (Unlocked) Complete!"
