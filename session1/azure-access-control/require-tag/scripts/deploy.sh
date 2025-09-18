#!/usr/bin/env bash
set -euo pipefail

LOCATION="${LOCATION:-australiaeast}"
POLICY_NAME="require-tag-any"

RULES="azure-access-control/require-tag/definition/rules.json"
DEFINITION_PARAMS="azure-access-control/require-tag/definition/parameters.json"   # schema (no $schema)
BICEP="azure-access-control/require-tag/assignment/assign.bicep"
ASSIGNMENT_PARAMS="azure-access-control/require-tag/assignment/parameters.json"  # values (has $schema)

say() { printf '🔵 %s\n' "$*"; }
die() { printf '❌ %s\n' "$*" >&2; exit 1; }

# ---------- Preflight ----------
[ -f "$RULES" ]            || die "Missing $RULES"
[ -f "$DEFINITION_PARAMS" ]|| die "Missing $DEFINITION_PARAMS"
[ -f "$BICEP" ]            || die "Missing $BICEP"

# rules.json must ONLY contain the rule (no displayName/mode/parameters)
grep -q '"displayName"' "$RULES" && die "rules.json must contain only the if/then rule."

# Definition params must be schema (no $schema / no top-level 'parameters')
if grep -q '"$schema"' "$DEFINITION_PARAMS"; then
  die "Definition params must be a policy schema (no \$schema / no top-level 'parameters')."
fi

# ---------- Create or update policy definition ----------
say "Checking for existing policy definition: $POLICY_NAME ..."
if az policy definition show --name "$POLICY_NAME" >/dev/null 2>&1; then
  say "Updating policy definition: $POLICY_NAME"
  az policy definition update \
    --name "$POLICY_NAME" \
    --rules @"$RULES" \
    --params @"$DEFINITION_PARAMS" \
    --mode Indexed \
    --display-name "Require Tag on Resources" \
    --description "Deny creation of resources without required tag."
else
  say "Creating policy definition: $POLICY_NAME"
  az policy definition create \
    --name "$POLICY_NAME" \
    --rules @"$RULES" \
    --params @"$DEFINITION_PARAMS" \
    --mode Indexed \
    --display-name "Require Tag on Resources" \
    --description "Deny creation of resources without required tag."
fi

# ---------- Assign at subscription scope via Bicep ----------
say "Fetching policy definition ID ..."
POLICY_DEF_ID="$(az policy definition show --name "$POLICY_NAME" --query id -o tsv)"
[ -n "$POLICY_DEF_ID" ] || die "Could not read policy definition id."
say "Policy Definition ID: $POLICY_DEF_ID"

say "Deploying policy assignment via Bicep ..."
if [ -f "$ASSIGNMENT_PARAMS" ]; then
  az deployment sub create \
    --location "$LOCATION" \
    --template-file "$BICEP" \
    --parameters @"$ASSIGNMENT_PARAMS" \
    --parameters policyDefinitionId="$POLICY_DEF_ID" \
    --name enforce-required-tag-deployment
else
  az deployment sub create \
    --location "$LOCATION" \
    --template-file "$BICEP" \
    --parameters policyDefinitionId="$POLICY_DEF_ID" requiredTagName="owner" \
    --name enforce-required-tag-deployment
fi

printf '✅ Deployment complete!\n'
