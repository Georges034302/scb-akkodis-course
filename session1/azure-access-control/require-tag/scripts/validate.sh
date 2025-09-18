#!/usr/bin/env bash
set -euo pipefail

LOCATION="${LOCATION:-australiaeast}"
RG="${RG:-demo-rg}"

# Optional tag (helps if Require-Tag policy is enabled); override via env if desired
TAG_KEY="${TAG_KEY:-owner}"
TAG_VALUE="${TAG_VALUE:-georges}"

echo "❌ Attempting to create untagged storage account (should be DENIED by policy)..."
if az storage account create \
  -n "untagged$RANDOM" \
  -g "$RG" \
  -l "$LOCATION" \
  --sku Standard_LRS; then
  echo "❌ Policy did NOT block untagged storage account! Please check your policy assignment."
else
  echo "✅ Policy correctly denied creation of untagged storage account."
fi

echo "✅ Attempting to create tagged storage account (should SUCCEED)..."
if az storage account create \
  -n "tagged$RANDOM" \
  -g "$RG" \
  -l "$LOCATION" \
  --sku Standard_LRS \
  --tags "$TAG_KEY=$TAG_VALUE"; then
  echo "✅ Tagged storage account created successfully."
else
  echo "❌ Failed to create tagged storage account. Please check your policy and permissions."
fi

echo "🎉 Validation complete!"