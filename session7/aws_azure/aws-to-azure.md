# Lab 3-A: AWS → Azure Migration (EC2 Export ➜ Azure Import via VHD)

This lab walks you through exporting an **AWS EC2** web server (Apache HTTP Server) to **VHD**, copying it to **Azure Blob Storage**, then creating a **Managed Disk** and **Azure VM** from that disk.

<img width="1536" height="1024" alt="AWS-Azure--VHD-migration" src="https://github.com/user-attachments/assets/e0c666fd-15b8-4f9d-b6c6-e75297b1cdaa" />

> Uses **password auth** (not SSH keys) and **`SUFFIX=$RANDOM`** to guarantee unique names.  
> The Azure side uses **`lab3-env.sh`** to prepare the landing zone (**RG/VNet/Subnet/NSG**) and write a hand-off file `.lab.env` you can `source` (# Lab 3-A: AWS → Azure Migration (EC2 Export ➜ Azure Import via VHD)

This lab walks you through exporting an **AWS EC2** web server (Apache HTTP Server) to **VHD**, copying it to **Azure Blob Storage**, then creating a **Managed Disk** and **Azure VM** from that disk — using **Lab 3 naming** where **source** artifacts end with **`-source`** (AWS) and **target** resources end with **`-target`** (Azure).

<img width="1536" height="1024" alt="AWS-Azure--VHD-migration" src="https://github.com/user-attachments/assets/e0c666fd-15b8-4f9d-b6c6-e75297b1cdaa" />

> Uses **password auth** (not SSH keys) and **`SUFFIX=$RANDOM`** to guarantee unique names.  
> The Azure side uses **`lab3-env.sh`** (TARGET-only) to prepare **TGT_RG/TGT_VNET/TGT_SUBNET/TGT_NSG** and writes `.lab.env` for sourcing.  
> **NSG Web Rules:** `lab3-env.sh` adds **HTTP (80)** and **HTTPS (443)** (with `CREATE_WEB_RULES=true`, default).

---

## 🎯 Objectives
- Export an **AWS EC2** image (AMI) as a **VHD** into **S3** (**-source** naming).  
- Copy that **VHD** into **Azure Blob Storage**.  
- Create a **Managed Disk** and **VM** in **Azure** (**-target** naming).  
- Validate via **SSH** and **HTTP/HTTPS** (Apache).

---

## ✅ Prerequisites
- **AWS CLI** authenticated (permissions for **AMI/S3/export**).  
- **Azure CLI** authenticated (subscription access).  
- **AzCopy** available locally.  
- Network egress to **SSH (22)** and **HTTP/HTTPS** from your client IP.  
- AWS **`vmimport`** service role exists and is trusted by `vmie.amazonaws.com` (VM Import/Export).  
- EC2 instance is a Linux web server (Apache) you own and can export.

---

## 1) Login & Initialize the Azure TARGET Environment

Run these from the `session7` folder. The script prepares the **Azure TARGET landing zone** and writes `.lab.env`:

```bash
chmod +x lab3-env.sh

# Login (no-op if already logged in) + register providers
./lab3-env.sh login

# Provision/ensure TARGET RG, VNet, Subnet, NSG (idempotent). Adds SSH/HTTP/HTTPS rules by default.
./lab3-env.sh init
# optionally lock SSH to your /32 and/or disable web rules:
# SSH_SOURCE=auto CREATE_WEB_RULES=false ./lab3-env.sh init

# Quick health check (non-zero exit if missing)
./lab3-env.sh status

# Load variables exported by the env script
source .lab.env
echo "TGT_RG=$TGT_RG TGT_LOCATION=$TGT_LOCATION TGT_VNET=$TGT_VNET TGT_SUBNET=$TGT_SUBNET TGT_NSG=$TGT_NSG"
```

---

## 2) Prepare Unique Names & Identify the AWS Instance (**source**)

```bash
# Unique suffix to avoid collisions
SUFFIX=$RANDOM

# Replace with your real EC2 instance ID (the Apache web server to migrate)
EC2_ID="i-xxxxxxxxxxxx"
```

---

## 3) Create an AMI From the Running EC2 (No Reboot) (**source**)

```bash
# Create an image (AMI) of the EC2 instance without reboot to avoid downtime
aws ec2 create-image \
  --instance-id "$EC2_ID" \
  --name "WebServerExport-$SUFFIX-source" \
  --no-reboot
```

```bash
# OPTIONAL: capture the AMI ID (or inspect create-image output directly)
AMI_ID=$(aws ec2 describe-images --owners self \
  --filters "Name=name,Values=WebServerExport-$SUFFIX-source" \
  --query "Images[0].ImageId" -o tsv)
echo "Using AMI: $AMI_ID"
```

> ⚠️ Some Marketplace AMIs are **not exportable**. Use an AMI you own and is eligible for export.

---

## 4) Create an S3 Bucket for Export (**source**)

```bash
# Global-unique bucket for the exported VHD (include -source naming)
aws s3 mb "s3://ec2-export-bucket-$SUFFIX-source"
```

> Ensure the **`vmimport`** role exists and is configured per AWS documentation.

---

## 5) Export the AMI to VHD in S3 (**source**)

```bash
# Export the AMI to VHD placed under the S3 prefix
EXPORT_TASK_ID=$(aws ec2 export-image \
  --image-id "$AMI_ID" \
  --disk-image-format VHD \
  --s3-export-location S3Bucket="ec2-export-bucket-$SUFFIX-source",S3Prefix="exports/" \
  --query "ExportImageTaskId" -o tsv)
echo "Export task: $EXPORT_TASK_ID"
```

```bash
# Poll export status until Status becomes 'completed'
aws ec2 describe-export-image-tasks \
  --export-image-task-ids "$EXPORT_TASK_ID"
```

When complete, the VHD will appear under:
```
s3://ec2-export-bucket-$SUFFIX-source/exports/
```

---

## 6) Create Azure Storage (Unique) & Container (**target**)

```bash
# Storage account name: 3–24 lowercase alphanumeric, globally unique
# (No hyphens allowed, so we append 'tgt' to indicate target.)
SA_NAME="migratevhdstore${SUFFIX}tgt"

# Create storage account in your configured TARGET location and RG
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$TGT_RG" \
  --location "$TGT_LOCATION" \
  --sku Standard_LRS

# Create a container to hold VHDs
az storage container create \
  --account-name "$SA_NAME" \
  --name vhds \
  --auth-mode login
```

```bash
# Generate SAS for ADD/CREATE/WRITE/LIST (valid ~4 hours)
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

## 7) Copy the VHD From S3 → Azure Blob (AzCopy) (**source ➜ target**)

```bash
# Replace with your actual exported object name from S3
SRC_S3_URL="https://s3.amazonaws.com/ec2-export-bucket-$SUFFIX-source/exports/myexport.vhd"

# Destination blob URL with SAS
DST_BLOB_URL="https://${SA_NAME}.blob.core.windows.net/vhds/imported-${SUFFIX}-target.vhd?${SAS}"

# Cross-cloud copy (no local disk usage)
azcopy copy "$SRC_S3_URL" "$DST_BLOB_URL" --recursive=false
```

> If direct S3 access is blocked, download locally then use `az storage blob upload` to the container.

---

## 8) Create a Managed Disk From the Imported VHD (**target**)

```bash
# Build a managed OS disk in Azure from the uploaded VHD (Linux)
az disk create \
  --resource-group "$TGT_RG" \
  --name "aws-imported-disk-${SUFFIX}-target" \
  --source "https://${SA_NAME}.blob.core.windows.net/vhds/imported-${SUFFIX}-target.vhd" \
  --os-type Linux
```

---

## 9) Create the Migrated VM in Azure (Password Auth) (**target**)

```bash
# Prompt securely for the admin password (lab uses password auth, not SSH keys)
read -s -p "Enter a secure password for the migrated VM admin user: " ADMIN_PASSWORD && echo

# Create the VM by attaching the imported OS disk; place it into the prepared TARGET VNet/Subnet/NSG
az vm create \
  --resource-group "$TGT_RG" \
  --name "aws-migrated-vm-${SUFFIX}-target" \
  --attach-os-disk "aws-imported-disk-${SUFFIX}-target" \
  --os-type Linux \
  --size Standard_B1s \
  --admin-username azureuser \
  --admin-password "$ADMIN_PASSWORD" \
  --authentication-type password \
  --vnet-name "$TGT_VNET" \
  --subnet "$TGT_SUBNET" \
  --nsg "$TGT_NSG"
```

> If your NSG is associated at the **subnet**, attaching `--nsg` at VM create may be ignored. The rules added by `lab3-env.sh` handle inbound **80/443/22**.

---

## 10) Validate the Migrated VM (SSH + Web) (**target**)

```bash
# Confirm environment health
./lab3-env.sh status

# Get the VM public IP
PUBLIC_IP=$(az vm show -d \
  --resource-group "$TGT_RG" \
  --name "aws-migrated-vm-${SUFFIX}-target" \
  --query publicIps -o tsv)
echo "Migrated VM Public IP: $PUBLIC_IP"

# SSH: expect the host to respond and print its hostname
ssh -o StrictHostKeyChecking=no azureuser@"$PUBLIC_IP" hostname
```

```bash
# HTTP validation (Apache)
curl -I "http://$PUBLIC_IP"
# Optional HTTPS if configured on the VM:
curl -Ik "https://$PUBLIC_IP"
```

> For a browser test, open: `http://$PUBLIC_IP` (and `https://$PUBLIC_IP` if enabled).

---

## 11) Cleanup (Optional)

```bash
# Remove Azure TARGET landing zone resources created by the lab
./lab3-env.sh cleanup

# Delete the storage account used for the imported VHD
az storage account delete \
  --name "$SA_NAME" \
  --resource-group "$TGT_RG" \
  --yes \
  --no-wait
```

> In AWS (source), optionally delete the S3 export bucket and the AMI once you’re done.

---

## 📘 Notes
- **Export eligibility:** Some Marketplace AMIs are not exportable. Use your own AMI.  
- **Security:** Prefer locking SSH to your `/32` (`SSH_SOURCE=auto ./lab3-env.sh init`). You can disable auto web rules via `CREATE_WEB_RULES=false` and add your own restricted source prefixes.  
- **Production path:** For ongoing migrations, prefer **Azure Migrate: Server Migration** (agentless replication, test failover, orchestrated cutover).  
- **Costs:** Storage accounts, managed disks, and VMs incur charges while present.

✅ **End of Lab** — You exported an AWS EC2 VM (**-source**), imported its VHD into Azure, built a managed disk and VM (**-target**), opened NSG for **SSH + HTTP/HTTPS** (via env script), and validated access.exports `RG`, `LOCATION`, `VNET`, `SUBNET`, `NSG_NAME`, etc.).  
> **NSG Web Rules:** `lab3-env.sh` now adds **HTTP (80)** and **HTTPS (443)** rules automatically when `CREATE_WEB_RULES=true` (default).

