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
- Appliance deployment permissions in AWS (OVA/AMI import).  
- Firewall egress open for appliance → Azure communication (HTTPS 443).  

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

## 3) Deploy the Azure Migrate Appliance (**source: AWS**)

1. In your Azure Migrate project, go to **Servers, databases and web apps → Discover** → **Discover machines**.  
2. Select **Yes, with AWS** as the source.  
3. Download the **Azure Migrate appliance for AWS** using the wizard.  
4. Follow the wizard’s AWS steps to **create the EC2-based appliance** (the wizard guides you through AMI/OVA import or launch steps as applicable).  
5. During setup, **register the appliance** by pasting the **project key** shown in the Azure Migrate wizard.  
6. *(Optional, for dependency maps)* Provide guest credentials or install the dependency agent when prompted; otherwise discovery works but maps will be empty.

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

1. In the Azure Migrate project, open **Assessments** → **+ Create assessment**.  
2. Select the discovered AWS VMs.  
3. Configure:  
   - **Target region**: `$TGT_LOCATION`  
   - **Sizing criteria**:  
     - **Performance-based** (uses collected CPU/RAM/IO counters to right-size), or  
     - **As-on-prem** (mirrors current vCPU/RAM)  
   - **Pricing**: **Pay-as-you-go** (or **Azure Hybrid Benefit** if eligible)  
4. Review **readiness** (green/yellow/red), **recommended SKU**, and **estimated monthly cost**.

---

## 6) Configure Replication (**source → target**)

1. In **Azure Migrate → Replicate**, select the AWS VMs.  
2. Configure replication:
   - **Target Subscription & RG**: `$TGT_RG`  
   - **Target VNet/Subnet**: `$TGT_VNET` / `$TGT_SUBNET`  
   - **NSG**: `$TGT_NSG`  
3. Review **Advanced** (recommended):
   - **Disk selection & type** (OS + data disks; Premium/Standard)  
   - **Availability** (none / Zone / Availability Set)  
   - **Target VM size** (override if required)  
   - **Public IP** (enable if you plan to SSH/HTTP directly for validation)  
   - **Licensing** (Azure Hybrid Benefit if eligible)

> After you start replication, monitor progress in **Replicated items**.

---

## 7) Perform Cutover (**target**)

1. Verify **Compute quotas** in `$TGT_LOCATION` (insufficient vCPUs will block cutover).  
2. In **Azure Migrate → Replicated items**, select the VM → **Migrate**.  
3. Choose **Shut down and cut over** (optional shutdown of the AWS source).  
4. Azure Migrate performs a final sync and creates an **Azure VM** in `$TGT_RG`.

After cutover, identify the actual VM name and IP:

```bash
# Show the most recently created VM in the target RG (adjust if needed)
VM_NAME=$(az vm list -g "$TGT_RG" --query "[-1].name" -o tsv)
echo "Created VM: $VM_NAME"

PUBLIC_IP=$(az vm show -d -g "$TGT_RG" -n "$VM_NAME" --query publicIps -o tsv)
echo "Public IP: ${PUBLIC_IP:-<none>}"
```

> If there is **no Public IP**, validate via **Azure Bastion** or attach a temporary public IP to the NIC.

---

## 8) Validate the Migrated VM (**target**)

```bash
# If a Public IP exists:
VM_NAME=$(az vm list -g "$TGT_RG" --query "[-1].name" -o tsv)
PUBLIC_IP=$(az vm show -d -g "$TGT_RG" -n "$VM_NAME" --query publicIps -o tsv)

echo "VM_NAME=$VM_NAME"
echo "PUBLIC_IP=${PUBLIC_IP:-<none>}"

# SSH (Linux) — replace <username> with your expected user for the image
ssh <username>@"$PUBLIC_IP" hostname

# Optional web check if you know the workload exposes HTTP:
curl -I "http://$PUBLIC_IP"
```

> **No Public IP?** Use **Azure Bastion** from the VM’s **Connect** menu, or attach a temporary public IP.

---

## 9) Cleanup (Optional)

- **Azure**  
  ```bash
  ./lab3-env.sh cleanup
  ```  

- **AWS**  
  - Terminate the **Azure Migrate appliance** EC2 instance.  
  - Remove **temporary IAM users/roles/keys** created for the appliance.  
  - Delete any **S3 import buckets**, **snapshots/AMIs**, or other temporary artifacts used during the appliance import process.

---

## 🔧 Quick Troubleshooting Tips

- **Appliance not showing as connected:** Confirm outbound **HTTPS (443)** from the appliance to Azure; configure proxy if required.  
- **No machines discovered:** Re-check AWS credentials in the appliance and region selection.  
- **Dependency maps empty:** Install the dependency agent or provide guest credentials during discovery.  
- **Cutover fails:** Check **Compute quotas** in `$TGT_LOCATION` and **target VM SKU** availability.  
- **Can’t SSH/HTTP:** Ensure replication config included a **Public IP**, or use **Azure Bastion**. Verify NSG rules on `$TGT_NSG`.

---

## 📘 Notes
- This lab uses **Azure Migrate: Server Migration** with the AWS connector, not manual VHD export.  
- Benefits include:  
  - Automated discovery, dependency mapping, and assessments.  
  - Continuous replication, test failover, and orchestrated cutover.  
- This is the **recommended production workflow** for cross-cloud rehost migrations.  

✅ **End of Lab** — You migrated AWS EC2 workloads (**-source**) into Azure (**-target**) using Azure Migrate.
