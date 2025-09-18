#!/usr/bin/env bash
set -euo pipefail

# Config (override LOCATION via env if you like)
LOCATION="${LOCATION:-australiaeast}"
POLICY_NAME="allowed-vm-sizes-lab"

RULES="azure-access-control/allowed-vm-sizes/definition/rules.json"
PARAMS="azure-access-control/allowed-vm-sizes/definition/parameters.json"
BICEP="azure-access-control/allowed-vm-sizes/assignment/assign.bicep"

echo "🔵 Checking files..."
[[ -f "$RULES" ]]  || { echo "❌ Missing $RULES"; exit 1; }
[[ -f "$PARAMS" ]] || { echo "❌ Missing $PARAMS"; exit 1; }
[[ -f "$BICEP"  ]] || { echo "❌ Missing $BICEP";  exit 1; }

# Safety: rules.json must ONLY contain the rule (if/then)
if grep -q '"displayName"' "$RULES"; then
  echo "❌ $RULES must contain ONLY the policy rule (if/then). Remove displayName/mode/parameters."
  exit 1
fi

echo "🔵 Checking for existing policy definition: $POLICY_NAME ..."
if az policy definition show --name "$POLICY_NAME" >/dev/null 2>&1; then
  echo "📝 Updating existing policy definition: $POLICY_NAME"
  az policy definition update \
    --name "$POLICY_NAME" \
    --rules @"$RULES" \
    --params @"$PARAMS" \
    --mode Indexed \
    --display-name "Allowed VM Sizes (Cost Control)" \
    --description "Restrict VM creation to approved SKUs only."
else
  echo "🆕 Creating new policy definition: $POLICY_NAME"
  az policy definition create \
    --name "$POLICY_NAME" \
    --rules @"$RULES" \
    --params @"$PARAMS" \
    --mode Indexed \
    --display-name "Allowed VM Sizes (Cost Control)" \
    --description "Restrict VM creation to approved SKUs only."
fi

echo "🔎 Fetching policy definition ID ..."
POLICY_DEF_ID=$(az policy definition show --name "$POLICY_NAME" --query id -o tsv)
echo "✅ Policy Definition ID: $POLICY_DEF_ID"

echo "🚀 Deploying policy assignment via Bicep ..."
az deployment sub create \
  --location "$LOCATION" \
  --template-file "$BICEP" \
  --parameters policyDefinitionId="$POLICY_DEF_ID" \
  --name enforce-allowed-vm-sizes-deployment

echo "🎉 Deployment complete!"
