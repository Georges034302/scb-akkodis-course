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
- **AWS CLI** installed and authenticated with an IAM identity that can read EC2/AMI/Snapshots and manage a Windows EC2 instance for the appliance.  
- **Azure CLI** installed and authenticated to the target subscription.  
- **lab3-env.sh** prepared (creates target RG/VNet/Subnet/NSG).  
- Ability to open outbound **HTTPS (443)** from the appliance VM to Azure.  
- RDP access to the Windows appliance VM.  

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
2. Click **Servers, databases and web apps**.  
3. Create a project:  
   - **Subscription**: Azure subscription 1  
   - **Resource group**: `rg-migrate-target`  
   - **Project name**: `aws-migrate-target`  
   - **Geography**: Australia  
   - **Connectivity method**: Public endpoint  
4. Click **Create**.

> `lab3-env.sh` can also create the project, but the **Portal** flow is recommended for clarity.

---

## 3) In the Azure Portal

- Open **Azure Migrate → aws-migrate-target**.  
- Under **Migration tools → Migration and modernization**, click **Discover**.  
- Select **Using appliance**.  
- For **Are your servers virtualized?** select **Physical or other (AWS, GCP, Xen, etc.)**.  

### Generate Project Key
- Enter an appliance name (e.g., `awsappkey001`).  
- Click **Generate key** and wait for the operation to finish.  
- Copy the **Project Key** (used to register the appliance).  

### Download the Appliance Package
- Download the `.zip` package (~500 MB).  
- This package contains **AzureMigrateInstaller.ps1** which sets up the appliance on Windows.  
- Copy the `.zip` to a Windows Server VM you will create in AWS (next step).

---

## 4) Create the Appliance VM in AWS EC2

- **Launch instance** → Name: `AWS-Appliance-VM`.  
- **AMI**: Windows Server **2022 Datacenter (64-bit)** (2016/2019/2022 are supported).  
- **Instance type**: `c5.2xlarge` (8 vCPU, 16 GiB).  
- **Key pair**: Select or create; keep `.pem` to decrypt `Administrator` password.  
- **Network**: Public IP = **Enabled**; Subnet with Internet egress.  
- **Security group**:  
  - Inbound: **RDP 3389** (restrict to your IP).  
  - Inbound: **HTTPS 443** (0.0.0.0/0).  
  - Inbound: **HTTP 80** (optional).  
  - Outbound: **Allow all**.  
- **Storage**: Root 80 GiB **gp3** SSD.  
- **Launch** → Decrypt `Administrator` password → **RDP** into the VM.

---

## 5) Set Up and Configure the Appliance

### 5.1) Install the Appliance (Windows VM)

1. **Copy & extract** the Azure Migrate appliance `.zip` to `C:\AzureMigrateAppliance`.  
2. **Open 64-bit PowerShell as Administrator**:  
   - Start → Windows PowerShell → **Run as administrator**.  
   - Verify:  
     ```powershell
     [Environment]::Is64BitProcess   # must return True
     ```
   - If `False`, start explicitly:  
     ```powershell
     & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
     ```
3. **Prepare & run installer**:  
   ```powershell
   Set-Location "C:\AzureMigrateAppliance"
   Set-ExecutionPolicy -Scope Process Bypass -Force
   Get-ChildItem -Recurse | Unblock-File
   .\AzureMigrateInstaller.ps1
   ```
