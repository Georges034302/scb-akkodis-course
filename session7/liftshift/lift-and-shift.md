# Lab 1: Lift & Shift Migration (Linux VM) – Snapshot & Disk Method

This lab demonstrates a **simulated lift-and-shift migration** in Azure using snapshots and managed disks. Instead of creating a new VM from scratch, you will capture a source VM, create a disk from its snapshot, and deploy a new VM from that disk — representing the "migrated" workload.

<img width="1536" height="1024" alt="LiftandShift" src="https://github.com/user-attachments/assets/0816afe1-ba42-4737-a5c9-0e6301e9a4ec" />

## 🎯 Objectives
- Understand Lift & Shift (Rehost) as the fastest migration strategy with minimal changes.  
- Learn how to simulate migration by **cloning a VM** using snapshot and disk operations.  
- Validate the migrated VM by connecting via SSH and checking the hostname.  
- Map this lightweight approach to the full Azure Migrate workflow.  

## 🛠️ Steps

### 1. Login and Initialize Environment
Run from the `session7` folder:

```bash
./env.sh login
./env.sh init
./env.sh status
```

---

### 2. Create a Source VM (Simulating On-Prem)

Use a unique suffix to avoid collisions in multi-student sessions:

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
```

---

### 3. Stop the Source VM

```bash
az vm deallocate \
  -g rg-migrate-demo \
  -n source-vm-$SUFFIX
```

---

### 4. Snapshot the OS Disk

```bash
SOURCE_DISK=$(az vm show \
  -g rg-migrate-demo \
  -n source-vm-$SUFFIX \
  --query "storageProfile.osDisk.managedDisk.id" \
  -o tsv)

az snapshot create \
  -g rg-migrate-demo \
  -n source-snap-$SUFFIX \
  --source "$SOURCE_DISK"

# Verify
az snapshot show -g rg-migrate-demo -n source-snap-$SUFFIX --query "provisioningState"
```

---

### 5. Create a Managed Disk from Snapshot

```bash
az disk create \
  -g rg-migrate-demo \
  -n migrated-disk-$SUFFIX \
  --source source-snap-$SUFFIX

# Verify
az disk show -g rg-migrate-demo -n migrated-disk-$SUFFIX --query "provisioningState"
```

---

### 6. Create Target "Migrated VM"

```bash
read -s -p "Enter a secure password for the migrated VM admin user: " ADMIN_PASSWORD && echo

az vm create \
  --resource-group rg-migrate-demo \
  --name migrated-vm-$SUFFIX \
  --attach-os-disk migrated-disk-$SUFFIX \
  --os-type Linux \
  --size Standard_B1s \
  --vnet-name vnet-migrate \
  --subnet subnet-migrate \
  --nsg nsg-migrate
```

---

### 7. Validate the Migration

```bash
./env.sh status

PUBLIC_IP=$(az vm show -d \
  --resource-group rg-migrate-demo \
  --name migrated-vm-$SUFFIX \
  --query publicIps \
  -o tsv)

ssh azureuser@"$PUBLIC_IP" hostname
# Expected: migrated-vm-$SUFFIX
```

Exit with `exit` when done.

---

### 8. Cleanup (Optional)

```bash
./env.sh cleanup
```

---

## 📘 Notes
- This lab **simulates migration** by cloning a VM with snapshot + disk operations.  
- In production, **Azure Migrate** or **ASR** handle replication and cutover automatically.  
- Pros: lightweight, cost-friendly, works in personal subscriptions.  
- Cons: not a full enterprise migration workflow, but teaches the **rehost concept** effectively.  

✅ **End of Lab** — you have completed a Lift & Shift migration simulation using snapshot and disk cloning.
