# 🔍 Lab Testing Checklist  

This file provides a **step-by-step validation guide** for all Session 7 migration labs. Each section includes the flow and expected outcome.

---

## **Lab 1 – Lift & Shift Migration (Snapshot + Disk)**  
1. **Run env.sh**  
   ```bash
   ./lab1-env.sh login
   ./lab1-env.sh init
   ./lab1-env.sh status
   ```  
   ✅ RG, VNet, Subnet, NSG all “exists”  

2. **Create Source VM** → name `source-vm-$SUFFIX`  
   ✅ VM deployed, reachable in Portal  

3. **Deallocate Source VM**  
   ✅ State = `Stopped (deallocated)`  

4. **Snapshot OS Disk** → `source-snap-$SUFFIX`  
   ✅ Snapshot provisioning state = `Succeeded`  

5. **Create Managed Disk** → `migrated-disk-$SUFFIX`  
   ✅ Disk provisioning state = `Succeeded`  

6. **Create Migrated VM** → `migrated-vm-$SUFFIX`  
   ✅ VM deployed  

7. **Validate**  
   ```bash
   ssh azureuser@$PUBLIC_IP hostname
   ```  
   ✅ Hostname matches `migrated-vm-$SUFFIX`  

8. **Cleanup**  
   ```bash
   ./lab1-env.sh cleanup
   ```  
   ✅ Resource group delete in progress  

---

## **Lab 2 – On-Prem to Azure Migration (ASR)**  
1. **Run lab2-env.sh**  
   ```bash
   ./lab2-env.sh login
   ./lab2-env.sh init
   ./lab2-env.sh status
   ```  
   ✅ Both **Source RG** + **Target Vault RG** + **ASR RG** created  

2. **Create Source VM** → `source-vm-$SUFFIX` in AE  
   ✅ VM deployed  

3. **Enable Replication** (Portal) → Source AE → Target ASEA  
   ✅ VM listed in **Replicated items**  

4. **Run Test Failover** → test VM in ASEA  
   ✅ Test VM booted, accessible via SSH  

5. **Run Planned Failover (Cutover)**  
   ✅ Source VM deallocated in AE  
   ✅ Replica promoted in ASEA  

6. **Validate**  
   ```bash
   ssh azureuser@$REPL_IP hostname
   ```  
   ✅ Hostname matches `source-vm-$SUFFIX`  

7. **Cleanup**  
   ```bash
   ./lab2-env.sh cleanup
   ```  
   ✅ Source RG (optional) and all Target RGs deleted  

---

## **Lab 3-A – AWS → Azure Migration (EC2 Export → VHD Import)**  
1. **Run lab3-env.sh**  
   ```bash
   ./lab3-env.sh login
   ./lab3-env.sh init
   ./lab3-env.sh status
   ```  
   ✅ Landing zone ready (RG, VNet, Subnet, NSG)  

2. **AWS EC2 Export**  
   - Create AMI of EC2  
   - Export to S3 → VHD  
   ✅ Export task = `completed`  

3. **Copy VHD to Azure Storage** (`azcopy` or blob upload)  
   ✅ Blob visible in container  

4. **Create Managed Disk** → `aws-imported-disk-$SUFFIX`  
   ✅ Disk provisioning state = `Succeeded`  

5. **Create Migrated VM** → `aws-migrated-vm-$SUFFIX`  
   ✅ VM deployed  

6. **Validate**  
   ```bash
   ssh azureuser@$PUBLIC_IP hostname
   ```  
   ✅ Hostname = `aws-migrated-vm-$SUFFIX`  

7. **Cleanup**  
   ```bash
   ./lab3-env.sh cleanup
   az storage account delete -n <SA_NAME> -g rg-migrate-demo --yes
   ```  
   ✅ RG + storage deleted  

---

## **Lab 3-B – AWS → Azure Migration with Azure Migrate**  
1. **Run lab3-env.sh**  
   ```bash
   ./lab3-env.sh login
   ./lab3-env.sh init
   ./lab3-env.sh status
   ```  
   ✅ Landing zone ready  

2. **Portal: Create Azure Migrate Project**  
   ✅ Project listed in `rg-migrate-demo`  

3. **Deploy Appliance in AWS** → registered in project  
   ✅ Appliance status = “Connected”  

4. **Discover AWS VMs**  
   ✅ VM inventory appears in Azure Migrate  

5. **Run Assessment**  
   ✅ Azure SKU recommendations and readiness results displayed  

6. **Enable Replication** → Source AWS → Target Azure VNet/Subnet  
   ✅ VM appears under **Replicated items**  

7. **Cutover** → Shut down EC2 + migrate  
   ✅ New Azure VM appears in `rg-migrate-demo`  

8. **Validate**  
   ```bash
   ssh azureuser@$PUBLIC_IP hostname
   ```  
   ✅ Hostname matches expected AWS VM name  

9. **Cleanup**  
   - Delete `rg-migrate-demo`  
   - Terminate AWS appliance  
   ✅ Both AWS + Azure test resources gone  