---

## 🎯 Objectives
- Export an **AWS EC2** image (AMI) as a **VHD** into **S3**.  
- Copy that **VHD** into **Azure Blob Storage** (using SAS + AzCopy).  
- Create a **Managed Disk** and **VM** in **Azure** from the imported VHD.  
- Validate via **SSH** and **HTTP/HTTPS** (Apache).

---

## ✅ Prerequisites
- **AWS CLI** authenticated (permissions for **AMI/S3/export**).  
- **Azure CLI** authenticated (subscription access).  
- **AzCopy** available locally.  
- Network egress to **SSH (22)** and **HTTP/HTTPS** from your client IP.  
- AWS **`vmimport`** service role exists and is trusted by `vmie.amazonaws.com` (VM Import/Export).  
- EC2 instance is a Linux web server (Apache) you own and can export.

---

## 1) Login & Initialize the Azure Environment

Run these from the `session7` folder. The script prepares the **Azure landing zone** and writes `.lab.env`:

```bash
chmod +x lab3-env.sh

# Login (no-op if already logged in) + register providers
./lab3-env.sh login

# Provision/ensure RG, VNet, Subnet, NSG (idempotent). Adds SSH(22)+HTTP(80)+HTTPS(443) rules by default.
./lab3-env.sh init
# optionally lock SSH to your /32 and/or disable web rules:
# SSH_SOURCE=auto CREATE_WEB_RULES=false ./lab3-env.sh init

# Quick health check (non-zero exit if missing)
./lab3-env.sh status

# Load variables exported by the env script
source .lab.env
echo "RG=$RG LOCATION=$LOCATION VNET=$VNET SUBNET=$SUBNET NSG_NAME=$NSG_NAME"
```

