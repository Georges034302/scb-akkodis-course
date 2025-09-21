# Lab 3: AWS to Azure Migration (EC2 Export → Azure Import)

This lab demonstrates a **real cross‑cloud migration** by exporting an AWS EC2 instance (web server) to a VHD, copying it to Azure Blob Storage, and creating a VM from that disk in Azure.
<img width="1536" height="1024" alt="AWS-Azure--VHD-migration" src="https://github.com/user-attachments/assets/e0c666fd-15b8-4f9d-b6c6-e75297b1cdaa" />


> Uses **password auth** (not SSH keys) and **`SUFFIX=$RANDOM`** to guarantee unique names.  
> The Azure side uses a dedicated **`lab3-env.sh`** to prepare the landing zone (RG/VNet/Subnet/NSG).

---

## 🎯 Objectives
- Export an **AWS EC2** VM image (AMI) as a **VHD** into S3  
- Copy that VHD into **Azure Blob Storage** (with SAS)  
- Create a **Managed Disk** and **VM** in Azure from the imported VHD  
- Validate via **SSH** (password) and optional web test

---

## ✅ Prerequisites
- AWS CLI authenticated to your AWS account (with permissions for AMI/S3/export)  
- Azure CLI authenticated to your Azure subscription  
- `azcopy` available locally (for cross‑cloud copy)  
- Network egress allowed to SSH (22) from your client IP  
- The **`vmimport`** service role exists in AWS for EC2 VM Import/Export (if not, create it via AWS docs)

---

## 1) Login & Initialize the Azure Environment

Run these from the `session7` folder. The script prepares **Azure source landing zone** used by the migrated VM:
- RG: `rg-migrate-demo`
- VNet/Subnet: `vnet-migrate` / `subnet-migrate`
- NSG: `nsg-migrate` with SSH allow rule (optionally locked to your `/32`)

```bash
# Make script executable
chmod +x lab3-env.sh

# Log into Azure only if needed (no-op if already logged in)
./lab3-env.sh login   # prints the active subscription and sets defaults

# Provision/ensure RG, VNet, Subnet, NSG
./lab3-env.sh init    # idempotent: creates only if missing

# Quick health check
./lab3-env.sh status  # exits non-zero if anything is missing
```

> If you’d like to lock SSH to your current public IP, re-run:  
> `SSH_SOURCE=auto ./lab3-env.sh init`

---

## 2) Prepare Unique Names & Identify the AWS Instance

```bash
# Create a unique suffix to avoid global name collisions (storage account, VM names, etc.)
SUFFIX=$RANDOM

# Replace with your real EC2 instance ID (the web server you want to migrate)
EC2_ID="i-xxxxxxxxxxxx"
```

---

## 3) Create an AMI From the Running EC2 (No Reboot)

```bash
# Create an image (AMI) of the EC2 instance without reboot to avoid downtime
aws ec2 create-image \
  --instance-id "$EC2_ID" \
  --name "WebServerExport-$SUFFIX" \
  --no-reboot
```

```bash
# OPTIONAL: capture the AMI ID from the previous command (or via describe-images)
AMI_ID=$(aws ec2 describe-images --owners self \
  --filters "Name=name,Values=WebServerExport-$SUFFIX" \
  --query "Images[0].ImageId" -o tsv)
echo "Using AMI: $AMI_ID"
```

> ✅ **Note:** EC2 export rules apply. Instances based on some marketplace AMIs cannot be exported. Using *your* AMI is the supported route.

---

## 4) Create an S3 Bucket for Export

```bash
# Create an S3 bucket (must be globally unique) to hold the exported VHD
aws s3 mb "s3://ec2-export-bucket-$SUFFIX"
```

> Ensure the **`vmimport`** role exists and is trusted by `vmie.amazonaws.com` (VM Import/Export service).

---

## 5) Export the AMI to VHD in S3

```bash
# Start the export of the AMI to VHD in the S3 bucket
EXPORT_TASK_ID=$(aws ec2 export-image \
  --image-id "$AMI_ID" \
  --disk-image-format VHD \
  --s3-export-location S3Bucket="ec2-export-bucket-$SUFFIX",S3Prefix="exports/" \
  --query "ExportImageTaskId" -o tsv)
echo "Export task: $EXPORT_TASK_ID"
```

```bash
# Poll export status until it completes (Status should become 'completed')
aws ec2 describe-export-image-tasks \
  --export-image-task-ids "$EXPORT_TASK_ID"
```

> When complete, the VHD will appear under `s3://ec2-export-bucket-$SUFFIX/exports/`.

---

## 6) Create Azure Storage (Unique) & Container

