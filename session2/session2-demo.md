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

Before running this, ensure your user (e.g., <your-azure-account-email>) has been assigned the Key Vault Secrets User role on the vault.
- Go to the Key Vault in Azure Portal (e.g., DemoVault...)
- Click Access control (IAM) → + Add → Add role assignment
- Select role: Key Vault Secrets User
- Assign access to: User
- Select your own name from the list
- Click Review + assign
---

### 🔹 Step 5: Create KQL Analytics Rule in Microsoft Sentinel

#### **Goal:**  
Detect a spike in secret retrieval by a single user.

---

#### **A. Enable Microsoft Sentinel on Your Workspace**

1. Go to the [Azure Portal](https://portal.azure.com).
2. In the top search bar, type **Microsoft Sentinel** and open it.
3. Click **➕ Add**.
4. In the **Subscription** dropdown, select the subscription where your Log Analytics workspace was created.
5. In the **Workspace** dropdown, select your workspace (e.g., `log-demoworkspace` in the `Demo-RG` resource group).
6. Click **Add Microsoft Sentinel** to enable it on your workspace.

---

#### **B. Create Analytics Rule to Detect Excessive Secret Access Attempts**

1. In Microsoft Sentinel, select your workspace (e.g., `log-demoworkspace`).
2. In the left pane, select **Analytics**.
3. Click **➕ Create > Scheduled query rule**.

**General Tab:**
- **Rule Name:** Excessive Secret Access Attempt
- **Description:** Detects more than 5 secret access attempts by a single user within a 5-minute window.

**Set Rule Logic Tab:**
- Paste the following KQL query into the rule logic section:
  ```kusto
  AuditLogs
  | where ActivityDisplayName == "Get Secret"
  | extend UPN = tostring(InitiatedBy.user.userPrincipalName)
  | summarize AccessCount = count() by UPN, bin(TimeGenerated, 5m)
  | where AccessCount > 5
  ```
- **View query results:** Click *View query results* to validate the output (optional but recommended).
- **Query scheduling:** Every 5 minutes
- **Lookup data from the last:** 5 minutes
- **Start running:** Choose a future start time or leave default (e.g., 17/06/2025, 12:00 PM)
- **Alert threshold:** Leave at 0 (generate an alert for any result returned)
- **Event grouping:** Optional — group all results into a single alert or group by UPN
- **Suppression:** Leave unchecked unless you want to prevent multiple alerts for the same behavior within a suppression window

**Entity Mapping Tab:**
- **Map User → UPN**

**Custom Details Tab:**
- (Optional) Add custom fields from the query you wish to expose in alerts.

**Actions Tab (Optional):**
- Add a playbook (Logic App) if you wish to automate the response (e.g., disable the user or send a Teams alert).

---

4. Click **Review + create**, then **Create** to finalize the rule.

---

> **Azure Best Practice:**  
> - Always use Azure Portal or Azure CLI for configuring Sentinel and analytics rules.
> - Use clear, descriptive rule names and document your detection logic.
> - Schedule queries at intervals that balance detection speed and resource usage.
> - Map entities for better incident investigation and automation.
> - Use playbooks for automated response to high-risk incidents.

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
