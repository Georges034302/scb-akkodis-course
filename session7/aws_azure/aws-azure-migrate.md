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

## 3) In the Azure Portal
- Open your **Azure Migrate project → aws-migrate-target**.
- Under **Migration tools → Migration and modernization**, click **Discover**.
- Select **Using appliance** (✅ correct for this lab).
- When asked **Are your servers virtualized?**
  - Select **Physical or other (AWS, GCP, Xen, etc.)**.
- You will see the guided steps to deploy the appliance.

- **Generate Project Key**
  - Enter a name for your appliance (e.g., `awsappkey001`).
  - Click **Generate key** → wait for the key to be created.
  - Azure will display:  
    *“Checking prerequisites and creating the required Azure resources. This may take a few minutes.”*
  - Copy the **Project Key** — you will need it when registering the appliance.
  - Note: Azure automatically creates resources for migration tracking in your subscription.

- **Download the Appliance Package**
  - Download the `.zip` package (~500 MB).
  - The package contains a PowerShell script to install the appliance.
  - This file must be copied into a **Windows Server VM** that you will prepare in AWS.

---

## 4) Create the Appliance VM in AWS EC2
- **Launch Instance**
  - Go to **EC2 → Launch instance**.
  - Name the instance: `AWS-Appliance-VM`.
  - (Optional) Add tags such as:
    - `Project = AzureMigrate`
    - `Role = Appliance`

- **Choose AMI**
  - Select a supported Windows Server image:
    - Name: **AWS-Appliance-VM**
    - Recommended: **Windows Server 2022 Datacenter (64-bit, x86)**.
    - If unavailable, you may see **Windows Server 2025**. While it may work, only 2016/2019/2022 are officially supported.
  - Example AMI ID (region-specific): `ami-09bbc01c23bd07334`.
  - Default username: `Administrator`.

- **Instance Type**
  - Select: **c5.2xlarge** (8 vCPUs, 16 GiB memory).
  - Meets Microsoft’s minimum appliance requirements.

- **Key Pair (Login)**
  - Select an existing **key pair** or create a new one.
  - Download the `.pem` file if new.
  - Required to decrypt the Windows Administrator password after launch.

- **Network Settings**
  - VPC: Use default or one with Internet access.
  - Subnet: Any with outbound Internet.
  - Auto-assign Public IP: **Enable**.
  - Security Group: Add inbound rules:
    - RDP (TCP/3389) → Source: restrict to **your IP** if possible.
    - HTTPS (TCP/443) → Source: **0.0.0.0/0** (required for Azure communication).
    - HTTP (TCP/80) → Source: **0.0.0.0/0** (optional, not required for appliance).
  - Outbound: Allow all (default).

- **Storage**
  - Root volume:
    - Size: **80 GiB**
    - Type: **gp3 SSD**
    - IOPS: default (3000)
    - Encryption: optional.

- **Advanced Details**
  - CPU options: default (8 vCPUs).
  - Metadata: Version 2 only (token required).
  - Shutdown behavior: Stop.
  - Tenancy: Shared.
  - EBS-optimized: Enabled.

- **Review and Launch**
  - Review all settings.
  - Click **Launch instance**.
  - When running, go to **Connect → RDP client** in the AWS console.
  - Use your key pair to decrypt the **Administrator password**.
  - Connect to the Windows VM via RDP.

---

## 5) Set Up and Configure the Appliance

- **Install the Appliance**
  - RDP into the Windows Server VM with admin rights.
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
  - (If blocked by execution policy) allow script execution temporarily:
    ```powershell
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    ```
  - Run the installer script:
    ```powershell
    .\AzureMigrateInstaller.ps1
    ```
  - ⚠️ If you see an error about `PowerShell-ISE` not found:
    - Ignore it (ISE is deprecated).
    - Manually install the missing IIS/WAS roles:
      ```powershell
      Install-WindowsFeature WAS, WAS-Process-Model, WAS-Config-APIs, Web-Server, Web-WebServer, Web-Mgmt-Service, Web-Request-Monitor, Web-Common-Http, Web-Static-Content, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-App-Dev, Web-CGI, Web-Health, Web-Http-Logging, Web-Log-Libraries, Web-Security, Web-Filtering, Web-Performance, Web-Stat-Compression, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Scripting-Tools, Web-Asp-Net45, Web-Net-Ext45, Web-Http-Redirect, Web-Windows-Auth, Web-Url-Auth
      ```
    - Verify installation:
      ```powershell
      Get-WindowsFeature | Where-Object {$_.InstallState -eq "Installed"} | Select-Object DisplayName, Name
      ```
    - Re-run the installer:
      ```powershell
      .\AzureMigrateInstaller.ps1
      ```
  - Wait for the installer to complete. It installs prerequisites and appliance services.
  - Note the **Appliance Configuration Manager URL** (e.g., `https://<VMName>:44368`).

- **Configure and Start Discovery**
  - Open the **Appliance Configuration Manager** in a browser on the VM using the provided URL.
  - Paste the **Project Key** you generated earlier.
  - Sign in with your **Azure account** to register the appliance with the project.
  - Provide **AWS IAM credentials** (user or role) so the appliance can query AWS APIs.
  - *(Optional)* For **dependency mapping**:
    - Provide Linux guest OS credentials in the configuration manager, or
    - Install the **Dependency Agent** on your AWS VMs.
  - Start discovery.

### ✅ Expected Result
- The appliance VM is running in AWS.
- In the Azure Portal, the appliance shows as **Connected** under *Discover*.
- Within ~15–30 minutes, discovered AWS EC2 instances (Linux or Windows) appear in your project.


### ✅ Expected Result
- The appliance VM is running in AWS.
- In the Azure Portal, the appliance shows as **Connected** under *Discover*.
- Within ~15–30 minutes, discovered AWS EC2 instances (Linux or Windows) appear in your project.

---

## 6) Discover AWS VMs (**source**)

1. In the Azure Migrate portal, go back to the **Discover** wizard.  
2. Confirm appliance connectivity.  
3. Select **Discover machines**.  
4. Appliance will:  
   - Collect inventory of **EC2 instances**.  
   - Pull **performance data** (CPU, memory, disk).  
   - Identify **dependencies** (if dependency mapping enabled).  

---

## 7) Run an Assessment (**target**)

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

## 8) Configure Replication (**source → target**)

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

## 9) Perform Cutover (**target**)

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

## 10) Validate the Migrated VM (**target**)

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

## 11) Cleanup (Optional)

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