```bash
# Storage account names must be globally unique, 3–24 lowercase alphanumeric
SA_NAME="migratevhdstore$SUFFIX"

# Create a storage account in Australia East to host the uploaded VHD
az storage account create \
  --name "$SA_NAME" \
  --resource-group rg-migrate-demo \
  --location australiaeast \
  --sku Standard_LRS

# Create a container to hold VHDs
az storage container create \
  --account-name "$SA_NAME" \
  --name vhds \
  --auth-mode login
```

```bash
# Generate a SAS for the container for WRITE/CREATE/LIST (valid for ~4 hours)
# Adjust expiry if needed (UTC). This SAS is used by azcopy as destination credentials.
EXPIRY=$(date -u -d "+4 hours" '+%Y-%m-%dT%H:%MZ')
SAS=$(az storage container generate-sas \
  --account-name "$SA_NAME" \
  --name vhds \
  --permissions acwl \
  --expiry "$EXPIRY" \
  --auth-mode login \
  -o tsv)
echo "SAS generated (expires $EXPIRY)"
```

---

## 7) Copy the VHD From S3 → Azure Blob (AzCopy)

```bash
# Determine source object key in S3 (replace with your actual exported object name)
SRC_S3_URL="https://s3.amazonaws.com/ec2-export-bucket-$SUFFIX/exports/myexport.vhd"

# Destination blob URL with SAS
DST_BLOB_URL="https://$SA_NAME.blob.core.windows.net/vhds/imported-$SUFFIX.vhd?$SAS"

# Use AzCopy to transfer directly across clouds (no local disk usage)
azcopy copy "$SRC_S3_URL" "$DST_BLOB_URL" --recursive=false
```

> If direct S3 access is blocked on your network, download locally and then use `az storage blob upload` as a fallback.

---

## 8) Create a Managed Disk From the Imported VHD

```bash
# Create a managed disk in Azure from the uploaded VHD (OS type Linux)
az disk create \
  --resource-group rg-migrate-demo \
  --name aws-imported-disk-$SUFFIX \
  --source "https://$SA_NAME.blob.core.windows.net/vhds/imported-$SUFFIX.vhd" \
  --os-type Linux
```

---

## 9) Create the Migrated VM in Azure (Password Auth)

```bash
# Prompt securely for the admin password (we are not using SSH keys in this lab)
read -s -p "Enter a secure password for the migrated VM admin user: " ADMIN_PASSWORD && echo

# Create the VM by attaching the imported OS disk; place it into the prepared VNet/Subnet/NSG
az vm create \
  --resource-group rg-migrate-demo \
  --name aws-migrated-vm-$SUFFIX \
  --attach-os-disk aws-imported-disk-$SUFFIX \
  --os-type Linux \
  --size Standard_B1s \
  --admin-username azureuser \
  --admin-password "$ADMIN_PASSWORD" \
  --authentication-type password \
  --vnet-name vnet-migrate \
  --subnet subnet-migrate \
  --nsg nsg-migrate
```

---

## 10) Validate the Migrated VM

```bash
# Confirm environment health
./lab3-env.sh status

# Fetch the VM public IP
PUBLIC_IP=$(az vm show -d \
  --resource-group rg-migrate-demo \
  --name aws-migrated-vm-$SUFFIX \
  --query publicIps -o tsv)
echo "Migrated VM Public IP: $PUBLIC_IP"

# Quick non-interactive SSH check: prints hostname then disconnects
ssh azureuser@"$PUBLIC_IP" hostname
# Expected: aws-migrated-vm-$SUFFIX
```

> If your EC2 was a web server (Apache/Nginx), test in browser: `http://$PUBLIC_IP`

---

## 11) Cleanup (Optional)

```bash
# Remove Azure resources created by the lab (keeps your subscription tidy)
./lab3-env.sh cleanup

# Delete the storage account that holds the imported VHD
az storage account delete \
  --name "$SA_NAME" \
  --resource-group rg-migrate-demo \
  --yes \
  --no-wait
```

> In AWS, you can optionally delete the S3 export bucket and the AMI once you’re done.

---

## 📘 Notes
- **EC2 export eligibility**: marketplace/native AMIs may not be exportable; using your own AMI is required.  
- **ASR vs Manual**: Production cross‑cloud migrations are best done with **Azure Migrate: Server Migration** (agentless incremental replication + orchestrated cutover). This lab uses the **manual VHD** path for clarity.  
- **Security**: Prefer locking NSG SSH to your `/32` with `SSH_SOURCE=auto` in `lab3-env.sh`.  
- **Costs**: Storage accounts, managed disks, and VMs incur charges while present.

✅ **End of Lab** — You exported an AWS EC2 VM, imported the VHD into Azure, created a managed disk and VM, and validated access.
