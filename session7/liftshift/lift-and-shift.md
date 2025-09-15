# Lab: Lift & Shift Migration (Linux VM) – Snapshot & Disk Method

This lab demonstrates a **simulated lift-and-shift migration** in Azure using snapshots and managed disks. Instead of creating a new VM from scratch, you will capture a source VM, create a disk from its snapshot, and deploy a new VM from that disk — representing the "migrated" workload.

## 🎯 Objectives
- Understand Lift & Shift (Rehost) as the fastest migration strategy with minimal changes.  
- Learn how to simulate migration by **cloning a VM** using snapshot and disk operations.  
- Validate the migrated VM by connecting via SSH.  
- Map this lightweight approach to the full Azure Migrate workflow.  

## 🛠️ Steps

### 1. Login and Initialize Environment
Run from the `session7` folder:

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

### 3. Stop the Source VM

    az vm deallocate -g rg-migrate-demo -n source-vm

---

### 4. Snapshot the OS Disk

    SOURCE_DISK=$(az vm show -g rg-migrate-demo -n source-vm \
        --query "storageProfile.osDisk.managedDisk.id" -o tsv)

    az snapshot create \
      -g rg-migrate-demo \
      -n source-snap \
      --source "$SOURCE_DISK"

---

### 5. Create a Managed Disk from Snapshot

    az disk create \
      -g rg-migrate-demo \
      -n migrated-disk \
      --source source-snap

---

### 6. Create Target "Migrated VM"

    az vm create \
      --resource-group rg-migrate-demo \
      --name migrated-vm \
      --attach-os-disk migrated-disk \
      --os-type Linux \
      --size Standard_B1s \
      --admin-username azureuser \
      --generate-ssh-keys \
      --vnet-name vnet-migrate \
      --subnet subnet-migrate \
      --nsg nsg-migrate

---

### 7. Validate the Migration

    ./env.sh status
    ssh azureuser@<migrated-vm-public-ip>

Exit with `exit` when done.

---

### 8. Cleanup (Optional)

    ./env.sh cleanup

---

## 📘 Notes
- This lab **simulates migration** by cloning a VM with snapshot + disk operations.  
- In production, **Azure Migrate** or **ASR** handle replication and cutover automatically.  
- Pros: lightweight, cost-friendly, works in personal subscriptions.  
- Cons: not a full enterprise migration workflow, but teaches the **rehost concept** effectively.  

✅ **End of Lab** — you have completed a Lift & Shift migration simulation using snapshot and disk cloning.
