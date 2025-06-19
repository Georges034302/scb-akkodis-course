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

**Goal:** Automate containment or response actions when a Sentinel incident is triggered.

1. Navigate to **Microsoft Sentinel > Automation**.
2. Click the **Playbooks** tab.
3. Click **➕ Add > Add new playbook (Consumption)**.
4. Enter the name, subscription, resource group, and region, then click **Create**.
5. Once the Logic App designer opens, select the trigger:  
   - **When a response to an Azure Sentinel alert is triggered**

**✅ Add the Following Actions (inside the Logic App):**
- **Condition:**  
  - Check if `UserPrincipalName` (from the incident entities) belongs to a privileged Azure AD group (via Graph API or Azure AD connector).
- **Disable User Account (optional):**  
  - Use Microsoft Graph API or Azure AD connector to disable the user.
- **Send Notification:**  
  - Send a message to Microsoft Teams, Email, or both — include Incident Name, Severity, Entities, and TimeGenerated.
- **Create ITSM Ticket (optional):**  
  - Use ServiceNow, Jira, or built-in Logic App connectors to log a ticket.
- **Log Action:**  
  - Write incident metadata and playbook action results to:
    - Azure Storage Account, or
    - Log Analytics (e.g., `CustomLogs_SentinelPlaybooks_CL`)
- **Save and publish** the Logic App.

---

### 🔹 Step 7: Connect the Playbook to the Alert Rule

**Goal:** Link the playbook to run automatically when the detection rule fires.

1. Go to **Microsoft Sentinel > Analytics**.
2. Open the Analytics Rule you created earlier (e.g., **Excessive Secret Access Attempt**).
3. Go to the **Automated response** tab.
4. Under **Trigger playbook on alert**, select your newly created Logic App.
5. Click **Apply**, then **Save** the rule.

---

## ✅ Success Criteria

| **Check**                             | **Expected Result**                             |
| ------------------------------------- | ----------------------------------------------- |
| Simulated secret access completed     | Multiple `Get Secret` events in AuditLogs       |
| Analytics rule triggered              | Sentinel incident created with mapped entities  |
| Playbook executed automatically       | User disabled, SOC notified, audit log archived |
| Metrics visible in workbook/dashboard | Event count, alert status, MTTR logged          |

---