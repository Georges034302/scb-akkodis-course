# 🛠️ Azure Policy as Code Demo: GitOps-Driven Compliance with Bicep + CI/CD

---

## 🌟 Objectives

This lab demonstrates how to implement **Policy as Code (PaC)** using **Bicep**, **Azure Policy**, and **GitHub Actions** to enforce region restrictions and governance in a reproducible and auditable way.

By completing this lab, you will:

- Author a custom policy to restrict resource deployment to `australiaeast`
- Define assignment logic using Bicep
- Set up GitHub Actions for CI/CD deployment
- Enforce policy through pull request approvals
- Validate policy assignment in Azure

---

## ✅ Prerequisites

Ensure you have:

- Azure subscription with Contributor access
- Azure CLI installed and authenticated (`az login`)
- GitHub repository (private or public)
- GitHub OIDC federation or PAT for GitHub Actions
- Optional: Visual Studio Code with Bicep extension

---

## 📂 Step 1: Create Policy Definition JSON

### 📄 File: `definitions/allowedLocations/policy.json`

```json
{
  "properties": {
    "displayName": "Allowed Locations - Australia East Only",
    "mode": "All",
    "description": "Only allow resources in australiaeast.",
    "policyRule": {
      "if": {
        "field": "location",
        "notEquals": "australiaeast"
      },
      "then": {
        "effect": "deny"
      }
    }
  }
}
```

Commit to your GitHub repository under `definitions/allowedLocations/policy.json`.

---

## 🛠️ Step 2: Define Assignment via Bicep

### 📄 File: `assignments/assign-aue-prod.bicep`

```bicep
param policyDefinitionId string = resourceId('Microsoft.Authorization/policyDefinitions', 'allowed-locations')

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-aue-only'
  properties: {
    displayName: 'Enforce Australia East Region Only'
    policyDefinitionId: policyDefinitionId
    scope: subscription().id
    enforcementMode: 'Default'
  }
}
```

Commit to `assignments/assign-aue-prod.bicep`.

---

## 📝 Step 3: Configure GitHub Actions

### 📄 File: `.github/workflows/deploy-policy.yml`

```yaml
name: Deploy Region Policy

on:
  push:
    branches: [ main ]
    paths:
      - 'definitions/**'
      - 'assignments/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Create Policy Definition
      run: |
        az policy definition create \
          --name allowed-locations \
          --rules definitions/allowedLocations/policy.json \
          --mode All \
          --display-name "Australia East Only"

    - name: Assign Policy via Bicep
      run: |
        az deployment sub create \
          --location australiaeast \
          --template-file assignments/assign-aue-prod.bicep \
          --name assign-location-policy
```

Push all files to `main` branch to trigger CI/CD.

---

## 🔑 Step 4: Enforce Pull Request Approval

1. Go to your **GitHub Repo → Settings → Branches**
2. Add a **Branch Protection Rule** for `main`
3. Enable:
   - Require pull request reviews before merging
   - Require status checks (e.g., lint, validate)
   - Limit who can push to `main`

This ensures governance teams must approve policy changes.

---

## 🔄 Step 5: Validate in Azure Portal

1. Go to **Azure Portal → Policy → Definitions** to confirm policy appears
2. Navigate to **Policy → Assignments**
3. Confirm `Enforce Australia East Region Only` is assigned
4. Deploy a test VM in `southeastasia` to see enforcement failure

---

## 🔢 Step 6: Monitor Assignment and Drift

### Optional: Run in Azure CLI

```bash
az policy state list \
  --policy-assignment-name enforce-aue-only \
  --query "[].{resource:resourceId, compliance:complianceState}"
```

### Optional: Configure Sentinel Rule

1. Use `AzureActivity` table to detect policy assignment changes:

```kql
AzureActivity
| where OperationNameValue contains "Microsoft.Authorization/policyAssignments/write"
| project TimeGenerated, Caller, ResourceGroup, ActivityStatus, Properties
```

2. Create an **Analytics Rule** to alert GRC or trigger a remediation playbook

---

## 📋 Summary

| Component      | Description                             |
| -------------- | --------------------------------------- |
| **Policy**     | Restrict deployments to `australiaeast` |
| **Bicep**      | Assignment logic as code                |
| **CI/CD**      | GitHub Actions to deploy policy + Bicep |
| **Governance** | PR approval enforced via branch rules   |
| **Monitoring** | Compliance checked in Policy + Sentinel |

---

🚀 This demo shows how to implement **GitOps-driven governance** using **Policy as Code**, fully auditable, repeatable, and CI/CD-enabled.

