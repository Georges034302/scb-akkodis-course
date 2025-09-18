#!/usr/bin/env bash
set -euo pipefail

LOCATION=australiaeast
POLICY_NAME=require-tag-any

echo "🔵 Checking for existing policy definition: $POLICY_NAME ..."
if az policy definition show --name "$POLICY_NAME" >/dev/null 2>&1; then
  echo "📝 Updating existing policy definition: $POLICY_NAME"
  az policy definition update \
    --name "$POLICY_NAME" \
    --rules @session1/azure-access-control/require-tag/definition/policy.json \
    --mode Indexed \
    --display-name "Require Tag on Resources" \
    --description "Deny creation of resources without required tag."
else
  echo "🆕 Creating new policy definition: $POLICY_NAME"
  az policy definition create \
    --name "$POLICY_NAME" \
    --rules @session1/azure-access-control/require-tag/definition/policy.json \
    --mode Indexed \
    --display-name "Require Tag on Resources" \
    --description "Deny creation of resources without required tag."
fi

echo "🔎 Fetching policy definition ID ..."
POLICY_DEF_ID=$(az policy definition show --name "$POLICY_NAME" --query id -o tsv)
echo "✅ Policy Definition ID: $POLICY_DEF_ID"

echo "🚀 Deploying policy assignment via Bicep with parameters file ..."
az deployment sub create \
  --location "$LOCATION" \
  --template-file session1/azure-access-control/require-tag/assignment/assign.bicep \
  --parameters @session1/azure-access-control/require-tag/assignment/assign-enforce-tags.parameters.json \
  --parameters policyDefinitionId="$POLICY_DEF_ID" \
  --name enforce-required-tag-deployment

echo "🎉 Deployment complete!"