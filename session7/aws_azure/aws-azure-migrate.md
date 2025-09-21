# Lab 3-B: AWS to Azure Migration with Azure Migrate

This lab demonstrates a **cross-cloud migration** using **Azure Migrate: Server Migration**. You will configure Azure Migrate to connect to AWS, discover workloads, assess readiness, and replicate VMs into Azure for cutover.

---

## 🎯 Objectives
- Provision an **Azure Migrate project** in the portal.  
- Deploy the **Azure Migrate appliance** into AWS.  
- **Discover AWS workloads** (VM inventory, performance data, dependencies).  
- Run an **assessment** for readiness, sizing, and cost.  
- Configure **replication** of AWS VMs into Azure.  
- Perform **cutover** to create Azure VMs.  
- Validate migrated workloads in Azure.  

---

## 🛠️ Steps

### 1. Provision an Azure Migrate Project
1. In the **Azure Portal**, search for **Azure Migrate**.  
2. Click **Create project**, name it `aws-migrate-lab`, and place it in `rg-migrate-demo`.  
3. Region: `Australia East`.  

---

### 2. Deploy the Azure Migrate Appliance into AWS
1. In the project, under **Servers, databases, and web apps → Discover**, choose **Discover machines**.  
2. Select **Yes, with AWS** as the source.  
3. Download the **Azure Migrate appliance OVA for AWS**.  
4. Import it into AWS as an EC2 VM (t2.medium or higher, Windows Server base).  
5. During setup, register the appliance with your Azure Migrate project (copy the project key).  

---

### 3. Discover AWS VMs
1. In the Azure Migrate portal, return to the **Discover** wizard.  
2. Confirm appliance connectivity.  
3. Select **Discover machines**.  
4. Appliance will:  
   - Collect **inventory of EC2 instances**.  
   - Pull **performance data** (CPU, memory, disk).  
   - Identify **application dependencies** if enabled.  

---

### 4. Run an Assessment
1. In the Azure Migrate project, go to **Assessments** → **+ Create assessment**.  
2. Choose the discovered AWS VMs.  
3. Configure:  
   - Target region: `Australia East`  
   - Sizing criteria: Performance-based  
   - Pricing: Pay-as-you-go  
4. Review cost estimates, Azure SKU recommendations, and readiness (green/yellow/red flags).  

---

### 5. Configure Replication
1. In the portal, under **Replicate**, select the AWS VMs to migrate.  
2. Configure replication settings:  
   - Target subscription and RG: `rg-migrate-demo`  
   - Target VNet/Subnet: `vnet-migrate` / `subnet-migrate`  
   - OS disk: select default  
   - Replication policy: default 24h retention  
3. Replication begins; monitor under **Replicated items**.  

---

### 6. Perform Cutover
1. In **Azure Migrate → Replicated items**, select the AWS VM.  
2. Choose **Migrate → Shut down and cut over**.  
3. Azure Migrate:  
   - Shuts down the EC2 instance (optional).  
   - Performs a final sync.  
   - Creates a **new Azure VM** in `rg-migrate-demo`.  

---

### 7. Validate Migrated VM

```bash
# Get public IP of migrated VM
PUBLIC_IP=$(az vm show -d \
  --resource-group rg-migrate-demo \
  --name aws-migrated-vm \
  --query publicIps -o tsv)
echo "Migrated VM: $PUBLIC_IP"

# SSH into it with the credentials you set
ssh azureuser@"$PUBLIC_IP" hostname
```

Validate connectivity (web app, SSH, etc.).  

---

### 8. Cleanup (Optional)
- In Azure: delete `rg-migrate-demo`.  
- In AWS: terminate the Azure Migrate appliance, delete exported resources.  

---

## 📘 Notes
- This lab **uses Azure Migrate: Server Migration** with the AWS connector, not manual VHD export.  
- Key benefits:  
  - Automated discovery, dependency mapping, and assessments.  
  - Continuous replication, test failover, and orchestrated cutover.  
- This is the **recommended production workflow** for cross-cloud rehost migrations.  

✅ **End of Lab** — You migrated AWS EC2 workloads into Azure using Azure Migrate.  
