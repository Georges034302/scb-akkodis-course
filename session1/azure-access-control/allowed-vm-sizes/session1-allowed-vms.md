# 🛠️ Enforce Allowed VM Sizes with Bicep (no CI/CD)

## 🎯 Objective  
Restrict VM creation to **low-cost SKUs** (`Standard_B1s`, `Standard_B2s`) using **Azure Policy** + **Bicep**, deployed from your terminal.

---

## 🗂️ Project Structure
```
session1/azure-access-control/
├── allowed-vm-sizes/
│   ├── definition/
│   │   └── policy.json
│   ├── assignment/
│   │   └── assign.bicep
│   └── scripts/
```

---

## 📄 Policy Definition — `session1/azure-access-control/allowed-vm-sizes/definition/policy.json`
```json
{
  "properties": {
    "displayName": "Allowed VM Sizes (Cost Control)",
    "mode": "Indexed",
    "description": "Restrict VM creation to approved SKUs only.",
    "parameters": {
      "listOfAllowedSKUs": {
        "type": "Array",
        "metadata": {
          "displayName": "Allowed VM Sizes",
          "description": "List of permitted SKU names for virtual machines."
        }
      }
    },
    "policyRule": {
      "if": {
        "allOf": [
          { "field": "type", "equals": "Microsoft.Compute/virtualMachines" },
          { "field": "Microsoft.Compute/virtualMachines/sku.name", "notIn": "[parameters('listOfAllowedSKUs')]" }
        ]
      },
      "then": { "effect": "deny" }
    }
  }
}
```

---

## 📄 Policy Assignment (Bicep) — `session1/azure-access-control/allowed-vm-sizes/assignment/assign.bicep`
```bicep
param policyDefinitionId string
param scope string = subscription().id
param listOfAllowedSKUs array = [
  'Standard_B1s'
  'Standard_B2s'
]

resource pa 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-allowed-vm-sizes'
  properties: {
    displayName: 'Enforce Allowed VM Sizes'
    scope: scope
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

*(Optional)* `session1/azure-access-control/allowed-vm-sizes/assignment/assign-allowed-vms.parameters.json`
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "policyDefinitionId": { "value": "" },
    "listOfAllowedSKUs": { "value": ["Standard_B1s", "Standard_B2s"] }
  }
}
```

---

## 🚀 Deploy (Terminal Only)
```bash
set -euo pipefail
LOCATION=australiaeast
POLICY_NAME=allowed-vm-sizes-lab

# 1) Create or update the definition
if az policy definition show --name $POLICY_NAME >/dev/null 2>&1; then
  az policy definition update \
    --name $POLICY_NAME \
    --rules @session1/azure-access-control/allowed-vm-sizes/definition/policy.json \
    --mode Indexed \
    --display-name "Allowed VM Sizes (Cost Control)" \
    --description "Restrict VM creation to approved SKUs only."
else
  az policy definition create \
    --name $POLICY_NAME \
    --rules @session1/azure-access-control/allowed-vm-sizes/definition/policy.json \
    --mode Indexed \
    --display-name "Allowed VM Sizes (Cost Control)" \
    --description "Restrict VM creation to approved SKUs only."
fi

# 2) Assign via Bicep at subscription scope
POLICY_DEF_ID=$(az policy definition show --name $POLICY_NAME --query id -o tsv)

az deployment sub create \
  --location $LOCATION \
  --template-file session1/azure-access-control/allowed-vm-sizes/assignment/assign.bicep \
  --parameters policyDefinitionId="$POLICY_DEF_ID" \
  --name enforce-allowed-vm-sizes-deployment
```

---

## 🧪 Validation
```bash
RG=vm-lab-rg
az group create -n $RG -l australiaeast

# Expect DENY
az vm create \
  -g $RG \
  -n disallowedVm \
  --image Ubuntu2204 \
  --size Standard_D2s_v5 \
  --admin-username azureuser \
  --generate-ssh-keys

# Expect ALLOW
az vm create \
  -g $RG \
  -n allowedVm \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys
```

---

## 🧹 Cleanup
```bash
az group delete -n demo-rg -y
az policy assignment delete --name enforce-allowed-vm-sizes
az policy definition delete --name allowed-vm-sizes-lab
```

---

## ✅ Key Learnings
- Policy denies expensive SKUs at creation  
- Bicep assignment reproducible

