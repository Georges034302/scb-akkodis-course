# Lab 2: On‑Prem to Azure Migration with Azure Site Recovery (ASR)

This lab demonstrates a **simulated on‑prem → Azure migration** using **Azure Site Recovery (ASR)** across Australian regions.  
You will prepare a **source environment in Australia East** and a **target (DR) environment in Australia Southeast**, enable replication for a source VM, run a **Test Failover**, and then perform a **Planned Failover (cutover)**.

> **What you’ll learn:** ASR concepts (vault, replicated items, test failover vs planned failover), cross‑region mapping, and safe validation practices.

---

## 🎯 Objectives
- Provision **source** resources (AE) and **target** resources (ASEA) for ASR.
- Create a **source VM** that represents the on‑prem workload.
- Enable **replication** to the target region via a **Recovery Services Vault**.
- Run **Test Failover** (no impact) and **Planned Failover** (cutover).
- Validate the migrated VM with SSH.
- Clean up resources safely.

---

## ✅ Pre‑reqs
- Azure CLI logged in (the script will check)  
- Region policy allows **Australia East** and **Australia Southeast**  
- Network egress for SSH (22) from your client IP

---

## 1) Login & Initialize Environment

Run from the Session 7 folder. This script prepares **both** sides for ASR:
- **Source (AE):** `rg-migrate-demo`, `vnet-migrate`, `subnet-migrate`, optional `nsg-migrate`  
- **Target (ASEA):** `rg-migrate-target` (Vault), `migrateVaultSEA` (RSV), `rg-migrate-demo-asr`, `vnet-migrate-asr`, `subnet-migrate`

```bash
chmod +x lab2-env.sh

# Login only if necessary
./lab2-env.sh login

# Create/Ensure both source & target infra
./lab2-env.sh init

# Verify
./lab2-env.sh status

# Optional: lock SSH to your /32 and re-run init
# SSH_SOURCE=auto ./lab2-env.sh init
```

A **handoff file** is written to `lab2/.lab.env` with useful IDs. Load it when needed:
```bash
source lab2/.lab.env
```

---

## 2) Create the Source VM (Simulated On‑Prem, in Australia East)

Use a suffix to avoid collisions in classrooms:

```bash
export SUFFIX=$RANDOM
read -s -p "Enter a secure password for the VM admin user: " ADMIN_PASSWORD && echo

az vm create \
  --resource-group rg-migrate-demo \
  --name source-vm-$SUFFIX \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --admin-password "$ADMIN_PASSWORD" \
  --authentication-type password \
  --vnet-name vnet-migrate \
  --subnet subnet-migrate \
  --nsg nsg-migrate

# Quick probe: expect 'Succeeded'
az vm show -g rg-migrate-demo -n source-vm-$SUFFIX --query "provisioningState" -o tsv
```

---

## 3) Create the Target Resource Group & Recovery Services Vault (Australia Southeast)

Your `lab2-env.sh init` already created these, but if you want to double‑check or (re)create manually:

```bash
az group create --name rg-migrate-target --location australiasoutheast

az backup vault create \
  --name migrateVaultSEA \
  --resource-group rg-migrate-target \
  --location australiasoutheast
```

> The **vault** hosts ASR metadata and policies; **replicated items** will ultimately live in `rg-migrate-demo-asr` against the target VNet `vnet-migrate-asr` (both created by the environment script).

---

## 4) Enable Replication (Portal)

Use the Azure Portal for the ASR wizard (easiest for learners):

1. Go to **Resource groups → rg-migrate-target → migrateVaultSEA**.  
2. In the vault, select **Site Recovery**.  
3. Under **Azure virtual machines**, choose **Enable replication**.

**Wizard inputs:**

**(1) Source**
- **Source region:** Australia East
- **Source resource group:** `rg-migrate-demo`
- **VM to replicate:** `source-vm-$SUFFIX`
- Deployment model: Resource Manager → **Next**

**(2) Virtual machines**
- Select `source-vm-$SUFFIX` → **Next**

**(3) Replication settings**
- **Target location:** Australia Southeast
- **Target resource group:** `rg-migrate-demo-asr` (create if not present)
- **Failover virtual network:** `vnet-migrate-asr` (region = Australia Southeast, address space `10.20.0.0/16`)
- **Failover subnet:** `subnet-migrate` (`10.20.1.0/24`)
- Storage/Availability options: defaults are fine → **Next**

**(4) Manage**
- **Replication policy:** e.g., `24-hour-retention-policy` (create if not present)
- **Extension settings:** Allow ASR to manage (recommended)
- **Automation account:** create new if prompted (e.g., `migrateVaultSEA-aa`) → **Next**

**(5) Review**
- Confirm AE → ASEA mapping and settings → **Enable replication**

Monitor progress in **Site Recovery → Replicated items → source-vm-$SUFFIX**. Wait until the item shows **Protected** (Initial sync complete).

---

## 5) Test Failover (No‑Impact Validation)

