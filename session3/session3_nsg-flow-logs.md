## 🧪 NSG Flow Visibility Lab – 🔒 Monitor and Block Intra-VNet Traffic

---

### 🛠️ Prerequisites:

- Azure Subscription with Contributor or Owner access
- Azure CLI installed and authenticated

---

## 🗭 Step-by-Step Lab Instructions

---

### 🚀 Step 1: Deploy Infrastructure

**Goal:** Provision a secure VNet setup with NSG and diagnostic visibility via Flow Logs

---

#### 🛡️ Option A: Create Resource group and deploy the Bicep file `nsg_flow.bicep`

```bash
az group create \
  --name rg-flow-lab \
  --location australiaeast

az network watcher configure \
  --locations australiaeast \
  --resource-group rg-flow-lab \
  --enabled true

az deployment group create \
  --resource-group rg-flow-lab \
  --template-file nsg_flow.bicep \
  --parameters adminPassword=$(read -s -p "Enter admin password: " pwd; echo $pwd)
```

---

#### 💻 Option B: Deploy Using Azure CLI

```bash
cd session3
bash nsg_flow.sh
```

---

### 📦 Step 3: Enable Virtual Network Flow Logs (Manual)

#### A: Send VNet flow logs to Log Analytics workspace

1. Open the Azure Portal:
   ```bash
   "$BROWSER" https://portal.azure.com
   ```
2. Go to **Virtual Networks** and select `vnet-demo`.
3. In the left menu, select **Diagnostic settings**.
4. Click **+ Add diagnostic setting**.
5. Name your setting (e.g., `flowlogs-to-law`).
6. Check **Send to Log Analytics workspace** and select your workspace (e.g., `flowlog-law`).
7. Optionally, also send to a storage account.
8. Under **Log**, check **Flow logs**.
9. Click **Save**.

> **Important:**  
> For full visibility, repeat steps 1–9 above for your **Network Security Group** (e.g., `nsg-app`). \
> Repeat the same process for the Network Interfaces (NICs) of both VMs (`vm-web` and `vm-app`).  
> This ensures that your VNet, NSG, and both VM NICs are sending flow logs to your Log Analytics workspace and storage account.
> - To verify, Search for: Network Watcher
> - Go to Logs > Diagonistic Logs
> - Ensure that diagonistics is enable for NSG and both NICs

---

#### B: Enable Network Watcher for VNet logs

1. Open **Azure Portal** and search for **Network Watcher**.
2. In the left panel, select **Logs > Flow Logs**.
3. Click **➕ Create**.
   - **Basics Tab:**
     - **Flow log type:** `Virtual Network`
     - **Target Resource:** select `vnet-demo` (your deployed VNet)
     - **Location:** `australiaeast`
   - **Destination settings:**
     - **Storage account:** select the one created by your deployment (e.g., `flowlogstorageabcd1234`)
       - Do *not* accept a random auto-generated account (e.g., `flsay...`)
     - Assign the following roles to your signed-in identity (if not already granted):
       - `Storage Blob Data Contributor`
       - `Storage Blob Data Owner`
     - **Retention:** set to 30 days (or adjust per your policy)
   - **Analytics Tab:**
     - **Flow logs version:** `Version 2`
     - **Enable Traffic Analytics:** Yes
       - **Interval:** `10 minutes`
       - **Log Analytics workspace:** select `flowlog-law`
   - **Review + Create**

> **Important:**  
> Repeat the above process for the **Network Interfaces (NICs) of both VMs** (`vm-web` and `vm-app`) to ensure flow logs are collected for all relevant resources.
---

### 🔍 Step 4: Post-Deployment Testing

#### Enviroment Variables:
```bash
# Resource group and VM names
RG=rg-flow-lab
VM_WEB=vm-web
VM_APP=vm-app
ADMIN_USER=azureuser   # change if your template used a different username
```

#### Get Private & Public IPs 

```bash
# Get public IP of vm-web (jump host)
VM_WEB_PIP=$(az vm show -g $RG -n $VM_WEB --show-details --query publicIps -o tsv)

# Get private IP of vm-app (target of blocked SSH)
VM_APP_PRIV=$(az vm show -g $RG -n $VM_APP --show-details --query privateIps -o tsv)

# Display the results
echo "vm-web public IP : $VM_WEB_PIP"
echo "vm-app private IP: $VM_APP_PRIV"

```

#### ❌ Test Direct SSH to vm-app (Expected to Fail)

```bash
ssh $ADMIN_USER@$VM_APP_PRIV
```
⏳ This should timeout or deny connection — confirming NSG is blocking SSH.


#### ✅ Test SSH to vm-web (Expected to Succeed)

