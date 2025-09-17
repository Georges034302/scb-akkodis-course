## 📉️ Sentinel Lab – Key Vault Detection

---

### ✅ Prerequisites

- Azure Subscription with Owner or Contributor access
- Microsoft Sentinel enabled on a Log Analytics Workspace
- Logic App Contributor and Security Reader roles
- Microsoft Teams integration and Graph API permissions (optional for advanced response)

---

## 🚀 Step-by-Step Lab Instructions

- Use Azure Cloud Shell - Azure CLI: 👉 https://shell.azure.com

---

### 🔹 Step 1: Create a Resource Group and Key Vault

**Goal:** Deploy a controlled lab environment

```bash
./session2/env-setup.sh
```

Or manually:

```bash
# Set resource group and location variables
RG="demo-rg"
LOCATION="australiaeast"

# Create a new resource group
az group create \
  --name "$RG" \
  --location "$LOCATION"

# Register the Key Vault resource provider (if not already registered)
az provider register \
  --namespace Microsoft.KeyVault

# Generate a unique Key Vault name and create the Key Vault
KV_NAME="DemoVault$(date +%s)"
az keyvault create \
  --name "$KV_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION"
```

---

### 🔹 Step 2: Assign a Privileged Role

**Goal:** Assign **Key Vault Administrator** role on the vault (using Portal):

- Open the Azure Portal:  
  ```bash
  "$BROWSER" https://portal.azure.com
  ```
- Navigate to **Resource Groups** > **Demo-RG**
- Open your Key Vault (e.g., **DemoVault1749993950**)
- In the left-hand menu, select **Access Control (IAM)** > **Role assignments**
- Click **➕ Add** > **Add role assignment**
- For **Role**, select **Key Vault Administrator**
- For **Assign access to**, choose **User, group, or service principal**
- Select the user, group, or service principal you want to assign the role to
- Click **Save**
- Click **Review + assign**

---

### 🔹 Step 3: Enable Diagnostic Settings on the Key Vault

**Goal:** Forward logs to Sentinel for analytics

```bash
./session2/enable-logging.sh
```

Or manually:

```bash
# Create Log Analytics Workspace for Sentinel
az monitor log-analytics workspace create \
  --resource-group Demo-RG \
  --workspace-name log-demoworkspace \
  --location australiaeast

# Get Log Analytics Workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group Demo-RG \
  --workspace-name log-demoworkspace \
  --query id -o tsv)

# Get Subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get Key Vault Name in Resource Group
KV_NAME=$(az keyvault list --resource-group Demo-RG --query "[0].name" -o tsv)

# Add a Test Secret to the Key Vault
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name testsecret \
  --value "demo-value"

# Enable Diagnostic Logging for Key Vault to Sentinel
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

### 🔹 Step 4: Create KQL Analytics Rule in Microsoft Sentinel

**Goal:** Detect a spike in secret retrieval by a single user.

#### A. Enable Microsoft Sentinel on Your Workspace

1. In **Microsoft Sentinel**, go to **Overview**.
2. Find the **Analytics** view and select **Manage analytics rules**.
3. Click **➕ Create**.
4. Select the lab workspace (e.g., `log-demoworkspace` in the `Demo-RG` resource group).
5. Click **➕ Add** to enable **Microsoft Sentinel** on your workspace.

#### B. Create Analytics Rule to Detect Excessive Secret Access Attempts

1. In Microsoft Sentinel, select your workspace (e.g., `log-demoworkspace`).
2. In the left pane, select **Analytics**.
3. Click **➕ Create > Scheduled query rule**.

**General Tab:**
- **Rule Name:** Excessive Secret Access Attempt
- **Description:** Detects more than 5 secret access attempts by a single user or principal within a 5-minute window.
- **Severity:** Medium
- **MITRE ATT&CK:** Search and select `Credential Access` → `T1552 – Unsecured Credentials`
- Ensure **Status** is Enabled

**Set Rule Logic Tab:**
- **Rule query:**
  ```kusto
let Window = 5m;
AzureDiagnostics
| where OperationName == "SecretGet"
// Extract available identity claims safely
| extend UPN        = tostring(column_ifexists("identity_claim_upn_s", column_ifexists("identity_claim_name_s","")))
| extend ObjectId   = tostring(column_ifexists("identity_claim_objectidentifier_g",""))
| extend PrincipalId= tostring(column_ifexists("identity_claim_principalid_g",""))
| extend PUID       = tostring(column_ifexists("identity_claim_puid_s",""))
// Build a robust identifier for correlation
| extend AadUserId  = iff(ObjectId != "", ObjectId, iff(PrincipalId != "", PrincipalId, PUID))
// Normalize UPN if present
| extend UPN        = iif(UPN == "", "", tolower(UPN))
// Count per user per 5-minute bin
| summarize AccessCount = count(), StartTime=min(TimeGenerated), EndTime=max(TimeGenerated)
    by UPN, AadUserId, bin(TimeGenerated, Window)
