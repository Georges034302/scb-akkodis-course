# 🛠️ Azure Policy as Code (Require Tag) with Bicep (no CI/CD)

## 🎯 Objective  
Require an `owner` tag on **every** resource using **Policy** + **Bicep**, deployed from your terminal.

---

## 🗂️ Project Structure
```
session1/azure-access-control/
└── require-tag/
    ├── definition/
    │   ├── rules.json
    │   └── parameters.json
    ├── assignment/
    │   └── assign.bicep
    └── scripts/
```

---

## 📄 Policy Rule — `definition/rules.json`
```json
{
  "if": {
    "field": "[concat('tags[', parameters('requiredTagName'), ']')]",
    "exists": "false"
  },
  "then": { "effect": "deny" }
}
```

---

## 📄 Policy Parameters — `definition/parameters.json`
```json
{
  "requiredTagName": {
    "type": "String",
    "metadata": {
      "displayName": "Required Tag Name",
      "description": "Name of the tag that must be present on resources."
    }
  }
}
```

---

## 📄 Policy Assignment (Bicep) — `assignment/assign.bicep`
```bicep
targetScope = 'subscription'

param policyDefinitionId string
param requiredTagName string = 'owner'

resource assignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-required-tag'
  properties: {
    displayName: 'Enforce Required Tag'
    policyDefinitionId: policyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      requiredTagName: {
        value: requiredTagName
      }
    }
  }
}
```

---

## 🚀 Deploy (Terminal Only)
```bash
set -euo pipefail
LOCATION=australiaeast
POLICY_NAME=require-tag-any
RULES="azure-access-control/require-tag/definition/rules.json"
PARAMS="azure-access-control/require-tag/definition/parameters.json"
BICEP="azure-access-control/require-tag/assignment/assign.bicep"

# 1) Create or update the definition
if az policy definition show --name "$POLICY_NAME" >/dev/null 2>&1; then
  az policy definition update \
    --name "$POLICY_NAME" \
    --rules @"$RULES" \
    --params @"$PARAMS" \
    --mode Indexed \
    --display-name "Require Tag on Resources" \
    --description "Deny creation of resources without required tag."
else
  az policy definition create \
    --name "$POLICY_NAME" \
    --rules @"$RULES" \
    --params @"$PARAMS" \
    --mode Indexed \
    --display-name "Require Tag on Resources" \
    --description "Deny creation of resources without required tag."
fi

# 2) Fetching policy definition ID
POLICY_DEF_ID="$(az policy definition show --name "$POLICY_NAME" --query id -o tsv)"
[ -n "$POLICY_DEF_ID" ] || { echo "Could not read policy definition id."; exit 1; }

# 3) Deploying policy assignment via Bicep
az deployment sub create \
  --location "$LOCATION" \
  --template-file "$BICEP" \
  --parameters policyDefinitionId="$POLICY_DEF_ID" requiredTagName="owner" \
  --name enforce-required-tag-deployment
```

---

## 🧪 Validation
```bash
RG="${RG:-demo-rg}"
LOCATION="${LOCATION:-australiaeast}"

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
  --tags owner=georges; then
  echo "✅ Tagged storage account created successfully."
else
  echo "❌ Failed to create tagged storage account. Please check your policy and permissions."
fi

echo "🔍 Verifying policy assignment exists..."
az policy assignment list --query "[?name=='enforce-required-tag']" -o table

echo "🔍 Inspecting compliance state (may take a few minutes to propagate)..."
az policy state list \
  --filter "PolicyAssignmentName eq 'enforce-required-tag'" \
  --query "[].{resource:resourceId, compliance:complianceState}" -o table

echo "🎉 Validation complete!"
```

---

## 🧹 Cleanup
```bash
az group delete -n demo-rg -y
az policy assignment delete --name enforce-required-tag
az policy definition delete --name require-tag-any
```

---

## ✅ Key Learnings
- Tag enforcement strengthens governance  
- Parameterized for flexibility

