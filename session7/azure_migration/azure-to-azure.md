# Lab: Azure to Azure Migration (Resource Mover / Redeploy)

This lab shows how to migrate a VM between regions or resource groups in Azure using **Resource Mover** and **Bicep/ARM redeployment**.

## 🎯 Objectives
- Learn use cases for Azure-to-Azure migrations (region move, RG restructuring).  
- Use ARM/Bicep export to redeploy a VM.  
- Validate VM redeployment in a new region/RG.  

## 🛠️ Steps

### 1. Export the VM Template

    az vm export \
      --resource-group rg-migrate-demo \
      --name source-vm \
      --output json > source-vm-template.json

---

### 2. Modify Template for Target
- Change resource group or region in the template.  
- Example: `location: australiaeast → southeastasia`.  

---

### 3. Redeploy to Target

    az group create -n rg-migrate-target -l southeastasia

    az deployment group create \
      --resource-group rg-migrate-target \
      --template-file source-vm-template.json

---

### 4. Validate

    az vm list -g rg-migrate-target -o table

SSH into the VM using the new public IP.

---

### 5. Cleanup (Optional)

    ./env.sh cleanup
    az group delete -n rg-migrate-target --yes --no-wait

---

## 📘 Notes
- Resource Mover can automate this in the Portal.  
- ARM/Bicep gives you fine control and repeatability.  
- Useful for region migrations and RG restructuring.  

✅ **End of Lab** — you have completed an Azure-to-Azure migration simulation.
