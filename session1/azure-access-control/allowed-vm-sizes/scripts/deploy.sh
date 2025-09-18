#!/usr/bin/env bash
set -euo pipefail

LOCATION=australiaeast
POLICY_NAME=allowed-vm-sizes-lab

echo "🔵 Checking for existing policy definition: $POLICY_NAME ..."
if az policy definition show --name "$POLICY_NAME" >/dev/null 2>&1; then
  echo "📝 Updating existing policy definition: $POLICY_NAME"
  az policy definition update \
    --name "$POLICY_NAME" \
    --rules @session1/azure-access-control/allowed-vm-sizes/definition/policy.json \
    --mode Indexed \
    --display-name "Allowed VM Sizes (Cost Control)" \
    --description "Restrict VM creation to approved SKUs only."
else
  echo "🆕 Creating new policy definition: $POLICY_NAME"
  az policy definition create \
    --name "$POLICY_NAME" \
    --rules @session1/azure-access-control/allowed-vm-sizes/definition/policy.json \
    --mode Indexed \
    --display-name "Allowed VM Sizes (Cost Control)" \
    --description "Restrict VM creation to approved SKUs only."
fi

echo "🔎 Fetching policy definition ID ..."
POLICY_DEF_ID=$(az policy definition show --name "$POLICY_NAME" --query id -o tsv)
echo "✅ Policy Definition ID: $POLICY_DEF_ID"

echo "🚀 Deploying policy assignment via Bicep with parameters file ..."
az deployment sub create \
  --location "$LOCATION" \
  --template-file session1/azure-access-control/allowed-vm-sizes/assignment/assign.bicep \
  --parameters @session1/azure-access-control/allowed-vm-sizes/assignment/assign-allowed-vms.parameters.json \
  --parameters policyDefinitionId="$POLICY_DEF_ID" \
  --name enforce-allowed-vm-sizes-deployment

echo "🎉 Deployment complete!"