# Lab: On-Prem to Azure Migration (ASR)

This lab demonstrates a simulated **on-premises to Azure migration** using **Azure Site Recovery (ASR)**. A VM acts as the "on-prem source" and is replicated into Azure using a Recovery Services Vault.

## 🎯 Objectives
- Learn how ASR replicates workloads into Azure.  
- Configure a Recovery Services Vault for replication.  
- Perform **Test Failover** and **Planned Failover (cutover)**.  
- Validate the migrated VM via SSH.  

## 🛠️ Steps

### 1. Login and Initialize Environment

    ./env.sh login
    ./env.sh init
    ./env.sh status

---

### 2. Create a Source VM (Simulating On-Prem)

    az vm create \
      --resource-group rg-migrate-demo \
      --name source-vm \
      --image UbuntuLTS \
      --size Standard_B1s \
      --admin-username azureuser \
      --generate-ssh-keys \
      --vnet-name vnet-migrate \
      --subnet subnet-migrate \
      --nsg nsg-migrate

---

### 3. Create a Recovery Services Vault

    az backup vault create \
      --name migrateVault \
      --resource-group rg-migrate-demo \
      --location australiaeast

---

### 4. Enable Replication for the VM
(Portal is faster for personal subscriptions)

- Go to **Azure Portal → migrateVault → Site Recovery**.  
- Enable replication for **source-vm**.  
- Set target RG = `rg-migrate-demo`, VNet = `vnet-migrate`.  

---

### 5. Run Test Failover

- In the Vault, choose **Replicated items → source-vm → Test Failover**.  
- Select target RG/VNet.  
- Verify a new test VM boots successfully.  

---

### 6. Run Planned Failover (Cutover)

- Stop source-vm.  
- In the Vault, perform **Planned Failover**.  
- The replicated VM becomes the new primary workload.  

---

### 7. Validate

    ./env.sh status
    ssh azureuser@<replicated-vm-public-ip>

---

### 8. Cleanup (Optional)

    ./env.sh cleanup

---

## 📘 Notes
- ASR provides **continuous replication** and **failover automation**.  
- **Test Failover** = safe validation.  
- **Planned Failover** = cutover migration.  
- This lab simulates **on-prem → Azure** with minimal setup.  

✅ **End of Lab** — you have completed an On-Prem to Azure migration using ASR.
