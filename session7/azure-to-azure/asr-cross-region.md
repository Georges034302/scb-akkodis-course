# Lab 2: On-Prem to Azure Migration with Azure Site Recovery (ASR)

This lab demonstrates a **simulated on-prem → Azure migration** using **Azure Site Recovery (ASR)** across Australian regions.  
You will prepare a **source environment in Australia East** and a **target (DR) environment in Australia Southeast**, enable replication for a source VM, run a **Test Failover**, and then perform a **Planned Failover (cutover)**.

<img width="1536" height="1024" alt="asr-cross-region" src="https://github.com/user-attachments/assets/76693d77-9cc4-4847-a96e-7265e6aa0f0b" />

> **What you’ll learn:** ASR concepts (vault, replicated items, test failover vs planned failover), cross-region mapping, and safe validation practices.

---

## 🎯 Objectives
- Provision **source** resources (AE) and **target** resources (ASEA) for ASR.
- Create a **source VM** that represents the on-prem workload.
- Enable **replication** to the target region via a **Recovery Services Vault**.
- Run **Test Failover** (no impact) and **Planned Failover** (cutover).
- Validate the migrated VM with SSH.
- Clean up resources safely.

---

## ✅ Pre-reqs
- Azure CLI logged in (the script will check)  
- Region policy allows **Australia East** and **Australia Southeast**  
- Network egress for SSH (22) from your client IP

---

## 1) Login & Initialize Environment

Run from the Session 7 folder. This script prepares **both** sides for ASR:
- **Source (AE):** `rg-migrate-source`, `vnet-migrate-source`, `subnet-migrate-source`, optional `nsg-migrate-source`  
- **Target (ASEA):** `rg-migrate-target-vault` (Vault), `migrateVaultSEA-target` (RSV), `rg-migrate-target`, `vnet-migrate-target`, `subnet-migrate-target`

```bash
chmod +x lab2-env.sh

./lab2-env.sh login

./lab2-env.sh init

./lab2-env.sh status
```

```bash
# Optional: lock SSH to your /32 and re-run init
# SSH_SOURCE=auto ./lab2-env.sh init
```

A **handoff file** is written to `lab2/.lab.env` with useful IDs. Load it when needed:
```bash
source lab2/.lab.env
```

---

## 2) Create the Source VM (Simulated On-Prem, in Australia East)

Use a suffix to avoid collisions in classrooms:

```bash
export SUFFIX=$RANDOM
read -s -p "Enter a secure password for the VM admin user: " ADMIN_PASSWORD && echo

az vm create \
  --resource-group rg-migrate-source \
  --name source-vm-$SUFFIX \
  --location australiaeast \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --admin-password "$ADMIN_PASSWORD" \
  --authentication-type password \
  --vnet-name vnet-migrate-source \
  --subnet subnet-migrate-source
```

```bash
# Quick probe: expect 'Succeeded'
az vm show -g rg-migrate-source -n source-vm-$SUFFIX --query "provisioningState" -o tsv
```

---

## 3) Enable Replication (Portal)

Use the Azure Portal for the ASR wizard (easiest for learners):

1. Go to **Resource groups → rg-migrate-target-vault → migrateVaultSEA-target**.  
2. In the vault, select **Site Recovery**.  
3. Under **Azure virtual machines**, choose **Enable replication**.

**Wizard inputs:**

**(1) Source**
- **Source region:** Australia East
- **Source resource group:** `rg-migrate-source`
- **VM to replicate:** `source-vm-$SUFFIX`
- Deployment model: Resource Manager 
- Disaster recovery between availability zones → **No**
- Click → **Next**

**(2) Virtual machines**
- Select `source-vm-$SUFFIX` → **Next**

**(3) Replication settings**
- **Target location:** Australia Southeast
- **Target resource group:** `rg-migrate-target` (create if not present)
- **Failover virtual network:** `vnet-migrate-target` (region = Australia Southeast, address space `10.20.0.0/16`)
- **Failover subnet:** `subnet-migrate-target` (`10.20.1.0/24`)
- Storage/Availability options: defaults are fine → **Next**

**(4) Manage**
- **Replication policy:** e.g., `24-hour-retention-policy` (create if not present)
- **Extension settings:** Allow ASR to manage (recommended)
- **Automation account:** create new if prompted (e.g., `migrateVaultSEA-target-aa`) → **Next**

