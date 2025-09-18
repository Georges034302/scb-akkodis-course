# 🛠️ Azure Policy as Code (Require Tag) with Bicep (no CI/CD)

## 🎯 Objective  
Require an `owner` tag on **every** resource using **Policy** + **Bicep**, deployed from your terminal.

---

## 🗂️ Project Structure
```
session1/azure-access-control/
└── require-tag/
    ├── definition/
    │   └── policy.json
    ├── assignment/
    │   └── assign.bicep
    └── scripts/
```

---

## 📄 Policy Definition — `session1/azure-access-control/require-tag/definition/policy.json`
```json
{
  "properties": {
    "displayName": "Require Tag on Resources",
    "mode": "Indexed",
    "description": "Deny creation of resources that do not include the required tag.",
    "parameters": {
      "requiredTagName": {
        "type": "String",
        "metadata": {
          "displayName": "Required Tag Name",
          "description": "Name of the tag that must be present on resources."
        }
      }
    },
    "policyRule": {
      "if": {
        "field": "[concat('tags[', parameters('requiredTagName'), ']')]",
        "exists": "false"
      },
      "then": { "effect": "deny" }
    }
  }
}
```

---

## 📄 Policy Assignment (Bicep) — `session1/azure-access-control/require-tag/assignment/assign.bicep`
```bicep
param policyDefinitionId string
param requiredTagName string = 'owner'
param scope string = subscription().id

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-required-tag'
  properties: {
    displayName: 'Enforce Required Tag'
    scope: scope
    policyDefinitionId: policyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      requiredTagName: { value: requiredTagName }
    }
  }
}
```

*(Optional)* `require-tag/assignment/assign-enforce-tags.parameters.json`
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "policyDefinitionId": { "value": "" },
    "requiredTagName": { "value": "owner" }
  }
}
```

---

## 🚀 Deploy (Terminal Only)
```bash
set -euo pipefail
LOCATION=australiaeast
POLICY_NAME=require-tag-any

# 1) Create or update the definition
if az policy definition show --name $POLICY_NAME >/dev/null 2>&1; then
  az policy definition update \
    --name $POLICY_NAME \
    --rules @azure-access-control/require-tag/definition/policy.json \
    --mode Indexed \
    --display-name "Require Tag on Resources" \
    --description "Deny creation of resources without required tag."
else
  az policy definition create \
    --name $POLICY_NAME \
    --rules @azure-access-control/require-tag/definition/policy.json \
    --mode Indexed \
    --display-name "Require Tag on Resources" \
    --description "Deny creation of resources without required tag."
fi

# 2) Assign via Bicep using parameters.json
POLICY_DEF_ID=$(az policy definition show --name $POLICY_NAME --query id -o tsv)

az deployment sub create \
  --location $LOCATION \
  --template-file azure-access-control/require-tag/assignment/assign.bicep \
  --parameters @azure-access-control/require-tag/assignment/assign-enforce-tags.parameters.json \
  --parameters policyDefinitionId="$POLICY_DEF_ID" \
  --name enforce-required-tag-deployment
```

---

## 🧪 Validation
```bash
# Expect DENY (missing tag)
az group create -n demo-untagged-rg -l australiaeast

# Expect ALLOW (tag present)
az group create -n demo-tagged-rg -l australiaeast --tags owner=georges

# Verify assignment exists
az policy assignment list --query "[?name=='enforce-required-tag']" -o table

# Inspect compliance (propagation may take a few minutes)
az policy state list \
  --filter "PolicyAssignmentName eq 'enforce-required-tag'" \
  --query "[].{resource:resourceId, compliance:complianceState}" -o table
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

