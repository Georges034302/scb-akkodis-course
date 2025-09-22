# Lab 3-B: AWS → Azure Migration with Azure Migrate (Server Migration)

This lab demonstrates a **cross-cloud migration** using **Azure Migrate: Server Migration**.  
You will configure Azure Migrate to connect to **AWS (-source)**, discover workloads, assess readiness, and replicate them into **Azure (-target)** for cutover.

<img width="1536" height="1024" alt="AWS-Azure-Migrate" src="https://github.com/user-attachments/assets/6b2d0d4f-a623-4bc2-a524-3e5b0998acc1" />

---

## 🎯 Objectives
- Provision an **Azure Migrate project** in the portal.  
- Deploy the **Azure Migrate appliance** into AWS (-source).  
- **Discover AWS workloads** (VM inventory, performance data, dependencies).  
- Run an **assessment** for readiness, sizing, and cost.  
- Configure **replication** of AWS VMs into Azure (-target).  
- Perform **cutover** to create Azure VMs.  
- Validate migrated workloads in Azure.  

---

## ✅ Prerequisites
- **AWS CLI** authenticated with permissions for EC2/AMI/S3.  
- **Azure CLI** authenticated with subscription access.  
- **lab3-env.sh** prepared (TARGET RG/VNet/Subnet/NSG).  
- Appliance deployment permissions in AWS (OVA import).  
- Firewall egress open for appliance → Azure communication.  

---

## 1) Initialize the Azure TARGET Environment

Run `lab3-env.sh` to prepare the **TARGET landing zone** (RG, VNet/Subnet, NSG with SSH/HTTP/HTTPS):

```bash
chmod +x lab3-env.sh
./lab3-env.sh login
./lab3-env.sh init
./lab3-env.sh status

# Load vars for later use
source .lab.env
echo "TGT_RG=$TGT_RG TGT_VNET=$TGT_VNET TGT_SUBNET=$TGT_SUBNET TGT_NSG=$TGT_NSG TGT_LOCATION=$TGT_LOCATION"
```

---

## 2) Provision an Azure Migrate Project (**target**)

1. In the **Azure Portal**, search for **Azure Migrate**.  
2. Create a project:  
   - **Name**: `aws-migrate-target`  
   - **Resource Group**: `$TGT_RG` (default: `rg-migrate-target`)  
   - **Region**: `$TGT_LOCATION` (default: `australiaeast`)  

> ⚠️ Although `lab3-env.sh` can attempt to create a project (`CREATE_MIGRATE_PROJECT=true`), the **Portal is the recommended method**.

---

## 3) Deploy the Azure Migrate Appliance (**source**)  

1. In the project, under **Servers, databases, and web apps → Discover**, choose **Discover machines**.  
2. Select **Yes, with AWS** as the source.  
3. Download the **Azure Migrate appliance OVA for AWS**.  
4. Import the OVA into AWS EC2 (recommended: `t2.medium` or higher).  
5. During setup, register the appliance with the Azure Migrate project (copy/paste the project key).  

---

## 4) Discover AWS VMs (**source**)  

1. In the Azure Migrate portal, go back to the **Discover** wizard.  
2. Confirm appliance connectivity.  
3. Select **Discover machines**.  
4. Appliance will:  
   - Collect inventory of **EC2 instances**.  
   - Pull **performance data** (CPU, memory, disk).  
   - Identify **dependencies** (if dependency mapping enabled).  

---

## 5) Run an Assessment (**target**)  

1. In the Azure Migrate project, go to **Assessments** → **+ Create assessment**.  
2. Choose the discovered AWS VMs.  
3. Configure:  
   - Target region: `$TGT_LOCATION`  
   - Sizing criteria: **Performance-based**  
   - Pricing: **Pay-as-you-go**  
4. Review cost estimates, Azure SKU recommendations, and readiness (green/yellow/red).  

---

## 6) Configure Replication (**source → target**)  

1. In the portal, under **Replicate**, select the AWS VMs to migrate.  
2. Configure replication settings:  
   - **Target Subscription & RG**: `$TGT_RG`  
   - **Target VNet/Subnet**: `$TGT_VNET` / `$TGT_SUBNET`  
   - **NSG**: `$TGT_NSG` (already provisioned)  
   - **OS disk**: default  
   - **Replication policy**: default (24h retention)  
3. Replication begins; monitor under **Replicated items**.  

---

## 7) Perform Cutover (**target**)  

1. In **Azure Migrate → Replicated items**, select the AWS VM.  
2. Choose **Migrate → Shut down and cut over**.  
3. Azure Migrate will:  
   - Shut down the EC2 instance (optional).  
   - Perform a final sync.  
   - Create a **new Azure VM** in `$TGT_RG`.  

---

## 8) Validate the Migrated VM (**target**)  

```bash
# Get public IP of migrated VM
PUBLIC_IP=$(az vm show -d \
  --resource-group "$TGT_RG" \
  --name "aws-migrated-vm-target" \
  --query publicIps -o tsv)
echo "Migrated VM Public IP: $PUBLIC_IP"

# SSH validation
ssh azureuser@"$PUBLIC_IP" hostname

# Web validation (Apache)
curl -I "http://$PUBLIC_IP"
```

> For browser validation, open: `http://$PUBLIC_IP`.

---

## 9) Cleanup (Optional)  

- In Azure:  
  ```bash
  ./lab3-env.sh cleanup
  ```  
- In AWS:  
  - Terminate the **Azure Migrate appliance** VM.  
  - Delete exported resources (optional).  

---

## 📘 Notes
- This lab uses **Azure Migrate: Server Migration** with the AWS connector, not manual VHD export.  
- Benefits include:  
  - Automated discovery, dependency mapping, and assessments.  
  - Continuous replication, test failover, and orchestrated cutover.  
- This is the **recommended production workflow** for cross-cloud rehost migrations.  

✅ **End of Lab** — You migrated AWS EC2 workloads (**-source**) into Azure (**-target**) using Azure Migrate.