---

## 2) Prepare Unique Names & Identify the AWS Instance

```bash
# Unique suffix to avoid collisions
SUFFIX=$RANDOM

# Replace with your real EC2 instance ID (the Apache web server to migrate)
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
# OPTIONAL: capture the AMI ID (or inspect create-image output directly)
AMI_ID=$(aws ec2 describe-images --owners self \
  --filters "Name=name,Values=WebServerExport-$SUFFIX" \
  --query "Images[0].ImageId" -o tsv)
echo "Using AMI: $AMI_ID"
```

> ⚠️ Some Marketplace AMIs are **not exportable**. Use an AMI you own and is eligible for export.

---

## 4) Create an S3 Bucket for Export

```bash
# Global-unique bucket for the exported VHD
aws s3 mb "s3://ec2-export-bucket-$SUFFIX"
```

> Ensure the **`vmimport`** role exists and is configured per AWS documentation.

---

## 5) Export the AMI to VHD in S3

```bash
# Export the AMI to VHD placed under the S3 prefix
EXPORT_TASK_ID=$(aws ec2 export-image \
  --image-id "$AMI_ID" \
  --disk-image-format VHD \
  --s3-export-location S3Bucket="ec2-export-bucket-$SUFFIX",S3Prefix="exports/" \
  --query "ExportImageTaskId" -o tsv)
echo "Export task: $EXPORT_TASK_ID"
```

