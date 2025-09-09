# 🛡️ Lab 5-E: Enforce Region Policy with Azure Policy in CI/CD

## 🎯 Objectives

- Define and assign an Azure Policy to enforce regional compliance
- Integrate Azure Policy into GitHub Actions CI/CD workflow
- Use ARM/Bicep templates and Azure CLI in GitHub Actions
- Deny deployments to any region except `australiaeast`

---

## 🛠️ Requirements

| Requirement         | Description                                                  |
| ------------------- | ------------------------------------------------------------ |
| ✅ Azure CLI         | Installed and authenticated (`az login`)                    |
| ✅ GitHub CLI        | Installed and authenticated using PAT (Lab 5-A)             |
| ✅ `.env` file       | Contains Azure credentials and is in `.gitignore`           |
| ✅ GitHub Secrets    | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| ✅ App repo setup    | Contains session6/policy files with definition and assignment |

---

## 📁 Project Structure

### Step 1. ⚙️ Create Project Files

```bash
mkdir -p week5/definitions/allowedLocations
mkdir -p week5/assignments
touch week5/definitions/allowedLocations/policy.json
touch week5/assignments/assign-aue-prod.bicep
```
#### ✅ Expected Outcome:

```bash
📁 your-repo/
└── week5/
    ├── definitions/
    │   └── allowedLocations/
    │       └── policy.json
    └── assignments/
        └── assign-aue-prod.bicep
```

### Step 2. 🔖 Policy Definition File

`week56/definitions/allowedLocations/policy.json`:

```json
{
  "if": {
    "field": "location",
    "notEquals": "australiaeast"
  },
  "then": {
    "effect": "deny"
  }
}
```

---

### Step 3. 🧱 Bicep Assignment Template

`week5/assignments/assign-aue-prod.bicep`:

```bicep
param policyDefinitionId string

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'enforce-australiaeast-only'
  properties: {
    displayName: 'Enforce Australia East Region'
    policyDefinitionId: policyDefinitionId
    scope: subscription().id
  }
}
```

---

## 🤖 GitHub Actions Workflow

### ✨ Create CI/CD workflow: `.github/workflows/deploy-region-policy.yml`

```yaml
name: Deploy Region Policy

on:
  push:
    branches: [ main ]
    paths:
      - 'session6/**'
      - '.github/workflows/deploy-region-policy.yml'

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

      - name: Create Region Policy Definition
        run: |
          az policy definition create \
            --name allowed-locations \
            --rules @week5/definitions/allowedLocations/policy.json \
            --mode All \
            --display-name "Allowed Locations - Australia East Only" \
            --description "Only allow resource creation in australiaeast."

      - name: Assign Region Policy via Bicep
        run: |
          POLICY_DEF_ID=$(az policy definition show --name allowed-locations --query id -o tsv)

          az deployment sub create \
            --location australiaeast \
            --template-file week5/assignments/assign-aue-prod.bicep \
            --parameters policyDefinitionId=$POLICY_DEF_ID \
            --name assign-location-
```

### 🚀 Deploy Policy in CI/CD workflow

```bash
git add .
git commit -m "Azure Policy definition - Enforce Location"
git push
```

## 🧪 Post-Deployment Testing

### 🧾 List All Policy Assignments

```bash
az policy assignment list \
  --query "[].{Name:name, Scope:scope, DisplayName:displayName}" \
  --output table
```
> ➡️ This will show all assignments, including their names and scopes (e.g., subscription or resource group).

### 🔎 Show Details of a Specific Assignment

```bash
az policy assignment show \
  --name enforce-allowed-locations \
  --output json
```
> ➡️ Replace enforce-allowed-locations with your actual assignment name (if different).

### ❌ Test Non-Compliant Resource

```bash
az group create \
  --name test-nsw-rg \
  --location australiasoutheast
```
> Expected Result: ❌ Fails with a policy violation error\
> Reason: Location australiasoutheast is not allowed.

### ❌ Test Non-Compliant Storage Account 

```bash
az storage account create \
  --name teststorage123456 \
  --resource-group test-aue-rg \
  --location australiasoutheast \
  --sku Standard_LRS
```
>Expected Result: ❌ Fails with policy denial\
>Reason: Location is outside of allowed region (australiaeast).

---

## 🧹 Remove the Policy Assignment and Definition

### ❌ Remove the Policy Assignment

```bash
az policy assignment delete \
  --name enforce-allowed-locations
```
>✅ This removes the active enforcement on the scope.

### 🧻 Delete the Policy Definition

```bash
az policy definition delete \
  --name allowed-locations
```
>✅ This removes the custom policy definition itself from your subscription.

---

## ✅ Lab Complete

You have:

- 🛡️ Defined an Azure Policy to restrict resources to `australiaeast`
- 🤖 Automated the definition and assignment via GitHub Actions
- 🧱 Used a Bicep template to assign policy at the subscription scope
- 🔐 Secured access using GitHub OIDC authentication and Azure secrets