```bash
ssh $ADMIN_USER@$VM_WEB_PIP
```
⏳ This should succeed — vm-web has a public IP with SSH allowed.


#### ❌ From vm-web → vm-app (Expected to Fail)
```bash
ssh $ADMIN_USER@$VM_APP_PRIV
```
⏳ Run this command inside vm-web after logging in. It should fail — proving the NSG blocks intra-VNet SSH traffic.

---

### 📂 Step 4: Inspect Flow Logs (Portal or CLI)

#### 🔢 Option A: Using Azure Portal

1. Go to Storage accounts → (name starts with flowlogstorage...). 
2. Open `insights-logs-flowlogflowevent` container
3. Navigate into the folder structure: `year/month/day/hour`
4. Open a JSON log blob and inspect entries like:
   ```
   "10.100.1.4,10.100.2.5,57232,22,T,I,D,U,..."
   ```
   - `D` = Denied, `T` = TCP, `22` = SSH

#### 🔢 Option B: Using CLI

> **Before running the commands below, make sure you have the correct permissions on the storage account:**
>
> 1. In the Azure Portal, go to **Storage accounts** → select your storage account (e.g., `flowlogstorage...`)
> 2. In the left menu, select **Access control (IAM)**
> 3. Click **+ Add > Add role assignment**
> 4. Assign yourself one of the following roles (in order of preference):
>    - **Storage Blob Data Owner**
>    - **Storage Blob Data Contributor**
>    - **Storage Blob Data Reader**
> 5. Scope: Assign at the storage account level for least privilege.
> 6. Wait a few minutes for the role assignment to propagate.

```bash
# Get the storage account name deployed in the resource group
STORAGE_ACCOUNT=$(az storage account list -g $RG --query "[0].name" -o tsv)

# Dynamically get the container name for NSG flow logs
# The correct Azure CLI command is 'az storage container list' (not 'az storage.container.list')
CONTAINER=$(az storage container list --account-name $STORAGE_ACCOUNT --query "[?contains(name, 'flowlogflowevent')].name" -o tsv)

# Get latest blob path
BLOB_PATH=$(az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --auth-mode login \
  --query "[-1].name" -o tsv)

echo "Latest flow log blob: $BLOB_PATH"

# Download the blob (if found)
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name "$BLOB_PATH" \
  --file ./flowlog.json \
  --auth-mode login
echo "Downloaded flowlog.json"
```

Then open `flowlog.json` locally to examine flow tuples.

---

### 🥪 Step 5: Analyze Flow Logs with KQL in Log Analytics (Optional)

After generating denied SSH attempts in Step 3, check the logs.
> ⏳ Note: Flow Logs typically appear 15–20 minutes after traffic occurs (collection + pipeline delay).
> Prereqs: Flow logs linked to flowlog-law, Traffic Analytics enabled..

> Prerequisites:
>
> - Flow logs must be linked to `flowlog-law`
> - Traffic Analytics enabled

#### 1. Open Log Analytics:

- Go to **Log Analytics Workspaces** in Azure Portal
- Select `flowlog-law` > **Logs**

#### 2. Run KQL Queries:

**A. Recent NSG flow events (quick view)**

```kql
AzureDiagnostics
| where Category == "NetworkSecurityGroupEvent"
| project TimeGenerated, srcIp_s, destIp_s, destPort_s, protocol_s, action_s, ruleName_s
| order by TimeGenerated desc
```
**B. Denied SSH from vm-web → vm-app (most relevant)**
```kql
AzureDiagnostics
| where Category == "NetworkSecurityGroupEvent"
| where destPort_s == "22" and protocol_s =~ "TCP" and action_s =~ "Deny"
| project TimeGenerated, srcIp_s, destIp_s, destPort_s, action_s, ruleName_s
| order by TimeGenerated desc
```

**C. Denied SSH over time (5-min bins)**
```kql
AzureDiagnostics
| where Category == "NetworkSecurityGroupEvent"
| where destPort_s == "22" and action_s =~ "Deny"
| summarize denies = count() by bin(TimeGenerated, 5m)
| order by TimeGenerated asc
```

#### ✅ Expected Example:

| TimeGenerated       | srcIp\_s   | destIp\_s  | destPort\_s | action\_s | ruleName\_s     |
| ------------------- | ---------- | ---------- | ----------- | --------- | --------------- |
| 2025-06-19 12:02:10 | 10.100.1.4 | 10.100.2.5 | 22          | Deny      | deny-web-to-app |

---

🌟 You have now:

- Deployed infrastructure using Bicep/CLI
- Triggered and tested NSG blocking
- Enabled and explored Flow Logs
- Analyzed results using Traffic Analytics and KQL

📅 **Lab Complete**

