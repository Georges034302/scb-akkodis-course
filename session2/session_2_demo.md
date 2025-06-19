## 📉️ Lab Title: Sentinel Lab – Key Vault Detection

---

### ✅ Prerequisites

- Azure Subscription with Owner or Contributor access
- Microsoft Sentinel enabled on a Log Analytics Workspace
- Logic App Contributor and Security Reader roles
- Microsoft Teams integration and Graph API permissions *(optional for advanced response)*

---

## 🧪 Step-by-Step Lab Instructions

👉 Use Azure Cloud Shell (Azure CLI): [https://shell.azure.com](https://shell.azure.com)

---

### 🔹 Step 1: Create a Resource Group and Key Vault

**🎯 Goal:** Deploy a controlled lab environment

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

### 🔹 Step 2: Assign Privileged Access to a Lab User

**🎯 Goal:** Simulate real-world privileged access for testing and monitoring

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to: **Resource Groups** → `Demo-RG`
3. Open the Key Vault (e.g., `DemoVault1749993950`)
4. Click: **Access control (IAM)** → ➕ **Add role assignment**
5. Choose:
   - **Role:** Key Vault Administrator
   - **Assign access to:** User
   - **Select:** Your own name
6. Click **Review + assign**

> 💡 **Tips**:
>
> - Assign **Key Vault Administrator** for full permissions
> - Assign **Key Vault Contributor** for limited test-user permissions

---

### 🔹 Step 3: Enable Diagnostic Settings on the Key Vault

**🎯 Goal:** Forward logs to Sentinel for analytics

#### 3.1 Create a Log Analytics Workspace (if needed)

```bash
az monitor log-analytics workspace create \
  --resource-group Demo-RG \
  --workspace-name log-demoworkspace \
  --location australiaeast
```

#### 3.2 Retrieve Resource Identifiers

```bash
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group Demo-RG \
  --workspace-name log-demoworkspace \
  --query id -o tsv)

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
KV_NAME=$(az keyvault list --resource-group Demo-RG --query "[0].name" -o tsv)
```

#### 3.3 Generate Test Activity

```bash
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name testsecret \
  --value "demo-value"
```

#### 3.4 Enable Diagnostic Logging

```bash
az monitor diagnostic-settings create \
  --name "LogToSentinel" \
  --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/Demo-RG/providers/Microsoft.KeyVault/vaults/$KV_NAME" \
  --workspace "$WORKSPACE_ID" \
  --logs '[{"category":"AuditEvent","enabled":true}]'
```

---

### 🔹 Step 4: Create KQL Analytics Rule in Microsoft Sentinel

**🎯 Goal:** Detect spike in secret retrievals by a single user

---

#### Option A: Enable Sentinel Using ARM Template

```bash
az deployment group create \
  --resource-group Demo-RG \
  --template-file sentinel-keyvault-rule.json
```

---

#### Option B: Enable Sentinel Using Azure Portal

- Open **Microsoft Sentinel**
- Click ➕ **Create** → Add your workspace
- Open the workspace → Go to **Analytics** → **Manage Analytics Rules**
- Click ➕ **Create** → **Schedule Query Rule**

---

#### Fill In the Analytics Rule:

- **Name:** Excessive Secret Access Attempt
- **Description:** More than 5 accesses to Key Vault secrets within 5 mins
- **Security Level:** Medium or High
- **MITRE ATT&CK:**
  - Tactic: Credential Access
  - Technique: T1552 – Unsecured Credentials
- **Status:** Enabled

##### KQL Query:

```kusto
AzureDiagnostics
| where OperationName == "SecretGet"
| extend UPN = tostring(identity_claim_unique_name_s)
| summarize AccessCount = count() by UPN, bin(TimeGenerated, 5m)
| where AccessCount > 5
```

##### Alert Enhancements:

- **Entity Mapping:** Account → UPN
- **Custom Details:**
  - UserPrincipalName → `UPN`
- **Alert Format:**
  - **Name:** Excessive Secret Access by {{UPN}}
  - **Description:** {{AccessCount}} access attempts in 5 minutes

##### Query Scheduling:

- **Frequency:** Every 5 minutes
- **Lookback Window:** 5 minutes
- **Alert Threshold:** Greater than 0
- **Grouping:** Single alert
- **Suppression:** Off

Click **Next → Next → Automated Response**

---

#### In Automated Response Tab:

- ➕ **Add New Automation Rule**
  - **Rule Name:** Run Playbook on Excessive Access
  - **Trigger:** When incident is created
  - **Action:** Run playbook → Select `DisableUserOnKVAlert`
  - **Manage Permissions:** Select Resource Group → Click **Apply**

---

### 🔹 Step 5: Create a Logic App Playbook for Automated Response

**🎯 Goal:** Automatically contain or respond to incidents

---

#### Option A: Using ARM Template

```bash
az deployment group create \
  --resource-group Demo-RG \
  --template-file sentinel-playbook.json
```

---

#### Option B: Using Azure Portal

1. Go to **Microsoft Sentinel > Workspace > Automation**
2. Click ➕ **Create** → **Playbook with incident trigger**
3. Fill out form:
   - **Subscription:** Active subscription
   - **Resource Group:** Demo-RG
   - **Region:** Australia East
   - **Playbook Name:** DisableUserOnKVAlert
4. Click **Review + Create**

---

#### Add Trigger in Logic App Designer

- Go to your **Logic App**
- Open ⚙️ **Logic App Templates** → Select **Blank Workflow**
- Add Trigger:
  - **Search:** Microsoft Sentinel
  - **Choose:** When a response to a Sentinel incident is triggered
- Click **Save**

---

### 🔹 Step 6: Connect Playbook to Alert Rule

**🎯 Goal:** Link Logic App to Sentinel analytics alert

---

#### Use Azure Portal:

| Field     | Value                                    |
| --------- | ---------------------------------------- |
| Name      | Run Playbook on Excessive Access         |
| Trigger   | ✅ When an alert is created               |
| Condition | Analytics Rule = Excessive Secret Access |
| Action    | Run playbook                             |
| Playbook  | DisableUserOnKVAlert                     |

---

### 🔹 Step 7: Simulate Abnormal Secret Access

**🎯 Goal:** Trigger an alert by mimicking brute-force access behavior

```bash
for i in {1..10}
do
  az keyvault secret show --vault-name "<Key Vault Name>" --name testsecret
done
```

---

### 🔎 What Should Happen

1. Key Vault logs are sent to Log Analytics
2. Sentinel Analytics Rule evaluates activity
3. If access threshold exceeded:
   - 🔔 Alert generated
   - 🔀 Automation Rule fires
   - ⚙️ Logic App executes → disables user, sends notification, logs response

---

### ✅ Validate Your Setup

| Check                              | Where                                       |
| ---------------------------------- | ------------------------------------------- |
| Alert triggered                    | Microsoft Sentinel > Incidents              |
| Playbook executed                  | Microsoft Sentinel > Automation > Playbooks |
| Logic App run history              | Logic App > Run history                     |
| Email/Teams/Storage logs generated | As configured in Logic App steps            |

---

### 💬 Add Teams or Email Notifications (Optional)

1. Go to Logic App → `DisableUserOnKVAlert`
2. Click **Edit in Designer**
3. After Sentinel trigger → ➕ **New Step**
4. Choose an action:
   - 🔔 Send Microsoft Teams message
   - 📧 Send email (V2)
   - 📟 Post adaptive card to Teams

---

## 🏁 Success Criteria

| ✅ Check                  | 🧪 Expected Result                          |
| ------------------------ | ------------------------------------------- |
| Simulated secret access  | Audit logs show repeated `SecretGet` events |
| Analytics rule triggered | Sentinel incident created                   |
| Playbook executed        | User disabled, notification sent            |
| Dashboard visibility     | Event count and MTTR appear in workbook     |

---

