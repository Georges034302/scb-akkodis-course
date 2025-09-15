# Lab: On-Prem to Azure Migration (ASR)

This lab demonstrates a simulated **on-premises to Azure migration** using **Azure Site Recovery (ASR)**.  
A VM acts as the "on-prem source" (in Australia East) and is replicated into Azure using a Recovery Services Vault (in Southeast Asia).  
You will configure replication, run a test failover, then perform a planned failover (cutover) to complete the migration.

---

## 🎯 Objectives
- Learn how ASR replicates workloads into Azure.  
- Configure a **cross-region Recovery Services Vault** (Australia East → Southeast Asia).  
- Perform **Test Failover** to validate migration safely.  
- Perform **Planned Failover (cutover)** to complete the migration.  
- Validate the migrated VM via SSH.  

---

## 🛠️ Steps

### 1. Login and Initialize Environment
Run from the course folder:
```bash
cd /workspaces/scb-akkodis-course/session7

chmod +x env.sh

./env.sh login

./env.sh init

./env.sh status
```
This creates the **source environment** in `australiaeast` with:
- Resource group: `rg-migrate-demo`  
- VNet: `vnet-migrate`  
- Subnet: `subnet-migrate`  
- NSG: `nsg-migrate`  

---

### 2. Create a Source VM (Simulating On-Prem)
This VM represents the on-premises workload that we will replicate.
```bash
read -s -p "Enter a secure password for the VM admin user: " ADMIN_PASSWORD && echo

az vm create \
  --resource-group rg-migrate-demo \
  --name source-vm \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --admin-password "$ADMIN_PASSWORD" \
  --authentication-type password \
  --vnet-name vnet-migrate \
  --subnet subnet-migrate \
  --nsg nsg-migrate
```

---

### 3. Create a Target Resource Group and Recovery Services Vault (in Southeast Asia)
ASR requires the vault to be in a **different region** for cross-region DR.

1. Create the target RG in Southeast Asia:
    ```bash
    az group create \
      --name rg-migrate-target \
      --location southeastasia
    ```

2. Create the Recovery Services Vault in Southeast Asia:
    ```bash
    az backup vault create \
      --name migrateVaultSEA \
      --resource-group rg-migrate-target \
      --location southeastasia
    ```

---

### 4. Enable Replication (Portal Steps)

In the Azure portal:

1. Go to **Resource groups** → **rg-migrate-target** → **migrateVaultSEA**.
2. In the vault menu, select **Site Recovery**.
3. Under **Azure virtual machines**, click **Enable replication**.

**Wizard pages:**

**(1) Source**
- **Source region:** Australia East
- **Source resource group:** rg-migrate-demo
- **Deployment model:** Resource Manager
- **VM to replicate:** source-vm  
Click **Next**.

**(2) Virtual machines**
- Select **source-vm**.  
Click **Next**.

**(3) Replication settings**
- **Target location:** Australia Southeast
- **Target subscription:** Azure subscription 1
- **Target resource group:** (new) rg-migrate-demo-asr (create new)
- **Failover virtual network:** (new) vnet-migrate-asr (region = Australia Southeast, address space e.g. 10.20.0.0/16)
- **Failover subnet:** (new) subnet-migrate (10.20.1.0/24)
- **Storage:** leave default (configured per VM)
- **Availability options:** None
- **Capacity reservation:** leave unassigned (0 of 1 machines)  
Click **Next**.

**(4) Manage**
- **Replication policy:** choose 24-hour-retention-policy (or Create new if unavailable)
- **Replication group:** leave blank unless you need multi-VM consistency (not required here)
- **Extension settings:** select Allow ASR to manage (recommended)
- **Automation account:** create new, e.g. migrateVa-mxq-asr-automationaccount  
Click **Next**.

**(5) Review**
- Confirm **Source:** Australia East (rg-migrate-demo/source-vm) → **Target:** Australia Southeast (rg-migrate-demo-asr/vnet-migrate-asr)
- **Replication policy:** 24-hour-retention-policy
- **Automation account:** migrateVa-mxq-asr-automationaccount  
Click **Enable replication**.

Replication begins. Monitor progress under **Site Recovery → Replicated items → source-vm**.

---

### 5. Run Test Failover (Portal Steps)

This step creates a safe copy of the source VM in the target region (**Australia Southeast**) so you can validate migration without impacting production.

1. In the Azure portal, go to **Resource groups → rg-migrate-target → migrateVaultSEA**.
2. In the vault menu, navigate to **Site Recovery → Replicated items**.
3. Select **source-vm**.
4. From the top menu, click **Test Failover**.
5. Configure:
    - **Failover direction:** Australia East → Australia Southeast
    - **Target resource group:** rg-migrate-demo-asr
    - **Target network:** vnet-migrate-asr
    - **Target subnet:** subnet-migrate
6. Confirm with **OK** to start the test failover.

When complete:
- A **test VM** will be created in Australia Southeast.
- Under **Replicated items**, select the test failover VM to view its details and copy the public IP address.

**If the test VM does not have a public IP:**

a. Get the NIC name dynamically:
   ```bash
   NIC_ID=$(az vm show \
     --resource-group rg-migrate-demo-asr \
     --name source-vm \
     --query "networkProfile.networkInterfaces[0].id" \
     -o tsv)
   NIC_NAME=$(basename "$NIC_ID")
   ```

