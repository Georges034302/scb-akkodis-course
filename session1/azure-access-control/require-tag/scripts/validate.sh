#!/usr/bin/env bash
set -euo pipefail

RG_UNTAGGED=demo-untagged-rg
RG_TAGGED=demo-tagged-rg
LOCATION=australiaeast

echo "🔵 Attempting to create resource group WITHOUT required tag (should be DENIED)..."
if az group create -n "$RG_UNTAGGED" -l "$LOCATION"; then
  echo "❌ Policy did NOT block untagged resource group! Please check your policy assignment."
else
  echo "✅ Policy correctly denied creation of untagged resource group."
fi

echo "🟢 Attempting to create resource group WITH required tag (should be ALLOWED)..."
if az group create -n "$RG_TAGGED" -l "$LOCATION" --tags owner=georges; then
  echo "✅ Tagged resource group created successfully."
else
  echo "❌ Failed to create tagged resource group. Please check your policy and permissions."
fi

echo "🔍 Verifying policy assignment exists..."
az policy assignment list --query "[?name=='enforce-required-tag']" -o table

echo "🔍 Inspecting compliance state (may take a few minutes to propagate)..."
az policy state list \
  --filter "PolicyAssignmentName eq 'enforce-required-tag'" \
  --query "[].{resource:resourceId, compliance:complianceState}" -o table

echo "🎉 Validation complete!"