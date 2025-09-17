# 🧪 NSG Flow Visibility Lab – 🔒 Monitor and Block Intra-VNet Traffic  

---

## 🛠️ Prerequisites
- Azure Subscription with **Contributor** or **Owner** access  
- **Azure CLI** installed and authenticated (`az login`)  
- Clone/download the lab folder containing:  
  - `deploy_bicep.sh`  
  - `nsg_flow.sh`  
  - `nsg_flow.bicep`  
  - `get_flow_logs.sh`  

---

## 🗭 Step-by-Step Lab Instructions  

---

### 🚀 Step 1: Deploy Infrastructure  

**Goal:** Provision a VNet with two subnets, two VMs, and an NSG that blocks intra-VNet SSH traffic.  

You have **two deployment script options**:  

#### 🛡️ Option A — Bicep Deployment  

```bash
cd session3
bash deploy_bicep.sh
```

This script will:  
- Create the resource group (`rg-flow-lab`)  
- Enable Network Watcher  
- Prompt for the VM admin password securely  
- Deploy all resources using `nsg_flow.bicep`  

---

#### 💻 Option B — CLI Deployment  

```bash
cd session3
bash nsg_flow.sh
```

This script will:  
- Create the resource group and enable Network Watcher  
- Deploy the VNet, subnets, NSG + rules, and two VMs  
- Create a storage account + Log Analytics workspace  
- Enable NSG Flow Logs and Traffic Analytics  
- Output the public IP of `vm-web` for SSH access  

---

### 📦 Step 2: Enable Flow Logs (If Needed)  

- If you used **`nsg_flow.sh`**, Flow Logs are already enabled.  
- If you used **`deploy_bicep.sh`**, you must enable them manually in the Portal:  

1. Open **Network Watcher** → **Logs > Flow Logs**  
2. Create a new Flow Log for NSG `nsg-app`  
3. Storage Account: select/create one  
4. Log Analytics workspace: `flowlog-law`  
5. Flow Logs version: `2`  
6. Traffic Analytics: **Enabled**, Interval = `10 minutes`  

---

### 🔍 Step 3: Post-Deployment Testing  

#### Define Environment Variables  

```bash
RG="rg-flow-lab"
VM_WEB="vm-web"
VM_APP="vm-app"
ADMIN_USER="azureuser"

# Get IPs dynamically
VM_WEB_PIP=$(az vm show -g $RG -n $VM_WEB --show-details --query publicIps -o tsv)
VM_APP_PRIV=$(az vm show -g $RG -n $VM_APP --show-details --query privateIps -o tsv)

echo "vm-web public IP : $VM_WEB_PIP"
echo "vm-app private IP: $VM_APP_PRIV"
```

---

#### ❌ Direct SSH to vm-app (Expected Fail)  

```bash
ssh $ADMIN_USER@$VM_APP_PRIV
```

- `vm-app` has **no public IP**  
- NSG (`nsg-app`) blocks inbound SSH (22)  
- Result: ❌ **Connection timeout/denied**  

---

#### ✅ SSH to vm-web (Expected Success)  

```bash
ssh $ADMIN_USER@$VM_WEB_PIP
```

- `vm-web` has a **public IP** and SSH allowed  
- Result: ✅ **Login succeeds**  

---

#### ❌ From vm-web → vm-app (Expected Fail)  

Inside `vm-web`:  

```bash
ssh $ADMIN_USER@$VM_APP_PRIV
```

- Simulates intra-VNet traffic from `web-subnet → app-subnet`  
- NSG explicitly blocks this  
- Result: ❌ **Connection denied**  

---

### 📂 Step 4: Inspect Flow Logs  

> ⏳ Logs take **15–20 minutes** to appear after generating SSH attempts.  

#### Option A — Portal  

- Open **Storage Account** → **Containers** → `insights-nsg-flow-logs`  
- Browse `year / month / day / hour` folders  
- Open a JSON blob and look for tuples like:  

```
"10.100.1.4,10.100.2.5,57232,22,T,I,D,U,..."
```
- `D = Denied`  
- `T = TCP`  
- `22 = SSH`  

---

#### Option B — CLI Script  

Run the helper script to fetch the **latest log blob** automatically:  

```bash
cd session3
bash get_flow_logs.sh
```

This will:  
- Get your storage account dynamically  
- Locate the latest blob in `insights-nsg-flow-logs`  
- Download it to `flowlog.json`  

Open **flowlog.json** and search for denied SSH entries.  

---

### 🥪 Step 5: Analyze with KQL in Log Analytics (Optional)  

In **Azure Portal** → **Log Analytics Workspaces** → `flowlog-law` → **Logs**, run:  

```kql
AzureDiagnostics
| where Category == "NetworkSecurityGroupEvent"
| project TimeGenerated, type_s, direction_s, srcIp_s, destIp_s, destPort_s, action_s, ruleName_s
| order by TimeGenerated desc
```

✅ Expected: SSH traffic (`port 22`) from `vm-web → vm-app` marked **Deny**.  

---

### 🧹 Step 6: Cleanup  

When finished, delete all lab resources:  

```bash
az group delete -n rg-flow-lab --yes --no-wait
```

---

## 🎉 Lab Wrap-Up  

You have successfully:  
- Deployed infrastructure with **Bicep or CLI script**  
- Verified NSG blocking of intra-VNet SSH  
- Inspected **NSG Flow Logs**  
- Validated denied traffic via **Traffic Analytics + KQL**  

📅 **Lab Complete**  