b. Create a public IP:
   ```bash
   az network public-ip create \
     --resource-group rg-migrate-demo-asr \
     --name source-vm-pip
   ```

c. Associate the public IP with the NIC (confirm the NIC and ipconfig names first):
   ```bash
   az network nic show \
     --resource-group rg-migrate-demo-asr \
     --name "$NIC_NAME" \
     --query "ipConfigurations[].name" \
     -o table
   # Use the actual name from the output, e.g., ipconfigsource-vm
   az network nic ip-config update \
     --resource-group rg-migrate-demo-asr \
     --nic-name "$NIC_NAME" \
     --name ipconfigsource-vm \
     --public-ip-address source-vm-pip
   ```

d. Get the actual public IP address:
   ```bash
   TEST_IP=$(az network.public-ip show \
     --resource-group rg-migrate-demo-asr \
     --name source-vm-pip \
     --query "ipAddress" \
     -o tsv)
   ```

e. Allow SSH in VM NSG:
   ```bash
   # Create a new NSG
   az network nsg create \
    --resource-group rg-migrate-demo-asr \
    --name asr-ssh-nsg \
    --location southeastasia

   # Allow SSH in the new NSG
  az network nsg rule create \
    --resource-group rg-migrate-demo-asr \
    --nsg-name asr-ssh-nsg \
    --name allow-ssh \
    --priority 1000 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --source-address-prefixes 0.0.0.0/0 \
    --destination-port-ranges 22

   # Attach the NSG to the subnet
  az network vnet subnet update \
    --resource-group rg-migrate-demo-asr \
    --vnet-name vnet-migrate-asr \
    --name subnet-migrate \
    --network-security-group asr-ssh-nsg
   ```

f. Connect to the test VM using SSH:
   ```bash
   ssh azureuser@"$TEST_IP"
   ```

---

### 6. Run Planned Failover (Cutover)

This step completes the migration by shutting down the source VM in **Australia East** and promoting the replica in **Australia Southeast** as the new primary workload.

1. **Stop the source VM** (so no new writes occur):
    ```bash
    az vm deallocate \
      --resource-group rg-migrate-demo \
      --name source-vm
    ```

2. In the Azure portal, navigate to **Resource groups → rg-migrate-target → migrateVaultSEA → Site Recovery → Replicated items**.

3. Select **source-vm**.

4. From the top menu, click **Planned Failover**.

5. In the dialog, confirm:
    - **Failover direction:** Australia East → Australia Southeast
    - **Target resource group:** rg-migrate-demo-asr
    - **Target virtual network:** vnet-migrate-asr
    - **Target subnet:** subnet-migrate

6. Start the failover.

ASR will:
- Perform a final sync of changes from **source-vm**.
- Shut down **source-vm** in Australia East.
- Bring up the replicated VM in Australia Southeast inside **rg-migrate-demo-asr** and **vnet-migrate-asr**.

When finished, you can validate that the new VM is running and accessible via SSH using the same credentials.

---

### 7. Validate the Migrated VM

Get the public IP of the replicated VM created by the Planned Failover:

```bash
REPL_IP=$(az vm list -d \
  --resource-group rg-migrate-demo-asr \
  --query "[0].publicIps" \
  -o tsv)

ssh azureuser@"$REPL_IP"
```

Log in using the same password you set in Step 2 (source-vm creation).

Run a quick check to confirm the VM is functional:

```bash
hostname
lsb_release -a
```

---

### 8. Cleanup (Optional)
Remove all resources created in this lab:

```bash
# Run environment cleanup script (if available)
./env.sh cleanup

# Delete the target resource group
az group delete \
  --name rg-migrate-target \
  --yes \
  --no-wait

# Deallocate and delete the replicated VM (if still present)
az vm deallocate \
  --resource-group rg-migrate-demo-asr \
  --name source-vm

az vm delete \
  --resource-group rg-migrate-demo-asr \
  --name source-vm \
  --yes

# Delete the network interface (must be detached from VM first)
az network nic delete \
  --resource-group rg-migrate-demo-asr \
  --name source-vmVMNic

# Delete the public IP
az network public-ip delete \
  --resource-group rg-migrate-demo-asr \
  --name source-vm-pip

# Delete the NSG (if you created one for SSH)
az network nsg delete \
  --resource-group rg-migrate-demo-asr \
  --name asr-ssh-nsg

# Delete the subnet or VNet if needed
# az network vnet subnet delete \
#   --resource-group rg-migrate-demo-asr \
#   --vnet-name vnet-migrate-asr \
#   --name subnet-migrate

# az network vnet delete \
#   --resource-group rg-migrate-demo-asr \
#   --name vnet-migrate-asr

# Delete any disk replicas if present
# az disk delete \
#   --resource-group rg-migrate-demo-asr \
#   --name <disk-name> \
#   --yes

# Delete any snapshots or images referencing the disk
# az snapshot delete -g <resource-group> -n <snapshotName>
# az image delete -g <resource-group> -n <imageName>
```

---

## 📘 Notes
- **ASR requires cross-region DR** for non-zonal VMs. That’s why the vault and target RG are in `southeastasia`.  
- **Test Failover** = validation without impacting the source VM.  
- **Planned Failover** = final migration cutover.  
- This lab simulates **on-prem → Azure** with a cross-region rehost scenario.  

✅ **End of Lab** — you have completed an On-Prem to Azure migration using ASR (Australia East → Southeast Asia).
