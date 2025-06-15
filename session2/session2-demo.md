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
RG="demo-rg"
LOCATION="australiaeast"
az group create \
  --name "$RG" \
  --location "$LOCATION"

az provider register \
  --namespace Microsoft.KeyVault

KV_NAME="DemoVault$(date +%s)"
az keyvault create \
  --name $KV_NAME \
  --resource-group "$RG" \
  --location "$LOCATION"
```

---

### 🔹 Step 2: Assign a Privileged Role to a Lab User

**Goal:** Simulate real-world privileged access

1. Identify or create a user (`PrivilegedLabUser`)
2. Assign **Key Vault Contributor** role on the vault (using Portal):

   - Go to the Azure Portal: [https://portal.azure.com](https://portal.azure.com)
   - Navigate to **Resource Groups** > **Demo-RG**
   - Open your Key Vault (e.g., **DemoVault1749993950**)
   - In the left-hand menu, select **Access Control (IAM)** > **Role assignments**
   - Click **➕ Add** > **Add role assignment**
   - For **Role**, select **Key Vault Contributor**
   - For **Assign access to**, choose **User, group, or service principal**
   - Select the user, group, or service principal you want to assign the role to
   - Click **Save**

---

### 🔹 Step 3: Enable Diagnostic Settings on the Key Vault

**Goal:** Forward logs to Sentinel for analytics

1. Ensure you have a Log Analytics Workspace connected to Sentinel
   
```bash
az monitor log-analytics workspace create \
  --resource-group Demo-RG \
  --workspace-name log-demoworkspace \
  --location australiaeast
```

2. Enable diagnostic logging:

```bash
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group Demo-RG \
  --workspace-name log-demoworkspace \
  --query id -o tsv)

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
KV_NAME=$(az keyvault list --resource-group Demo-RG --query "[0].name" -o tsv)

az monitor diagnostic-settings create \
  --resource "$KV_NAME" \
  --resource-group Demo-RG \
  --resource-type "vaults" \
  --resource-namespace "Microsoft.KeyVault" \
  --workspace "$WORKSPACE_ID" \
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
