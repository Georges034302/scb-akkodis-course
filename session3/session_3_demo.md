## 🧪 Lab Title: NSG Flow Visibility Lab – 🔒 Monitor and Block Intra-VNet Traffic

---

### 🛠️ Prerequisites:

- Azure Subscription with Contributor or Owner access
- Azure CLI installed and authenticated

---

## 🧭 Step-by-Step Lab Instructions

---

### 🚀 Step 1: Deploy Infrastructure

**Goal:** Provision a secure VNet setup with NSG and diagnostic visibility via Flow Logs

---

#### 🧱 Option A: Create Resource group and deploy the Bicep file `nsg_flow.bicep`

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

### 🔍 Step 2: Post-Deployment Testing

#### 1️⃣ Get Private IP of vm-app

```bash
az vm show \
  --resource-group rg-flow-lab \
  --name vm-app \
  --show-details \
  --query privateIps -o tsv
```

#### 2️⃣ SSH into vm-web

```bash
az vm ssh --name vm-web --resource-group rg-flow-lab
```

#### 3️⃣ Attempt SSH to vm-app (Expected to Fail)

```bash
ssh azureuser@<vm-app-private-ip>
```

You should see a timeout or connection denied — verifying NSG is blocking the traffic.

---

### 📦 Step 3: Enable Flow Logs in Network Watcher (Manual or Scripted)

- Open Azure Portal > Network Watcher > NSG Flow Logs
- Select NSG `nsg-app`
- Enable logging
  - Destination: Create or select a Storage Account
  - Link to Log Analytics workspace: `flowlog-law`
- (Optional) Enable **Traffic Analytics** with 10-minute interval

---

### 📂 Step 4: Inspect Flow Logs (Optional)

Navigate to the Storage Account container or use Traffic Analytics to:
- Review JSON logs showing `deny` actions
- Confirm the flow from `vm-web (10.100.1.x)` to `vm-app (10.100.2.x:22)` was blocked

---

### 🧪 Step 5: Analyze Flow Logs with KQL in Log Analytics (Optional)

**Goal:** Validate denied SSH traffic is visible in flow logs via KQL.

> ⚠️ Prerequisites:
> - Flow logs must be enabled and connected to a Log Analytics Workspace (`flowlog-law`)
> - Traffic Analytics is enabled in your Bicep or CLI deployment

#### 1️⃣ Open Log Analytics:
- Go to **Log Analytics Workspaces** in Azure Portal
- Open the workspace `flowlog-law`
- Select **Logs** (KQL query window)

#### 2️⃣ Run the KQL Query:
```kql
AzureNetworkAnalytics_CL
| where FlowType_s == "Blocked" and L4Protocol_s == "TCP" and Dport_s == "22"
| where Direction_s == "I" and SubType_s == "FlowLog"
| project TimeGenerated, SrcIP_s, DstIP_s, Dport_s, L4Protocol_s, FlowType_s, VM_s
| order by TimeGenerated desc
```

#### ✅ Expected Output:
A table showing denied SSH traffic from vm-web to vm-app:

| TimeGenerated       | SrcIP_s       | DstIP_s       | Dport_s | FlowType_s | VM_s    |
|---------------------|---------------|---------------|---------|------------|---------|
| 2025-06-19 12:02:10 | 10.100.1.4    | 10.100.2.5    | 22      | Blocked    | vm-web  |

---

🎯 You have now:
- Deployed infrastructure using Bicep and CLI
- Tested denied traffic flow
- Verified NSG enforcement
- Enabled and reviewed Flow Logs
- Analyzed logs with KQL in Log Analytics

✅ **Lab Complete**

---




