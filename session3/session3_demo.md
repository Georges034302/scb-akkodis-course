## 🧪 Lab Title: NSG Flow Visibility Lab – 🔒 Monitor and Block Intra-VNet Traffic

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
  --parameters adminPassword='YourSecureP@ssword123'
```

---

#### 💻 Option B: Deploy Using Azure CLI

```bash
cd session3
bash nsg_flow.sh
```

---

### 📦 Step 3: Enable Flow Logs in Network Watcher (Manual)

- Open **Azure Portal** and search for **Network Watcher**
- In the left panel, select **Logs > Flow Logs**
- Click **➕ Create**
  - **Basics Tab:**
    - Flow log type: `Network security group`
    - Select NSG: `nsg-app` and confirm
    - Location: `australiaeast`
    - Create or select a **Storage Account** for logs
    - Set retention (e.g., 30 days)
  - **Analytics Tab:**
    - Flow logs version: `Version 2`
    - Enable **Traffic Analytics**
      - Set interval: `10 minutes`
      - Select Log Analytics workspace: `flowlog-law`
  - Review and Create

---

### 🔍 Step 4: Post-Deployment Testing

#### Get Private IP of vm-app

```bash
az vm show \
  --resource-group rg-flow-lab \
  --name vm-app \
  --show-details \
  --query privateIps -o tsv
```

#### SSH into vm-web (Expected to Fail)

```bash
ssh azureuser@<vm-app-private-ip>
```

⏳ You should see a timeout or connection denied — verifying NSG is blocking the traffic.

---

### 📂 Step 4: Inspect Flow Logs (Portal or CLI)

#### 🔢 Option A: Using Azure Portal

1. Go to **Storage accounts** > your account (e.g., `flsay...`) > **Containers**
2. Open `insights-logs-networksecuritygroupflowevent`
3. Navigate into the folder structure: `year/month/day/hour`
4. Open a JSON log blob and inspect entries like:
   ```
   "10.100.1.4,10.100.2.5,57232,22,T,I,D,U,..."
   ```
   - `D` = Denied, `T` = TCP, `22` = SSH

#### 🔢 Option B: Using CLI

```bash
az storage blob list \
  --account-name flsay3lw6cr4y4mwq \
  --container-name insights-logs-networksecuritygroupflowevent \
  --output table
```

(Optional) To download and inspect a specific log:

```bash
az storage blob download \
  --account-name flsay3lw6cr4y4mwq \
  --container-name insights-logs-networksecuritygroupflowevent \
  --name <blob-path> \
  --file ./flowlog.json
```

Then open `flowlog.json` locally to examine flow tuples.

---

### 🥪 Step 5: Analyze Flow Logs with KQL in Log Analytics (Optional)

**Goal:** Validate denied SSH traffic is visible in flow logs via KQL.

> Prerequisites:
>
> - Flow logs must be linked to `flowlog-law`
> - Traffic Analytics enabled

#### 1. Open Log Analytics:

- Go to **Log Analytics Workspaces** in Azure Portal
- Select `flowlog-law` > **Logs**

#### 2. Run KQL:

```kql
AzureDiagnostics
| where Category == "NetworkSecurityGroupEvent"
| project TimeGenerated, type_s, direction_s, primaryIPv4Address_s, ruleName_s
| order by TimeGenerated desc
```

#### ✅ Expected:

| TimeGenerated       | SrcIP\_s   | DstIP\_s   | Dport\_s | FlowType\_s | VM\_s  |
| ------------------- | ---------- | ---------- | -------- | ----------- | ------ |
| 2025-06-19 12:02:10 | 10.100.1.4 | 10.100.2.5 | 22       | Blocked     | vm-web |

---

🌟 You have now:

- Deployed infrastructure using Bicep/CLI
- Triggered and tested NSG blocking
- Enabled and explored Flow Logs
- Analyzed results using Traffic Analytics and KQL

📅 **Lab Complete**

