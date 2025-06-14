# 🧪 Hands-On Lab: Sentinel Lab – Key Vault Detection

## 🏷️ Lab Title
Detect and Respond to Suspicious Access Patterns in Azure Key Vault Using Microsoft Sentinel

---

## 🎯 Lab Objective
Simulate abnormal secret access from a privileged user in Azure Key Vault and automatically detect and respond using Microsoft Sentinel analytics rules and Logic App playbooks.

---

## ✅ Lab Scenario
A privileged identity accesses secrets excessively from a Key Vault, possibly indicating misuse or credential compromise.

**Lab goals:**
- Enable diagnostic logging on Key Vault  
- Stream logs to Sentinel  
- Write a KQL detection rule  
- Automate incident response using a Logic App playbook

---

## 🧰 Pre-Requisites
- Azure Subscription  
- Sentinel-enabled Log Analytics Workspace  
- Azure CLI installed and authenticated (`az login`)  
- Microsoft Teams integration (for notification)  
- Permission to create Key Vault, Logic Apps, RBAC roles

---

## 🛠️ Step-by-Step Instructions

### 🔹 Step 1: Create Resource Group & Key Vault

```bash
az group create \
  --name Demo-RG \
  --location australiaeast

az keyvault create \
  --name DemoVault \
  --resource-group Demo-RG \
  --location australiaeast
```

---

### 🔹 Step 2: Assign Privileged Role to Lab User

```bash
az role assignment create \
  --assignee <user-upn> \
  --role 'Key Vault Contributor' \
  --scope /subscriptions/<sub-id>/resourceGroups/Demo-RG/providers/Microsoft.KeyVault/vaults/DemoVault
```

---

### 🔹 Step 3: Enable Diagnostic Logging on Key Vault

```bash
az monitor diagnostic-settings create \
  --resource /subscriptions/<sub-id>/resourceGroups/Demo-RG/providers/Microsoft.KeyVault/vaults/DemoVault \
  --workspace <workspace-id> \
  --name "LogToSentinel" \
  --logs '[{"category": "AuditEvent","enabled": true}]'
```

---

### 🔹 Step 4: Simulate Abnormal Secret Access

```bash
for i in {1..10}; do \
  az keyvault secret show \
    --vault-name DemoVault \
    --name testsecret; \
done
```

---

### 🔹 Step 5: Create Analytics Rule in Sentinel

Go to **Microsoft Sentinel > Analytics > + Create Rule**

Paste this KQL:

```kql
AuditLogs
| where ActivityDisplayName == "Get Secret"
| summarize AccessCount = count() by UserPrincipalName, bin(TimeGenerated, 5m)
| where AccessCount > 5
```

Configure alert thresholds, set frequency (5 min), and map entities.

---

### 🔹 Step 6: Create Logic App Playbook

In **Sentinel > Automation > Playbooks**:

- Trigger: *When an incident is created in Sentinel*
- Condition: User in privileged group
- Actions:
  - Disable user via Graph API
  - Send Teams alert
  - Create ServiceNow ticket
  - Archive incident to Blob or Log Analytics

---

### 🔹 Step 7: Connect Playbook to Rule

In the analytic rule settings:

- Go to **Automated Response**
- Attach your Logic App under “Trigger playbook on alert”

---

## ✅ Success Criteria

| ✅ Check                         | 🧪 How to Validate                            |
|----------------------------------|-----------------------------------------------|
| Secrets accessed excessively     | Logs show 10+ `Get Secret` events             |
| Sentinel rule triggered          | Incident created in Sentinel                  |
| Playbook executed automatically  | User disabled, SOC notified                   |
| Results visible in dashboards    | Event metrics in Workbooks                    |

---