Create an isolated, temporary VM copy in **ASEA** to verify that failover works.

1. In the vault (**migrateVaultSEA**), open **Site Recovery → Replicated items → source-vm-$SUFFIX**.  
2. Click **Test Failover**.  
3. Configure:
   - **Failover direction:** Australia East → Australia Southeast
   - **Target resource group:** `rg-migrate-demo-asr`
   - **Target network:** `vnet-migrate-asr`
   - **Target subnet:** `subnet-migrate`
4. Confirm to start the test failover.

When complete: a **test VM** appears in `rg-migrate-demo-asr`. If the test VM lacks a public IP/NSG:
```bash
# Find NIC name
NIC_ID=$(az vm show --resource-group rg-migrate-demo-asr \
  --name source-vm-$SUFFIX --query "networkProfile.networkInterfaces[0].id" -o tsv)
NIC_NAME=$(basename "$NIC_ID")

# Public IP
az network public-ip create \
  --resource-group rg-migrate-demo-asr \
  --name source-vm-$SUFFIX-pip

# Attach PIP (replace ipconfig name if different)
az network nic ip-config update \
  --resource-group rg-migrate-demo-asr \
  --nic-name "$NIC_NAME" \
  --name ipconfigsource-vm-$SUFFIX \
  --public-ip-address source-vm-$SUFFIX-pip

# Optional: create/attach NSG to allow SSH if needed
az network nsg create \
  --resource-group rg-migrate-demo-asr \
  --name asr-ssh-nsg \
  --location australiasoutheast

az network nsg rule create \
  --resource-group rg-migrate-demo-asr \
  --nsg-name asr-ssh-nsg \
  --name allow-ssh \
  --priority 1000 \
  --access Allow --protocol Tcp --direction Inbound \
  --source-address-prefixes 0.0.0.0/0 \
  --destination-port-ranges 22

az network vnet subnet update \
  --resource-group rg-migrate-demo-asr \
  --vnet-name vnet-migrate-asr \
  --name subnet-migrate \
  --network-security-group asr-ssh-nsg
```

Connect to the test VM to validate boot and login:
```bash
TEST_IP=$(az network.public-ip show \
  --resource-group rg-migrate-demo-asr \
  --name source-vm-$SUFFIX-pip \
  --query "ipAddress" -o tsv)

ssh azureuser@"$TEST_IP" hostname
# Quick check expected: source-vm-$SUFFIX (or similar)
```

> When done, use **Cleanup test failover** in the portal to remove temporary artifacts for the test.

---

## 6) Planned Failover (Cutover)

This is the **real cutover**. It shuts down the source and promotes the replica in ASEA.

1. **Deallocate the source VM** in AE to stop writes (simulated cutover trigger):
   ```bash
   az vm deallocate -g rg-migrate-demo -n source-vm-$SUFFIX
   ```
2. In the vault (**migrateVaultSEA**) → **Site Recovery → Replicated items → source-vm-$SUFFIX**.  
3. Click **Planned Failover** and confirm:
   - **Direction:** Australia East → Australia Southeast  
   - **Target RG:** `rg-migrate-demo-asr`  
   - **Target VNet/Subnet:** `vnet-migrate-asr` / `subnet-migrate`  
4. Start the failover and monitor until complete.

ASR will finalize sync, stop the source VM, and bring up the **replicated VM** in `rg-migrate-demo-asr` (ASEA).

---

## 7) Validate the Migrated VM (ASEA)

Get the public IP of the failover VM (attach one if not present as in Step 5).

```bash
REPL_IP=$(az vm list -d \
  --resource-group rg-migrate-demo-asr \
  --query "[0].publicIps" -o tsv)

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

## 8) Cleanup

Two parts:

**A) Target resources (ASEA) — lab‑scoped**  
```bash
# Removes target ASR RG (replicated items etc.)
az group delete -n rg-migrate-demo-asr --yes --no-wait

# Removes the vault RG (Recovery Services Vault)
az group delete -n rg-migrate-target --yes --no-wait
```

**B) Source resources (AE) — optional**  
If you want to also remove the source landing zone created for this lab:
```bash
DELETE_SOURCE_ON_CLEANUP=true ./lab2-env.sh cleanup
# (or) az group delete -n rg-migrate-demo --yes --no-wait
```

> **Tip:** If you plan to re‑run the lab soon, you can keep the source RG to save time.

---

## 📘 Notes
- **Test Failover** is safe and **does not impact** the source workload.  
- **Planned Failover** is the **cutover** — it stops the source and promotes the target.  
- Cross‑region used here: **Australia East → Australia Southeast**.  
- Network security and public IP on the target are **not guaranteed by ASR**; attach an NSG/PIP as needed for SSH validation.  
- The provided `lab2-env.sh` mirrors your Lab 1 style and ensures idempotent provisioning across both regions.

✅ **End of Lab** — you’ve completed an on‑prem to Azure migration using Azure Site Recovery (ASR).
