#!/usr/bin/env bash
set -euo pipefail

# Load environment variables (including RG) if available
if [ -f ../../../../.env ]; then
  source ../../../../.env
fi

RG="${RG:-demo-rg}"
POLICY_ASSIGNMENT_NAME="enforce-allowed-vm-sizes"
POLICY_DEFINITION_NAME="allowed-vm-sizes-lab"

echo "🧹 Deleting resource group: $RG ..."
az group delete -n "$RG" -y

echo "🧹 Deleting policy assignment: $POLICY_ASSIGNMENT_NAME ..."
az policy assignment delete --name "$POLICY_ASSIGNMENT_NAME"

echo "🧹 Deleting policy definition: $POLICY_DEFINITION_NAME ..."
az policy definition delete --name "$POLICY_DEFINITION_NAME"

echo "✅ Cleanup complete!"