# Lab: AWS to Azure Migration (Simulated VHD Import)

This lab simulates **cross-cloud migration** from AWS to Azure by exporting a VM image (VHD) and importing it into Azure.

## 🎯 Objectives
- Understand challenges of AWS-to-Azure migration.  
- Simulate by importing a VHD into Azure.  
- Deploy a new VM from the imported disk.  

## 🛠️ Steps

### 1. Simulate AWS Export
- Pretend you exported a VHD from AWS EC2.  
- For the lab, use a pre-prepared VHD file (or small local image).  

---

### 2. Upload VHD to Azure Storage

    az storage account create \
      --name migratevhdstore \
      --resource-group rg-migrate-demo \
      --location australiaeast \
      --sku Standard_LRS

    az storage container create \
      --account-name migratevhdstore \
      --name vhds

    az storage blob upload \
      --account-name migratevhdstore \
      --container-name vhds \
      --file sample.vhd \
      --name imported.vhd

---

### 3. Create Managed Disk from VHD

    az disk create \
      -g rg-migrate-demo \
      -n aws-imported-disk \
      --source https://migratevhdstore.blob.core.windows.net/vhds/imported.vhd \
      --os-type Linux

---

### 4. Create a VM from the Imported Disk

    az vm create \
      --resource-group rg-migrate-demo \
      --name aws-migrated-vm \
      --attach-os-disk aws-imported-disk \
      --os-type Linux \
      --size Standard_B1s \
      --admin-username azureuser \
      --generate-ssh-keys \
      --vnet-name vnet-migrate \
      --subnet subnet-migrate \
      --nsg nsg-migrate

---

### 5. Validate

    ./env.sh status
    ssh azureuser@<aws-migrated-vm-ip>

---

### 6. Cleanup (Optional)

    ./env.sh cleanup
    az storage account delete -n migratevhdstore -g rg-migrate-demo --yes --no-wait

---

## 📘 Notes
- In real migrations, Azure Migrate with AWS connector automates this.  
- VHD import is the simplest way to simulate cross-cloud rehost.  
- Demonstrates how workloads can be “lifted” from AWS to Azure.  

✅ **End of Lab** — you have completed an AWS-to-Azure migration simulation.