**(5) Review**
- Confirm AE → ASEA mapping and settings → **Enable replication**

Monitor progress in **Site Recovery → Replicated items → source-vm-$SUFFIX**. Wait until the item shows **Protected** (Initial sync complete).

---

## 4) Test Failover (No-Impact Validation)

> ⚠️ **Note:**  
> • First, wait for **initial replication** to complete — during this stage ASR view shows replication in progress.  
> • Next, wait for **synchronization** to finish — the VM status must change to **Protected**.  
> • This process typically takes **20–30 minutes** (longer for larger disks/VMs).  
> • Once done, you should see: **Status = Protected**, **Replication Health = Healthy**, and a valid **RPO timestamp** in the Recovery Services Vault.



### 🔍 How to check replication status
You can check in **Azure Portal** → **Recovery Services Vault → Site Recovery → Replicated Items → source-vm-$SUFFIX**.  

Or use the CLI (make sure the ASR extension is installed):

```bash
# Install ASR extension once
az extension add --name site-recovery -y

# List recent ASR jobs
az site-recovery job list \
  --resource-group rg-migrate-target-vault \
  --vault-name migrateVaultSEA-target \
  --query "[].{Name:name, State:properties.state, Start:properties.startTime, End:properties.endTime}" \
  -o table
``` 

### After ASR replication is completed - Test Failover:

1. In the vault **rg-migrate-target-vault/migrateVaultSEA-target**, go to:  
   **Site Recovery → Replicated items → source-vm-$SUFFIX**

2. Click **Test Failover** and configure the following:

   - **Test failover direction**
     - **Source:** Australia East
     - **Destination:** Australia Southeast

   - **Test failover settings**
     - **Recovery point:** (Choose the latest or your preferred recovery point)
     - **Azure virtual network:** vnet-migrate-target
   - **Target resource group:** rg-migrate-target  
   - **Target subnet:** subnet-migrate-target

3. Confirm and start the test failover. 
   - Wait for the Test Failover to Complete.
   - A **test VM** will appear in **rg-migrate-target** once complete.

---

#### Access and Validate the Test VM (SSH & Connectivity):

Run the following commands to attach a public IP and allow SSH:

```bash
# Find NIC name
NIC_ID=$(az vm show --resource-group rg-migrate-target \
  --name source-vm-$SUFFIX-test \
  --query "networkProfile.networkInterfaces[0].id" -o tsv)
NIC_NAME=$(basename "$NIC_ID")

# Create a Public IP
az network public-ip create \
  --resource-group rg-migrate-target \
  --name source-vm-$SUFFIX-test-pip

# Get the NIC ipconfig name (usually 'ipconfig1')
IPCONFIG_NAME=$(az network nic show \
  --resource-group rg-migrate-target \
  --name "$NIC_NAME" \
  --query "ipConfigurations[0].name" -o tsv)

# Attach Public IP to NIC
az network nic ip-config update \
  --resource-group rg-migrate-target \
  --nic-name "$NIC_NAME" \
  --name "$IPCONFIG_NAME" \
  --public-ip-address source-vm-$SUFFIX-test-pip

# (Optional) Create an NSG for SSH
az network nsg create \
  --resource-group rg-migrate-target \
  --name asr-ssh-nsg \
  --location australiasoutheast

# Add SSH allow rule
az network nsg rule create \
  --resource-group rg-migrate-target \
  --nsg-name asr-ssh-nsg \
  --name allow-ssh \
  --priority 1000 \
  --access Allow --protocol Tcp --direction Inbound \
  --source-address-prefixes 0.0.0.0/0 \
  --destination-port-ranges 22

# Associate NSG with the target subnet
az network vnet subnet update \
  --resource-group rg-migrate-target \
  --vnet-name vnet-migrate-target \
  --name subnet-migrate-target \
  --network-security-group asr-ssh-nsg
```

#### Connect to the test VM to validate boot and login:

```bash
TEST_IP=$(az network public-ip show \
  --resource-group rg-migrate-target \
  --name source-vm-$SUFFIX-test-pip \
  --query "ipAddress" -o tsv)
echo "Test VM IP: $TEST_IP"

ssh azureuser@"$TEST_IP" hostname
# Quick check expected: source-vm-$SUFFIX (or similar)
```

