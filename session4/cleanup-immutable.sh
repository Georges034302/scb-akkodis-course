#!/bin/bash

# ===========================
# 🧩 Load Variables
# ===========================
source .env

echo "🧼 Starting cleanup..."
echo "📦 Storage Account: $STORAGE_NAME"
echo "📁 Container: $CONTAINER_NAME"
echo "🗑️ Resource Group: $RG_NAME"

# ===========================
# 🔓 Remove Legal Hold (if any)
# ===========================
echo "🔓 Removing legal hold (if applied)..."
EXISTING_TAGS=$(az storage container legal-hold show \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --query "tags[].tag" -o tsv 2>/dev/null)

if [[ -n "$EXISTING_TAGS" ]]; then
  echo "🔎 Found tags: $EXISTING_TAGS"
  az storage container legal-hold clear \
    --account-name "$STORAGE_NAME" \
    --container-name "$CONTAINER_NAME" \
    --tags $EXISTING_TAGS
else
  echo "✅ No legal hold tags found."
fi

# ===========================
# 🔓 Delete Immutability Policy (if not locked)
# ===========================
echo "🔍 Checking immutability policy state..."
POLICY_STATE=$(az storage container immutability-policy show \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --query "state" -o tsv 2>/dev/null)

if [[ "$POLICY_STATE" == "Unlocked" ]]; then
  echo "🔓 Immutability policy is unlocked. Deleting..."
  ETAG=$(az storage container immutability-policy show \
    --account-name "$STORAGE_NAME" \
    --container-name "$CONTAINER_NAME" \
    --query "etag" -o tsv)

  az storage container immutability-policy delete \
    --account-name "$STORAGE_NAME" \
    --container-name "$CONTAINER_NAME" \
    --if-match "$ETAG"
else
  echo "⚠️ Cannot delete immutability policy — current state: $POLICY_STATE"
fi

# ===========================
# 🗑️ Delete Container
# ===========================
echo "🗑️ Deleting blob container..."
az storage container delete \
  --account-name "$STORAGE_NAME" \
  --name "$CONTAINER_NAME" \
  --auth-mode login || echo "⚠️ Container delete may fail if policy still locked."

# ===========================
# 🗑️ Delete Resource Group
# ===========================
echo "🧨 Deleting resource group: $RG_NAME"
az group delete --name "$RG_NAME" --yes --no-wait

echo "✅ Cleanup initiated. It may take a few minutes to complete."
