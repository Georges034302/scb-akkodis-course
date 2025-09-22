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
```

```bash
./lab2-env.sh login
```

```bash
./lab2-env.sh init
```

```bash
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

The goal is to create an isolated, temporary VM copy in **Australia Southeast (ASEA)** to verify that failover works without impacting production.

### Steps:

1. In the vault **migrateVaultSEA-target**, go to:  
   **Site Recovery → Replicated items → source-vm-$SUFFIX**  

2. Click **Test Failover** and configure:  
   - **Failover direction:** Australia East → Australia Southeast  
   - **Target resource group:** rg-migrate-target  
   - **Target network:** vnet-migrate-target  
   - **Target subnet:** subnet-migrate-target  

3. Confirm and start the test failover.  
   - A **test VM** will appear in **rg-migrate-target** once complete.

---

#### If the test VM has no Public IP/NSG:

Run the following commands to attach a public IP and allow SSH:

```bash
# Find NIC name
NIC_ID=$(az vm show --resource-group rg-migrate-target \
  --name source-vm-$SUFFIX \
  --query "networkProfile.networkInterfaces[0].id" -o tsv)
NIC_NAME=$(basename "$NIC_ID")

# Create a Public IP
az network public-ip create \
  --resource-group rg-migrate-target \
  --name source-vm-$SUFFIX-pip

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
  --public-ip-address source-vm-$SUFFIX-pip

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

### Connect to the test VM to validate boot and login:

```bash
TEST_IP=$(az network.public-ip show \
  --resource-group rg-migrate-target \
  --name source-vm-$SUFFIX-pip \
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
az vm deallocate -g rg-migrate-source -n source-vm-$SUFFIX
```

2. In the vault (**migrateVaultSEA-target**) → **Site Recovery → Replicated items → source-vm-$SUFFIX**.  
3. Click **Planned Failover** and confirm:
   - **Direction:** Australia East → Australia Southeast  
   - **Target RG:** `rg-migrate-target`  
   - **Target VNet/Subnet:** `vnet-migrate-target` / `subnet-migrate-target`  
4. Start the failover and monitor until complete.

ASR will finalize sync, stop the source VM, and bring up the **replicated VM** in `rg-migrate-target` (ASEA).

---

## 6) Validate the Migrated VM (ASEA)

Get the public IP of the failover VM (attach one if not present as in Step 5).

```bash
REPL_IP=$(az vm list -d \
  --resource-group rg-migrate-target \
  --query "[0].publicIps" -o tsv)
echo "Migrated VM IP: $REPL_IP"

# Quick command mode (prints hostname then disconnects)
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

## 7) Cleanup

Two parts:

**A) Target resources (ASEA) — lab-scoped**

```bash
# Removes target ASR RG (replicated items etc.)
az group delete -n rg-migrate-target --yes --no-wait
```

```bash
# Removes the vault RG (Recovery Services Vault)
az group delete -n rg-migrate-target-vault --yes --no-wait
```

**B) Source resources (AE) — optional**  
If you want to also remove the source landing zone created for this lab:

```bash
DELETE_SOURCE_ON_CLEANUP=true ./lab2-env.sh cleanup
# (or) az group delete -n rg-migrate-source --yes --no-wait
```

> **Tip:** If you plan to re-run the lab soon, you can keep the source RG to save time.

---

## 📘 Notes
- **Test Failover** is safe and **does not impact** the source workload.  
- **Planned Failover** is the **cutover** — it stops the source and promotes the target.  
- Cross-region used here: **Australia East → Australia Southeast**.  
- Network security and public IP on the target are **not guaranteed by ASR**; attach an NSG/PIP as needed for SSH validation.  
- The provided `lab2-env.sh` mirrors your Lab 1 style and ensures idempotent provisioning across both regions.

✅ **End of Lab** — you’ve completed an on-prem to Azure migration using Azure Site Recovery (ASR).
