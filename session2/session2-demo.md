## 📉️ Lab Title: Sentinel Lab – Key Vault Detection

---

### ✅ Prerequisites:

- Azure Subscription with Owner or Contributor access
- Microsoft Sentinel enabled on a Log Analytics Workspace
- Logic App Contributor and Security Reader roles
- Microsoft Teams integration and Graph API permissions (optional for advanced response)

---

## 📉 Step-by-Step Lab Instructions

---

### 🔹 Step 1: Create a Resource Group and Key Vault

**Goal:** Deploy a controlled lab environment

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

### 🔹 Step 2: Assign a Privileged Role to a Lab User

**Goal:** Simulate real-world privileged access

1. Identify or create a user (`PrivilegedLabUser`)
2. Assign **Key Vault Contributor** role on the vault:

```bash
az role assignment create \
  --assignee <user-upn> \
  --role 'Key Vault Contributor' \
  --scope /subscriptions/<subscription-id>/resourceGroups/Demo-RG/providers/Microsoft.KeyVault/vaults/DemoVault
```

---

### 🔹 Step 3: Enable Diagnostic Settings on the Key Vault

**Goal:** Forward logs to Sentinel for analytics

1. Ensure you have a Log Analytics Workspace connected to Sentinel
2. Enable diagnostic logging:

```bash
az monitor diagnostic-settings create \
  --resource /subscriptions/<subscription-id>/resourceGroups/Demo-RG/providers/Microsoft.KeyVault/vaults/DemoVault \
  --workspace <workspace-id> \
  --name "LogToSentinel" \
  --logs '[{"category": "AuditEvent","enabled": true}]'
```

---

### 🔹 Step 4: Simulate Abnormal Secret Access

**Goal:** Trigger a brute-force–like pattern to mimic insider misuse

```bash
for i in {1..10}
do
  az keyvault secret show --vault-name DemoVault --name testsecret
done
```

You can also use PowerShell or SDK scripts to automate parallel requests.

---

### 🔹 Step 5: Create KQL Analytics Rule in Microsoft Sentinel

**Goal:** Detect spike in secret retrieval by a single user

```kql
AuditLogs
| where ActivityDisplayName == "Get Secret"
| summarize AccessCount = count() by UserPrincipalName, bin(TimeGenerated, 5m)
| where AccessCount > 5
```

- Go to **Microsoft Sentinel > Analytics > + Create Rule**
- Use the KQL above in the Detection rule logic
- Set evaluation interval (every 5 min) and alert threshold
- Map relevant entities (UserPrincipalName)

---

### 🔹 Step 6: Create a Logic App Playbook for Automated Response

**Goal:** Automate containment when an alert is triggered

1. Go to **Sentinel > Automation > Playbooks > + Add**
2. Use **Trigger: When an incident is created in Sentinel**
3. Add actions:
   - **Condition**: Is `UserPrincipalName` in Privileged Group?
   - **Disable user** (AzureAD or Graph API)
   - **Send notification** to Microsoft Teams or Email
   - **Create ITSM ticket** (optional: ServiceNow or Logic App connector)
   - **Log action** to Storage Account or Log Analytics

---

### 🔹 Step 7: Connect the Playbook to the Alert Rule

1. Open the Analytics Rule created earlier
2. Go to the **Automated Response** tab
3. Select your Logic App under “Trigger playbook on alert”

---

## ✅ Success Criteria

| **Check**                             | **Expected Result**                             |
| ------------------------------------- | ----------------------------------------------- |
| Simulated secret access completed     | Multiple `Get Secret` events in AuditLogs       |
| Analytics rule triggered              | Sentinel incident created with mapped entities  |
| Playbook executed automatically       | User disabled, SOC notified, audit log archived |
| Metrics visible in workbook/dashboard | Event count, alert status, MTTR logged          |

---

## 📆 Demo Summary for README.md

### 💪 Hands-On Lab: Sentinel Lab – Key Vault Detection

#### 🏷️ Lab Title

Detect and Respond to Suspicious Access Patterns in Azure Key Vault Using Microsoft Sentinel

#### 🌟 Lab Objective

Simulate and detect excessive secret access by a privileged identity, trigger a Microsoft Sentinel analytics rule, and automate the response using a Logic App to disable the account and notify the SOC team.

#### ✅ Lab Scenario

A privileged user retrieves secrets from Azure Key Vault more frequently than expected, indicating possible insider threat or credential misuse.

### 🔧 Lab Steps Overview

| Setup Step | Description                                      |
| ---------- | ------------------------------------------------ |
| 1          | Create Resource Group and Key Vault              |
| 2          | Assign Key Vault Contributor role to a test user |
| 3          | Enable diagnostic logging to Log Analytics       |

| Detection Step | Description                                  |
| -------------- | -------------------------------------------- |
| 1              | Simulate 10 secret retrievals using CLI loop |
| 2              | Author Sentinel Analytics Rule using KQL     |

| Response Step | Description                                 |
| ------------- | ------------------------------------------- |
| 1             | Create Logic App Playbook for auto-response |
| 2             | Connect playbook to analytics rule          |

| Expected Outcome | Description                                                |
| ---------------- | ---------------------------------------------------------- |
| 1                | Sentinel incident created upon detection                   |
| 2                | User account automatically disabled via Graph API          |
| 3                | SOC notified via Teams                                     |
| 4                | Event archived and metrics visible in Workbooks/Dashboards |
| 5                | End-to-end audit-traceable response workflow confirmed     |

---