```bash
# Poll export status until Status becomes 'completed'
aws ec2 describe-export-image-tasks \
  --export-image-task-ids "$EXPORT_TASK_ID"
```

When complete, the VHD will appear under:
```
s3://ec2-export-bucket-$SUFFIX/exports/
```

---

## 6) Create Azure Storage (Unique) & Container

```bash
# Storage account name: 3–24 lowercase alphanumeric, globally unique
SA_NAME="migratevhdstore${SUFFIX}"

# Create storage account in your configured LOCATION and RG
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS

# Create a container to hold VHDs
az storage container create \
  --account-name "$SA_NAME" \
  --name vhds \
  --auth-mode login
```

```bash
# Generate SAS for ADD/CREATE/WRITE/LIST (valid ~4 hours)
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
# Replace with your actual exported object name from S3
SRC_S3_URL="https://s3.amazonaws.com/ec2-export-bucket-$SUFFIX/exports/myexport.vhd"

# Destination blob URL with SAS
DST_BLOB_URL="https://${SA_NAME}.blob.core.windows.net/vhds/imported-${SUFFIX}.vhd?${SAS}"

# Cross-cloud copy (no local disk usage)
azcopy copy "$SRC_S3_URL" "$DST_BLOB_URL" --recursive=false
```

> If direct S3 access is blocked, download locally then use `az storage blob upload` to the container.

---

## 8) Create a Managed Disk From the Imported VHD

```bash
# Build a managed OS disk in Azure from the uploaded VHD (Linux)
az disk create \
  --resource-group "$RG" \
  --name "aws-imported-disk-${SUFFIX}" \
  --source "https://${SA_NAME}.blob.core.windows.net/vhds/imported-${SUFFIX}.vhd" \
  --os-type Linux
```

---

## 9) Create the Migrated VM in Azure (Password Auth)

```bash
# Prompt securely for the admin password (lab uses password auth, not SSH keys)
read -s -p "Enter a secure password for the migrated VM admin user: " ADMIN_PASSWORD && echo

# Create the VM by attaching the imported OS disk; place it into the prepared VNet/Subnet/NSG
az vm create \
  --resource-group "$RG" \
  --name "aws-migrated-vm-${SUFFIX}" \
  --attach-os-disk "aws-imported-disk-${SUFFIX}" \
  --os-type Linux \
  --size Standard_B1s \
  --admin-username azureuser \
  --admin-password "$ADMIN_PASSWORD" \
  --authentication-type password \
  --vnet-name "$VNET" \
  --subnet "$SUBNET" \
  --nsg "$NSG_NAME"
```

> If your NSG is associated at the **subnet**, attaching `--nsg` at VM create may be ignored. The rules added by `lab3-env.sh` handle inbound **80/443/22**.

---

## 10) Validate the Migrated VM (SSH + Web)

```bash
# Confirm environment health
./lab3-env.sh status

# Get the VM public IP
PUBLIC_IP=$(az vm show -d \
  --resource-group "$RG" \
  --name "aws-migrated-vm-${SUFFIX}" \
  --query publicIps -o tsv)
echo "Migrated VM Public IP: $PUBLIC_IP"

# SSH: expect the host to respond and print its hostname
ssh -o StrictHostKeyChecking=no azureuser@"$PUBLIC_IP" hostname
```

```bash
# HTTP validation (Apache)
curl -I "http://$PUBLIC_IP"
# Optional HTTPS if configured on the VM:
curl -Ik "https://$PUBLIC_IP"
```

> For a browser test, open: `http://$PUBLIC_IP` (and `https://$PUBLIC_IP` if enabled).

---

## 11) Cleanup (Optional)

```bash
# Remove Azure landing zone resources created by the lab
./lab3-env.sh cleanup

# Delete the storage account used for the imported VHD
az storage account delete \
  --name "$SA_NAME" \
  --resource-group "$RG" \
  --yes \
  --no-wait
```

> In AWS, you can optionally delete the S3 export bucket and the AMI once you’re done.

---

## 📘 Notes
- **Export eligibility:** Some Marketplace AMIs are not exportable. Use your own AMI.  
- **Security:** Prefer locking SSH to your `/32` (`SSH_SOURCE=auto ./lab3-env.sh init`). You can disable auto web rules via `CREATE_WEB_RULES=false` and add your own restricted source prefixes.  
- **Production path:** For ongoing migrations, prefer **Azure Migrate: Server Migration** (agentless replication, test failover, orchestrated cutover).  
- **Costs:** Storage accounts, managed disks, and VMs incur charges while present.

✅ **End of Lab** — You exported an AWS EC2 VM, imported its VHD into Azure, built a managed disk and VM, **opened NSG for SSH + HTTP/HTTPS (via env script)**, and validated access.