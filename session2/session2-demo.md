## 📉️ Lab Title: Sentinel Lab – Key Vault Detection

---

### ✅ Prerequisites:

- Azure Subscription with Owner or Contributor access
- Microsoft Sentinel enabled on a Log Analytics Workspace
- Logic App Contributor and Security Reader roles
- Microsoft Teams integration and Graph API permissions (optional for advanced response)

---

## 📉 Step-by-Step Lab Instructions
- Use Azure Cloud Shell - Azure CLI: 👉 https://shell.azure.com

---

### 🔹 Step 1: Create a Resource Group and Key Vault

**Goal:** Deploy a controlled lab environment

```bash
RG="demo-rg"
LOCATION="australiaeast"
az group create --name "$RG" --location "$LOCATION"

az provider register --namespace Microsoft.KeyVault

KV_NAME="DemoVault$(date +%s)"
az keyvault create --name $KV_NAME --resource-group "$RG" --location "$LOCATION"
```

---

### 🔹 Step 2: Assign a Privileged Role to a Lab User

**Goal:** Simulate real-world privileged access

Use Azure Portal:
- Assign yourself **Key Vault Contributor** and **Key Vault Secrets User** roles on the vault using Access Control (IAM).

---

### 🔹 Step 3: Enable Diagnostic Settings on the Key Vault

**Goal:** Forward logs to Sentinel

```bash
az monitor log-analytics workspace create   --resource-group Demo-RG   --workspace-name log-demoworkspace   --location australiaeast

WORKSPACE_ID=$(az monitor log-analytics workspace show   --resource-group Demo-RG   --workspace-name log-demoworkspace   --query id -o tsv)

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
KV_NAME=$(az keyvault list --resource-group Demo-RG --query "[0].name" -o tsv)

az monitor diagnostic-settings create   --resource "$KV_NAME"   --resource-group Demo-RG   --resource-type "vaults"   --resource-namespace "Microsoft.KeyVault"   --workspace "$WORKSPACE_ID"   --name "LogToSentinel"   --logs '[{"category": "AuditEvent","enabled": true}]'
```

---

### 🔹 Step 4: Simulate Brute-Force Access to Key Vault

```bash
for i in {1..10}
do
  az keyvault secret show --vault-name DemoVault --name testsecret
done
```

Make sure your identity is assigned the **Key Vault Secrets User** role.

---

### 🔹 Step 5: Deploy Sentinel Analytics Rule + Attach Logic App

```bash
az deployment group create   --resource-group Demo-RG   --template-file sentinel-keyvault-rule.json   --parameters     workspaceName="log-demoworkspace"     location="australiaeast"     playbookResourceId="/subscriptions/<sub-id>/resourceGroups/Demo-RG/providers/Microsoft.Logic/workflows/DisableUserOnKVAlert"
```

📌 This ARM template includes the analytics rule and automatically attaches the Logic App playbook to trigger upon alert creation.

---

### 🔹 Step 6: Deploy Sentinel Logic App Playbook

```bash
az deployment group create   --resource-group Demo-RG   --template-file sentinel-playbook.json
```

This creates the `DisableUserOnKVAlert` Logic App which will run automatically when the analytics rule fires.

---

## 🎯 Outcome

| What to Check                 | Where                                       |
|------------------------------|---------------------------------------------|
| Alert fired?                 | Microsoft Sentinel > Incidents              |
| Playbook triggered?          | Microsoft Sentinel > Automation > Playbooks |
| Logic App run history?       | Logic App > Run history                     |
| Notifications or outputs     | Teams/Email/Storage, depending on logic     |

---

## ✅ Success Criteria

| Check                                | Expected Result                             |
|-------------------------------------|---------------------------------------------|
| Secret access simulated             | Multiple `Get Secret` logs in AuditLogs     |
| Analytics rule triggered            | Incident created in Sentinel                |
| Logic App executed automatically    | Playbook triggered by the alert             |
| Visual feedback in dashboards       | Data appears in Sentinel workbook           |

---
