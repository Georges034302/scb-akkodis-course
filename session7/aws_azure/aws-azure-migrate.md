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
2. Click Servers, databases and web apps
3. Create a project:  
   - **Subscription**: Azure subscription 1
   - **Resource group**: rg-migrate-target
   - **Project name**: aws-migrate-target
   - **Geography**: Australia
   - **Connectivity method**: Public endpoint
4. **Create**

> ⚠️ Although `lab3-env.sh` can attempt to create a project (`CREATE_MIGRATE_PROJECT=true`), the **Portal is the recommended method**.

---

## 3) Deploy the Azure Migrate Appliance (AWS source)

### In the Azure Portal
- Open your **Azure Migrate project → aws-migrate-target**.
- Under **Migration tools → Migration and modernization**, click **Discover**.
- Select **Using appliance** (✅ correct for this lab).
- When asked **Are your servers virtualized?**
  - Select **Physical or other (AWS, GCP, Xen, etc.)**.
- You will see the guided steps to deploy the appliance:

  - **1. Generate project key**
    - Enter a name for your appliance (e.g., `awsappkey001`).
    - Click **Generate key** → wait for the key to be created.
    - Azure will display a message:  
      *“Checking prerequisites and creating the required Azure resources. This may take a few minutes.”*
    - Copy the **Project Key** — you will need it when registering the appliance.
    - Note: Azure automatically creates some resources in your subscription for migration tracking.

  - **2. Download Azure Migrate appliance**
    - Download the `.zip` package (~500 MB).
    - The package contains a PowerShell script to install the appliance.
    - This file must be copied into a **Windows Server VM** that you will prepare in AWS.

  - **3. Set up the appliance**
    - Provision a **Windows Server 2022 VM** in AWS EC2:
      - Minimum requirements:
        - **8 vCPUs**
        - **16 GB RAM**
        - **80 GB disk**
      - Place the VM in a subnet with outbound Internet access.
      - Ensure outbound **HTTPS (443)** to Azure endpoints is allowed in the Security Group/NACL.
    - RDP into the Windows Server VM with administrator privileges.
    - Copy the downloaded `.zip` package into the VM.
    - Extract the `.zip` file to a local folder (e.g., `C:\AzureMigrateAppliance\`).
    - Open **Windows PowerShell as Administrator**.
    - Navigate to the extracted folder:
      ```powershell
      cd "C:\AzureMigrateAppliance\"
      ```
    - (Optional) Unblock downloaded files:
      ```powershell
      Get-ChildItem -Recurse | Unblock-File
      ```
    - (If execution policy blocks scripts) allow execution temporarily:
      ```powershell
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
      ```
    - Run the installer script provided in the package:
      ```powershell
      .\AzureMigrateInstaller.ps1
      ```
    - Wait for the installer to complete. It installs prerequisites and services.
    - At the end, note the **Appliance Configuration Manager URL** (for example: `https://<VMName>:44368`).

  - **4. Configure the appliance and initiate discovery**
    - Open the **Appliance Configuration Manager** in a browser on the VM using the URL provided by the installer.
    - Paste the **Project Key** you generated earlier.
    - Sign in with your **Azure account** to register the appliance with the `aws-migrate-target` project.
    - Provide **AWS IAM credentials** (user or role) so the appliance can connect to AWS APIs and discover EC2 instances.
    - *(Optional)* For **dependency mapping**:
      - Provide Linux guest OS credentials in the configuration manager, or
      - Install the **Dependency Agent** on your AWS Linux VMs.
    - Start the discovery process.

### ✅ Expected Result
- The appliance VM is running in AWS.
- In the Azure Portal, the appliance shows as **Connected** under *Discover*.
- Within ~15–30 minutes, discovered AWS EC2 instances (Linux or Windows) begin appearing in your project.



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
