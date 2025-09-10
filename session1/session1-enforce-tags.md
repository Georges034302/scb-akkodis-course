# 🛠️ Azure Policy as Code (Tags) with Bicep + GitHub Actions

Make governance **real** on your own subscription: require an `owner` tag on every resource.  
This demo includes:  
- Project structure  
- CLI commands to scaffold it  
- Policy definition (JSON)  
- Assignment (Bicep)  
- GitHub Actions workflow (OIDC)  
- Validation and cleanup steps  

---

## 🗂️ Project Structure

```
azure-policy-tags/
├── definitions/
│   └── enforceTags/
│       └── policy.json
├── assignments/
│   ├── assign-enforce-tags.bicep
│   └── assign-enforce-tags.parameters.json
└── .github/
    └── workflows/
        └── deploy-enforce-tags.yml
```

---
## ⚙️ Bootstrap OIDC for GitHub Actions

### Create `.env` with your GitHub admin PAT
```bash
cat > .env <<'EOF'
export ADMIN_TOKEN=<your_github_admin_pat_here>
EOF
```
### Execute setup.sh
```bash
chmod +x setup.sh
./setup.sh
```
---

## ⚙️ CLI to Scaffold the Project

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="azure-policy-tags"

# Create directories
mkdir -p "$ROOT/definitions/enforceTags"
mkdir -p "$ROOT/assignments"
mkdir -p "$ROOT/.github/workflows"

# Create empty files
: > "$ROOT/definitions/enforceTags/policy.json"
: > "$ROOT/assignments/assign-enforce-tags.bicep"
: > "$ROOT/assignments/assign-enforce-tags.parameters.json"
: > "$ROOT/.github/workflows/deploy-enforce-tags.yml"
```

---

## 📄 Policy Definition

**File:** `definitions/enforceTags/policy.json`

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

## 📄 Policy Assignment (Bicep)

**File:** `assignments/assign-enforce-tags.bicep`

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
      requiredTagName: {
        value: requiredTagName
      }
    }
  }
}
```

---

## 📄 Optional Parameters File

**File:** `assignments/assign-enforce-tags.parameters.json`

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

## 📄 GitHub Actions Workflow

**File:** `.github/workflows/deploy-enforce-tags.yml`

```yaml
name: Deploy Enforce-Tag Policy

on:
  push:
    branches:
      - main
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
          if az policy definition show --name require-tag-any >/dev/null 2>&1; then
            az policy definition update \
              --name require-tag-any \
              --rules @definitions/enforceTags/policy.json \
              --mode Indexed \
              --display-name "Require Tag on Resources" \
              --description "Deny creation of resources without required tag."
          else
            az policy definition create \
              --name require-tag-any \
              --rules @definitions/enforceTags/policy.json \
              --mode Indexed \
              --display-name "Require Tag on Resources" \
              --description "Deny creation of resources without required tag."
          fi

      - name: Assign Policy via Bicep
        run: |
          set -e
          POLICY_DEF_ID=$(az policy definition show --name require-tag-any --query id -o tsv)

          az deployment sub create \
            --location australiaeast \
            --template-file assignments/assign-enforce-tags.bicep \
            --parameters policyDefinitionId=${POLICY_DEF_ID} requiredTagName=owner \
            --name enforce-required-tag-deployment
```

---

## 🧪 Validation

```bash
# Expect DENY (missing tag)
az group create \
  -n demo-untagged-rg \
  -l australiaeast

# Expect ALLOW (tag present)
az group create \
  -n demo-tagged-rg \
  -l australiaeast \
  --tags owner=georges

# Verify assignment exists
az policy assignment list \
  --query "[?name=='enforce-required-tag']" \
  -o table

# Inspect compliance (may take a few minutes)
az policy state list \
  --filter "PolicyAssignmentName eq 'enforce-required-tag'" \
  --query "[].{resource:resourceId, compliance:complianceState}" \
  -o table
```

---

## 🧹 Cleanup

```bash
az group delete \
  -n demo-tagged-rg \
  -y

az policy assignment delete \
  --name enforce-required-tag

az policy definition delete \
  --name require-tag-any
```