| where AccessCount > 5
// Friendly display name for alert text
| extend DisplayName = iif(UPN != "", UPN, AadUserId)
| project TimeGenerated = EndTime, DisplayName, UPN, AadUserId, AccessCount
  ```

- **View query results:** Click *View query results* to validate the output (optional).

**Entity Mapping:**

| Entity Type | Identifier | KQL Column |
|-------------|------------|------------|
| Account     | AadUserId  | AadUserId  |
| Account     | Name       | UPN        |

**Custom Details:**

| Custom Detail Key   | Mapped KQL Column |
|---------------------|-------------------|
| UserPrincipalName   | UPN               |
| AccessCount         | AccessCount       |

**Alert Details:**  
- **Alert Name Format:** Excessive Key Vault Access by {{DisplayName}}
- **Alert Description Format:** Principal {{DisplayName}} accessed secrets {{AccessCount}} times in a 5-minute window.

- **Query scheduling:** Every 5 minutes
- **Lookup data from the last:** 5 minutes
- **Start running:** Automatically
- **Alert threshold:** Leave at 0 (is greater than)
- **Event grouping:** Group all events into a single alert 
- **Suppression:** Leave unchecked unless you want to prevent multiple alerts

**Incident settings Tab:** Leave everything at defaults.

**Automated response Tab:** Proceed to Step 5 if you want to attach playbooks or SOAR automation.

Click **Review + create**, then **Create** to finalize the rule.

---

### 🔹 Step 5: Create a Logic App Playbook for Automated Response

**Goal:** Automate containment or response actions when a Sentinel incident is triggered.

1. Navigate to **Microsoft Sentinel > Automation**.
2. Click **➕ Create**.
3. Select **Playbook with incident trigger**.
    - Select the subscription and resource group
    - **Playbook name:** DisableUserOnKVAlert
    - **Enable diagnostics logs in Log Analytics:** ensure it is enabled
4. Go to **Logic Apps**.
    - In the Development tools (left panel) > **Logic app templates**
    - Select **Add Trigger**
    - Search for: `Azure Sentinel` and select the type: `When a response to an Azure Sentinel alert is triggered`
    - Add Description: When a response to a Microsoft Sentinel alert is triggered
    - Click **Save**
5. Once the Logic App trigger is configured, go back to **Analytics rule wizard** > **Automation response tab**
    - **➕ Add new**
    - **Automation rule name:** Run Playbook on Excessive Access
    - **Trigger:** When incident is created
    - **Actions:**
        - Select: `Run playbook`
        - Select: `DisableUserOnKVAlert`
        - Select: `Manage Permissions` and update the permissions at Resource Group level
    - **Apply**

---

### 🔹 Step 6: Simulate Abnormal Secret Access

**Goal:** Trigger a brute-force–like pattern to mimic insider misuse

```bash
./session2/brute.sh
```

Or manually:

```bash
for i in {1..10}
do
  az keyvault secret show --vault-name DemoVault --name testsecret
done
```

- Wait 5 minutes
- Navigate to **Microsoft Sentinel** and review the **Incidents** chart (incidents will appear after 5 minutes)
- Navigate to **Log Analytics** in Azure Portal
  - Copy and paste the `AzureDiagnostics` Kusto Query
  - Run the query and review the logs

---

### 🔹 (Optional) Step 7: Add Email Notification to the Logic App

**Goal:** Enable notifications using Logic App

1. Go to Azure Portal > Logic Apps
2. Open your Logic App: **DisableUserOnKVAlert**
3. Under **Development Tools**, click **Logic App Designer**
4. Inside the trigger block, you should already see:  
   *When a response to a Microsoft Sentinel incident is triggered*
5. Click **+ New Step**
6. Search for **Outlook 365** or **Office 365 Outlook** (based on your connector)
7. Select **Send an email (V2)**
8. Fill in the email fields:

   | Field   | Value                                                      |
   |---------|------------------------------------------------------------|
   | To      | your-soc-team@yourdomain.com                               |
   | Subject | 🔐 Sentinel Alert: {{IncidentName}} - Severity {{Severity}}|
   | Body    | Use dynamic fields:<br>Alert: {{IncidentName}}<br>Time: {{StartTimeUtc}}<br>User: {{UserPrincipalName}}<br>Description: {{Description}}<br>Check Sentinel for full details. |

   🛠 If you used UPN in the query, use `@{triggerBody()?['Entities']?[0]?['UPN']}` in advanced expressions.

9. Click **Save** in the Logic App toolbar.

---

### 🔔 Now What Happens?

When the "Excessive Secret Access" rule fires, Sentinel triggers your Logic App.

Your Logic App:
- Parses the incident entity.
- Sends an email to your SOC team with dynamic incident data.

---

## ✅ Success Criteria

| **Check**                             | **Expected Result**                             |
| ------------------------------------- | ----------------------------------------------- |
| Simulated secret access completed     | Multiple `Get Secret` events in AuditLogs       |
| Analytics rule triggered              | Sentinel incident created with mapped entities  |
| Playbook executed automatically       | User disabled, SOC notified, audit log archived |
| Metrics visible in workbook/dashboard | Event count, alert status, MTTR logged          |

---