4. **If you hit the deprecated PowerShell ISE feature error** on Windows Server 2022/2025:  
   - Run installer prerequisites **without** ISE and re-run:  
     ```powershell
     Install-WindowsFeature WAS, WAS-Process-Model, WAS-Config-APIs, `
       Web-Server, Web-WebServer, Web-Mgmt-Service, Web-Request-Monitor, `
       Web-Common-Http, Web-Static-Content, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, `
       Web-App-Dev, Web-CGI, `
       Web-Health, Web-Http-Logging, Web-Log-Libraries, `
       Web-Security, Web-Filtering, `
       Web-Performance, Web-Stat-Compression, `
       Web-Mgmt-Tools, Web-Mgmt-Console, Web-Scripting-Tools, `
       Web-Asp-Net45, Web-Net-Ext45, `
       Web-Http-Redirect, Web-Windows-Auth, Web-Url-Auth
     .\AzureMigrateInstaller.ps1
     ```
   - Or remove ISE from the script and run again:  
     ```powershell
     Copy-Item .\AzureMigrateInstaller.ps1 .\AzureMigrateInstaller.ps1.bak
     (Get-Content .\AzureMigrateInstaller.ps1) -replace 'PowerShell-ISE,?\s*', '' | Set-Content .\AzureMigrateInstaller.ps1
     .\AzureMigrateInstaller.ps1
     ```
5. **Confirm the configuration UI is reachable** (the installer prints a URL like `https://<VMName>:44368`):  
   ```powershell
   $u = "https://$env:COMPUTERNAME:44368"
   Test-NetConnection -ComputerName $env:COMPUTERNAME -Port 44368   # should be TcpTestSucceeded = True
   Start-Process $u   # accept the self-signed cert warning in the browser
   ```
6. **If the site doesn’t load**:  
   ```powershell
   iisreset
   # If time/clock skew causes Azure sign-in issues, sync time:
   w32tm /resync
   ```
7. **Logs** (for any install issues):  
   `C:\ProgramData\Microsoft Azure\Logs\AzureMigrateScenarioInstaller_*.log`

---

### 5.2) Register the Appliance with the Azure Migrate Project

1. In the **Appliance Configuration Manager** (the URL from step 5.1):  
   - Continue past the certificate warning (self-signed).  
   - Paste the **Project Key** generated in Step 3.  
   - Click **Login** and sign in with your **Azure account** that has access to the project.  
   - ensure the VM date aligns with your time zone (otherwise adjust date/time)
