# 🛠️ Enforce Allowed VM Sizes with Bicep + GitHub Actions

## 🎯 Objective
Restrict creation of virtual machines to **low-cost SKUs** (`Standard_B1s`, `Standard_B2s`) to prevent accidental overspending.

Learners will:  
- Define a parameterized **policy** for allowed VM sizes  
- Assign it at subscription scope with **Bicep**  
- Automate enforcement with **GitHub Actions**  
- Validate by attempting to deploy both allowed and disallowed VM sizes  

---

## 🗂️ Project Structure

```
azure-policy-allowed-vms/
├── definitions/
│   └── allowedVmSizes/
│       └── policy.json
├── assignments/
│   ├── assign-allowed-vms.bicep
│   └── assign-allowed-vms.parameters.json
└── .github/
    └── workflows/
        └── deploy-allowed-vms.yml
```

---

## 📄 Policy Definition

**File:** `definitions/allowedVmSizes/policy.json`

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

## 📄 Policy Assignment (Bicep)

**File:** `assignments/assign-allowed-vms.bicep`

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

---

## 📄 GitHub Actions Workflow

**File:** `.github/workflows/deploy-allowed-vms.yml`

```yaml
name: Deploy Allowed VM Sizes Policy

on:
  push:
    branches: [ main ]
    paths:
      - 'definitions/**'
      - 'assignments/**'

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Create or Update Policy Definition
        run: |
          set -e
          if az policy definition show --name allowed-vm-sizes-lab >/dev/null 2>&1; then
            az policy definition update \
              --name allowed-vm-sizes-lab \
              --rules @definitions/allowedVmSizes/policy.json \
              --mode Indexed \
              --display-name "Allowed VM Sizes (Cost Control)" \
              --description "Restrict VM creation to approved SKUs only."
          else
            az policy definition create \
              --name allowed-vm-sizes-lab \
              --rules @definitions/allowedVmSizes/policy.json \
              --mode Indexed \
              --display-name "Allowed VM Sizes (Cost Control)" \
              --description "Restrict VM creation to approved SKUs only."
          fi

      - name: Assign Policy via Bicep
        run: |
          set -e
          POLICY_DEF_ID=$(az policy definition show --name allowed-vm-sizes-lab --query id -o tsv)

          az deployment sub create \
            --location australiaeast \
            --template-file assignments/assign-allowed-vms.bicep \
            --parameters policyDefinitionId=${POLICY_DEF_ID} \
            --name enforce-allowed-vm-sizes-deployment
```

---

## 🧪 Validation

```bash
# Create test resource group
az group create -n vm-lab-rg -l australiaeast

# Expect DENY: disallowed VM SKU
az vm create \
  -g vm-lab-rg \
  -n disallowedVm \
  --image Ubuntu2204 \
  --size Standard_D2s_v5 \
  --admin-username azureuser \
  --generate-ssh-keys

# Expect ALLOW: allowed VM SKU
az vm create \
  -g vm-lab-rg \
  -n allowedVm \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys
```

---

## 🧹 Cleanup

```bash
az group delete -n vm-lab-rg -y
az policy assignment delete --name enforce-allowed-vm-sizes
az policy definition delete --name allowed-vm-sizes-lab
```

---

## ✅ Key Learnings
- **Cost guardrails** via Policy prevent expensive SKU creation  
- **Bicep assignments** make governance reproducible  
- **CI/CD with GitHub Actions** ensures enforcement is automated  
