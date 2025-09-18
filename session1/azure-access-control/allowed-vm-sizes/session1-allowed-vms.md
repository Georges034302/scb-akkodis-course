# 🛠️ Azure Policy as Code (Require Tag) with Bicep (no CI/CD)

## 🎯 Objective  
Require an `owner` tag on **every** resource using **Policy** + **Bicep**, deployed from your terminal.

---

## 🗂️ Project Structure
```
session1/azure-access-control/
└── require-tag/
    ├── definition/
    │   └── rules.json
    │   └── parameters.json
    ├── assignment/
    │   └── assign.bicep
    └── scripts/
```

---

## 📄 Policy Definition — `rules.json`
```json
{
  "if": {
    "allOf": [
      { "field": "type", "equals": "Microsoft.Compute/virtualMachines" },
      { "field": "Microsoft.Compute/virtualMachines/sku.name", "notIn": "[parameters('listOfAllowedSKUs')]" }
    ]
  },
  "then": { "effect": "deny" }
}
```

---

## 📄 Policy Assignment (Bicep) — `assign.bicep`
```bicep
targetScope = 'subscription'

param policyDefinitionId string
param listOfAllowedSKUs array = [
  'Standard_B1s'
  'Standard_B2s'
]

resource pa 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-allowed-vm-sizes'
  properties: {
    displayName: 'Enforce Allowed VM Sizes'
    policyDefinitionId: policyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      listOfAllowedSKUs: {
        value: listOfAllowedSKUs
      }
    }
  }
}
```

*(Optional)* `parameters.json`
```json
{
  "listOfAllowedSKUs": {
    "type": "Array",
    "metadata": {
      "displayName": "Allowed VM Sizes",
      "description": "List of permitted SKU names for virtual machines."
    }
  }
}
```

---

## 🚀 Deploy (Terminal Only)
```bash
set -euo pipefail
LOCATION="${LOCATION:-australiaeast}"
POLICY_NAME="allowed-vm-sizes-lab"
RULES="azure-access-control/allowed-vm-sizes/definition/rules.json"
PARAMS="azure-access-control/allowed-vm-sizes/definition/parameters.json"
BICEP="azure-access-control/allowed-vm-sizes/assignment/assign.bicep"

# 1) Create or update the definition
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

# 2) Fetching policy definition ID
POLICY_DEF_ID=$(az policy definition show --name "$POLICY_NAME" --query id -o tsv)

# 3) Deploying policy assignment via Bicep 
az deployment sub create \
  --location "$LOCATION" \
  --template-file "$BICEP" \
  --parameters policyDefinitionId="$POLICY_DEF_ID" \
  --name enforce-allowed-vm-sizes-deployment
```

---

## 🧪 Validation
```bash
# Create VM with disallowed size
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

# Ceate allowed VM (should SUCCEED)
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