> When done, use **Cleanup test failover** in the portal to remove temporary artifacts for the test.

---

## 5) Planned Failover (Cutover)

This is the **real cutover**. It shuts down the source and promotes the replica in ASEA.

```bash
# Manual VM shutdown before planned failover (ensures data consistency)
az vm deallocate -g rg-migrate-source -n source-vm-$SUFFIX
```

2. In the vault (**migrateVaultSEA-target**) 
3. Go to → **Site Recovery → Replicated items → source-vm-$SUFFIX**.  
4. Click **Failover** for `Planned Failover` and confirm:
   - **Direction:** Australia East → Australia Southeast  
   - **Target RG:** `rg-migrate-target`  
   - Shutdown machine before beginning the failover **Yes**
5. Start the failover and monitor until complete. 
6. Check status changes from `Failover was initiated` to `Completing falover` to `Failover completed`

ASR will finalize sync, stop the source VM, and bring up the **replicated VM** in `rg-migrate-target` (ASEA).

---

## 6) Validate the Migrated VM (ASEA)

Get the public IP of the failover VM (attach one if not present as in Step 5).

```bash
# Get the NIC resource ID of the migrated VM
REPL_NIC_ID=$(az vm show \
  --resource-group rg-migrate-target \
  --name source-vm-$SUFFIX \
  --query "networkProfile.networkInterfaces[0].id" -o tsv)

# Extract the NIC name from the resource ID
REPL_NIC_NAME=$(basename "$REPL_NIC_ID")

# Create a new Public IP for the migrated VM (if not already present)
az network public-ip create \
  --resource-group rg-migrate-target \
  --name source-vm-$SUFFIX-pip

# Get the name of the NIC's IP configuration (usually 'ipconfig1')
IPCONFIG_NAME=$(az network nic show \
  --resource-group rg-migrate-target \
  --name "$REPL_NIC_NAME" \
  --query "ipConfigurations[0].name" -o tsv)

# Attach the new Public IP to the NIC
az network nic ip-config update \
  --resource-group rg-migrate-target \
  --nic-name "$REPL_NIC_NAME" \
  --name "$IPCONFIG_NAME" \
  --public-ip-address source-vm-$SUFFIX-pip

# Retrieve the public IP address of the migrated VM
REPL_IP=$(az network public-ip show \
  --resource-group rg-migrate-target \
  --name source-vm-$SUFFIX-pip \
  --query "ipAddress" -o tsv)
echo "Migrated VM IP: $REPL_IP"

# SSH into the migrated VM and print its hostname
ssh azureuser@"$REPL_IP" hostname

# Or open an interactive shell:
# ssh azureuser@"$REPL_IP"
```

Optional deeper checks:

```bash
# Inside the VM:
hostname
lsb_release -a || cat /etc/os-release
```

---

## 7) Commit Failover & Decommission Source

✅ Post-Failover Next Steps in Azure ASR

1. **Commit the Failover**  
   - In the vault **migrateVaultSEA-target**, go to:  
     **Site Recovery → Replicated items → source-vm-$SUFFIX**  
   - Click **Commit Failover**.  
   - This finalizes the cutover, discards recovery points, and confirms the VM is running in **Australia Southeast**.
   - Check status changes from `Commit in progress` to `Failover committed`

2. **Decommission Source VM** (if migration is final)  
   - Shut down and delete the **source VM** in `rg-migrate-source`.  
   - This avoids double billing for compute/storage.

3. **Verify Target VM**  
   - Confirm the replica in `rg-migrate-target` is healthy.  
   - Ensure NIC + Public IP are attached, and test SSH connectivity.  
   - Update DNS or hostnames as needed.

---

## 8) Cleanup

```bash
./lab2-env.sh cleanup
```

---

## 📘 Notes
- **Test Failover** is safe and **does not impact** the source workload.  
- **Planned Failover** is the **cutover** — it stops the source and promotes the target.  
- Cross-region used here: **Australia East → Australia Southeast**.  
- Network security and public IP on the target are **not guaranteed by ASR**; attach an NSG/PIP as needed for SSH validation.  
- The provided `lab2-env.sh` mirrors your Lab 1 style and ensures idempotent provisioning across both regions.

✅ **End of Lab** — you’ve completed an on-prem to Azure migration using Azure Site Recovery (ASR).