2. Wait until the UI shows the appliance is **Registered**/**Connected** to your Azure Migrate project.  
3. **If Azure sign-in fails** (common causes):  
   - Ensure the PowerShell/browser session is on the **VM** (not your local PC).  
   - Verify outbound **443** to Azure is allowed by the instance’s security group/NACL.  
   - Run `w32tm /resync` to fix time skew and retry sign-in.  
   - If copy/paste is flaky in RDP for the Project Key, restart RDP clipboard:  
     ```powershell
     taskkill /IM rdpclip.exe /F; Start-Process rdpclip.exe
     ```

---

### 5.3) Configure AWS Access in the Appliance & Start Discovery

1. In the Configuration Manager, add **AWS account**:  
   - Choose **Access key** authentication.  
   - Enter **Access Key ID** and **Secret Access Key** of an AWS IAM principal with **read-only** permissions for EC2 (and S3 read if your environment requires it).  
   - A safe choice is to attach AWS managed policies:  
     - **AmazonEC2ReadOnlyAccess**  
     - **AmazonS3ReadOnlyAccess** (only if S3 read is needed in your environment)  
2. Select the **AWS regions** that contain your EC2 instances.  
3. (Optional) For **dependency mapping**:  
   - Provide **Windows/Linux guest credentials** here, or install the **Dependency Agent** on source VMs.  
4. Click **Start discovery**.  
5. Confirm the status changes to **Connected / Discovering**.  

**Expected:** Within ~15–30 minutes, discovered EC2 instances begin to appear in your Azure Migrate project (Step 6).

---

## 6) View Discovered AWS VMs (**source**)

1. In Azure Portal → **Azure Migrate → Migration and modernization**.  
2. Open **Discovered servers** (or **Machines**).  
3. Verify:  
   - EC2 instances are listed with OS, cores, memory, and region.  
   - If dependency mapping was enabled, dependency data will populate progressively.  
4. If nothing appears after ~30 minutes:  
   - Re-open the appliance UI and verify **AWS credentials**, **selected regions**, and **Connected** status.  
   - Check outbound connectivity from the appliance (HTTPS 443).  

---

## 7) Create and Review an Assessment (**target**)

1. In the project, go to **Assessments → + Create assessment**.  
2. Select the discovered AWS VMs for the assessment.  
3. Configure assessment settings:  
   - **Target region:** `$TGT_LOCATION`  
   - **Sizing:** **Performance-based** (recommended) or **As-on-prem**  
   - **Pricing:** **Pay-as-you-go** (or **Azure Hybrid Benefit** if eligible)  
4. Create the assessment and open it to review:  
   - **Readiness** (green/yellow/red) with reasons.  
   - **Recommended Azure VM SKUs** per machine.  
   - **Cost estimates** for compute and storage.  
5. Adjust settings and re-run if the SKUs/cost don’t align with your objectives.

---

## 8) Configure Replication (**source → target**)

1. In **Azure Migrate → Replicate**, select the AWS VMs to migrate.  
2. **Target settings:**  
   - **Subscription**: your target subscription  
   - **Resource group**: `$TGT_RG`  
   - **Virtual network / Subnet**: `$TGT_VNET` / `$TGT_SUBNET`  
   - **Network security group**: `$TGT_NSG`  
3. **Compute & storage details:**  
   - **Target VM size**: accept recommendation or override.  
   - **Availability options**: None / Zone / Availability Set.  
   - **OS & data disks**: choose disk types (Premium/Standard).  
   - **Public IP**: enable if you plan to validate via SSH/RDP/HTTP directly.  
   - **Licensing**: enable Azure Hybrid Benefit if you’re eligible.  
4. Start replication and monitor **Jobs** and **Replicated items** for progress.  

**Tip:** If a machine has large disks, initial sync can take time. Ensure appliance stays powered and connected.

---

## 9) Perform Cutover to Azure (**target**)

1. **Check Azure quotas** in `$TGT_LOCATION` (insufficient vCPU/cores will block cutover). Quick CLI check:  
   ```bash
   az vm list-usage -l "$TGT_LOCATION" -o table
   ```
2. In **Replicated items**, select each VM → **Migrate**.  
3. Choose whether to **Shut down the source** (optional).  
4. Azure Migrate runs a final sync and creates an **Azure VM** in `$TGT_RG`.  
5. Verify the VM resource shows **Running**.

**Identify the new VM and IP:**  
```bash
VM_NAME=$(az vm list -g "$TGT_RG" --query "[-1].name" -o tsv)
echo "Created VM: $VM_NAME"
PUBLIC_IP=$(az vm show -d -g "$TGT_RG" -n "$VM_NAME" --query publicIps -o tsv)
echo "Public IP: ${PUBLIC_IP:-<none>}"
```

---

## 10) Validate the Migrated VM (**target**)

- **Linux**:  
  ```bash
  ssh <username>@$PUBLIC_IP hostname
  ```
- **Windows**: Use **RDP** or **Azure Bastion** from the VM’s **Connect** menu.  
- **HTTP check** (if applicable):  
  ```bash
  curl -I http://$PUBLIC_IP
  ```
- Validate application services and logs as appropriate for your workload.

---

## 11) Cleanup (Optional)

**Azure**  
```bash
./lab3-env.sh cleanup
```

**AWS**  
- Terminate the **Azure Migrate appliance** EC2 instance.  
- Remove any **temporary IAM users/roles/keys** created for discovery.  
- Delete **temporary artifacts** used during setup (e.g., S3 objects, snapshots) if applicable.

---

## 🔧 Troubleshooting Reference

- **Appliance UI not loading** → `Test-NetConnection $env:COMPUTERNAME -Port 44368`, run `iisreset`.  
- **Still can’t sign in to Azure** → ensure outbound 443, sync time (`w32tm /resync`).  
- **No machines discovered** → verify AWS credentials/regions in the appliance UI and that the status is **Connected**.  
- **Cutover blocked** → check region quotas (`az vm list-usage`), ensure target VM size is available in `$TGT_LOCATION`.  
- **Cannot SSH/HTTP to VM** → ensure Public IP assigned or use Bastion; verify NSG `$TGT_NSG` allows required inbound ports.  

---

## 📘 Notes
- This lab uses **Azure Migrate: Server Migration** with the AWS connector (appliance-based discovery/replication).  
- Recommended workflow: discover → assess → replicate → (optional test) → cutover → validate.  

✅ **End of Lab** — You migrated AWS EC2 workloads (**source**) into Azure (**target**) using Azure Migrate.
