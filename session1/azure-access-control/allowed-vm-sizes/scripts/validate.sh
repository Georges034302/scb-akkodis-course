#!/usr/bin/env bash
set -euo pipefail

RG=vm-lab-rg
LOCATION=australiaeast

echo "🔵 Creating resource group: $RG ..."
az group create -n "$RG" -l "$LOCATION"

echo "❌ Attempting to create disallowed VM (should be DENIED by policy)..."
if az vm create \
  -g "$RG" \
  -n disallowedVm \
  --image Ubuntu2204 \
  --size Standard_D2s_v5 \
  --admin-username azureuser \
  --generate-ssh-keys; then
  echo "❌ Policy did NOT block disallowed VM size! Please check your policy assignment."
else
  echo "✅ Policy correctly denied creation of disallowed VM size."
fi

echo "✅ Attempting to create allowed VM (should SUCCEED)..."
if az vm create \
  -g "$RG" \
  -n allowedVm \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys; then
  echo "✅ Allowed VM size created successfully."
else
  echo "❌ Failed to create allowed VM size. Please check your policy and permissions."
fi

echo "🎉 Validation complete!"