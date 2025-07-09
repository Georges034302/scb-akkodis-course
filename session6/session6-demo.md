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
      - 'session6/**'
      - 'session6/definitions/**'
      - 'session6/assignments/**'

permissions:
  id-token: write
  contents: read

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
            --rules @session6/definitions/allowedLocations/policy.json \
            --mode All \
            --display-name "Allowed Locations - Australia East Only" \
            --description "Only allow resources in australiaeast."

      - name: Assign Policy via Bicep
        run: |
          POLICY_DEF_ID=$(az policy definition show --name allowed-locations --query id -o tsv)

          az deployment sub create \
            --location australiaeast \
            --template-file session6/assignments/assign-aue-prod.bicep \
            --parameters policyDefinitionId=$POLICY_DEF_ID \
            --name assign-location-policy

```

Push all files to `main` branch to trigger CI/CD. [test the deployment and validate]

---
## ✅ Step 4: Validate in Azure Portal

- **Go to Azure Portal → Policy → Definitions**  
  *Purpose: Ensure your custom policy is present in the subscription.*

- **Navigate to Policy → Assignments**  
  *Purpose: Confirm the policy is assigned at the correct scope.*

- **Find and review the assignment `Enforce Australia East Region Only`**  
  *Purpose: Validate that the assignment name and scope are correct.*

- **Test enforcement by creating a resource group in a disallowed region:**
  ```bash
  az group create --name test-denied --location southeastasia
  ```
  *Purpose: Ensure the policy blocks non-compliant deployments as expected.*

---

## 🕵️‍♂️ Step 5: Monitor Assignment and Query Activity Logs

- **Check policy compliance status in Azure CLI:**
  ```bash
  az policy assignment list \
    --query "[?displayName=='enforce-aue-only' || name=='enforce-aue-only'].{name:name, displayName:displayName, id:id}"
  ```
  *Purpose: Confirm the policy assignment exists and get its details.*

- **Check policy state and compliance:**
  ```bash
  az policy state list \
    --filter "PolicyAssignmentName eq 'enforce-aue-only'" \
    --query "[].{resource:resourceId, compliance:complianceState}"
  ```
  *Purpose: Review which resources are compliant or non-compliant with the policy.*

---

## 🗑️ Step 6: Cleanup - Remove Policy Assignment and Definition

- **Remove the policy assignment:**
  ```bash
  az policy assignment delete \
    --name enforce-aue-only
  ```
  *Purpose: Remove the policy assignment from the subscription scope.*

- **Remove the custom policy definition:**
  ```bash
  az policy definition delete \
    --name allowed-locations
  ```
  *Purpose: Delete the custom policy definition from the subscription.*

- **Verify removal:**
  ```bash
  # verify aue enfored policy is removed
  az policy assignment list \
    --query "[?name=='enforce-aue-only']" \
    --output table
  
  # verify allowed locations policy is removed
  az policy definition list \
    --query "[?name=='allowed-locations']" \
    --output table
  ```
  *Purpose: Confirm both the assignment and definition have been removed.*

---

## 📝 Step 7: Summary

| Component      | Description                             |
| -------------- | --------------------------------------- |
| **Policy Definition** | JSON-based custom policy restricting deployments to `australiaeast` |
| **Bicep Template** | Assignment logic as Infrastructure as Code |
| **CI/CD Pipeline** | GitHub Actions to deploy policy definition and assignment |
| **Validation** | Azure Portal verification and CLI testing |
| **Monitoring** | Policy compliance tracking via Azure CLI |
| **Cleanup** | Removal of assignments and definitions |

---

🚀 This demo shows how to implement **GitOps-driven governance** using **Policy as Code**, fully auditable, repeatable, and CI/CD-enabled.

