# Lab 3‑A: AWS → Azure Migration (EC2 Export ➜ Azure Import via VHD)

This lab exports an **AWS EC2** Linux web server (Apache HTTP Server) to a **VHD**, copies it to **Azure Blob Storage**, converts it to a **Page Blob**, creates a **Managed Disk**, and finally an **Azure VM**.  
We follow the naming convention: AWS **source** artifacts end with **`-source`**; Azure **target** resources end with **`-target`**.

<img width="1536" height="1024" alt="AWS-Azure--VHD-migration" src="https://github.com/user-attachments/assets/e0c666fd-15b8-4f9d-b6c6-e75297b1cdaa" />
> Uses **password auth** (not SSH keys) and **`SUFFIX=$RANDOM`** to guarantee unique names.  
> The Azure side uses **`lab3-env.sh`** to prepare the target landing zone (**TGT_RG/TGT_VNET/TGT_SUBNET/TGT_NSG**) and to write `.lab.env` for sourcing.  
> **NSG Web Rules:** `lab3-env.sh` (by default) adds inbound **SSH 22**, **HTTP 80**, and **HTTPS 443** via `CREATE_WEB_RULES=true`.

---

## 🎯 Objectives
- Export an **EC2** AMI to **VHD** in **S3** (**-source** naming).  
- Copy that **VHD** to **Azure Blob Storage** (server‑side copy).  
- Convert to **Page Blob**, create a **Managed Disk** and **VM** (**-target** naming).  
- Validate via **SSH** and **HTTP/HTTPS**.

---

## ✅ Prerequisites
- **AWS CLI** authenticated (AMI/S3/export permissions).
- **Azure CLI** authenticated (subscription access).
- **You ran** `lab3-env.sh` to prepare target networking/NSG **and** wrote `.lab.env`.
- Network egress to **22/80/443** from your client IP.
- AWS **`vmimport`** role set up (script provided below).

---

## 1) Prepare Azure TARGET landing zone

From your repo root (e.g., `session7`):

```bash
chmod +x lab3-env.sh

# Login (and register providers)
./lab3-env.sh login

# Create target RG/VNet/Subnet/NSG (idempotent). Adds SSH/HTTP/HTTPS by default.
./lab3-env.sh init

# Quick health check
./lab3-env.sh status

# Load hand-off variables for later steps
source .lab.env
echo "TGT_RG=$TGT_RG TGT_LOCATION=$TGT_LOCATION TGT_VNET=$TGT_VNET TGT_SUBNET=$TGT_SUBNET TGT_NSG=$TGT_NSG"
```

---

## 2) Prepare unique suffix & choose the EC2 instance (**source**)

```bash
# Unique suffix to avoid global name collisions
export SUFFIX=$RANDOM

# Pick your EC2 instance (Apache web server) to migrate (replace if you already know it)
EC2_ID=$(aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output text | awk '{print $1}')
echo "EC2_ID=$EC2_ID"
```

> Tip: If multiple instances are returned, set `EC2_ID="i-xxxxxxxxxxxx"` explicitly.

---

## 3) Create an AMI from the EC2 (no reboot) (**source**)

```bash
aws ec2 create-image \
  --instance-id "$EC2_ID" \
  --name "WebServerExport-$SUFFIX-source" \
  --no-reboot
```

```bash
# Capture the AMI ID
AMI_ID=$(aws ec2 describe-images --owners self \
  --filters "Name=name,Values=WebServerExport-$SUFFIX-source" \
  --query "Images[0].ImageId" \
  --output text)
echo "AMI_ID=$AMI_ID"
```

> ⚠️ Some Marketplace AMIs are **not exportable**. Use an AMI you own and that is eligible for export.

---

## 4) Create S3 export bucket (**source**)

```bash
export BUCKET="ec2-export-bucket-$SUFFIX-source"
aws s3 mb "s3://$BUCKET"
```

---

## 5) Configure AWS VM Import/Export permissions (**source**)

Use the helper to create/update the **`vmimport`** role and apply the bucket policy (argument = `SUFFIX`).

```bash
chmod +x setup_vmimport.sh
./setup_vmimport.sh "$SUFFIX"
```

---

## 6) Export the AMI to VHD in S3 (**source**)

```bash
EXPORT_TASK_ID=$(aws ec2 export-image \
  --image-id "$AMI_ID" \
  --disk-image-format VHD \
  --s3-export-location S3Bucket="$BUCKET",S3Prefix="exports/" \
  --query "ExportImageTaskId" \
  --output text)
echo "Export task: $EXPORT_TASK_ID"
```

```bash
# Watch until Status = completed
aws ec2 describe-export-image-tasks \
  --export-image-task-ids "$EXPORT_TASK_ID" \
  --query "ExportImageTasks[].{ID:ExportImageTaskId,Status:Status,Progress:Progress,Message:StatusMessage}" \
  --output table
```

When complete, the VHD will appear under:
```
s3://ec2-export-bucket-$SUFFIX-source/exports/
```

Get the exported object key and generate a **presigned URL**:

```bash
SRC_KEY=$(aws s3api list-objects-v2 \
  --bucket "$BUCKET" \
  --prefix "exports/" \
  --query "reverse(sort_by(Contents[?ends_with(Key, '.vhd')], &LastModified))[0].Key" \
  --output text)
echo "SRC_KEY=$SRC_KEY"

# 1-hour presigned URL for that exact VHD object
SRC_S3_URL=$(aws s3 presign "s3://$BUCKET/$SRC_KEY" --expires-in 3600)
echo "SRC_S3_URL=$SRC_S3_URL"
```

---

## 7) Create Azure Storage (target) & container (**target**)

```bash
# Storage account name: 3–24 lowercase alphanumeric, globally unique
export SA_NAME="migratevhdstore${SUFFIX}tgt"

# Create the storage account in your target RG/location
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$TGT_RG" \
  --location "$TGT_LOCATION" \
  --sku Standard_LRS

# Create a container for VHDs
az storage container create \
  --account-name "$SA_NAME" \
  --name vhds \
  --auth-mode login
```

### Assign yourself **Storage Blob Data Contributor** (Portal)
1. Azure Portal → Storage accounts → **`$SA_NAME`**  
2. **Access control (IAM)** → **+ Add** → **Add role assignment**  
3. **Role**: **Storage Blob Data Contributor**  
4. **Assign access to**: *User, group, or service principal* → pick your signed‑in user  
5. **Save** (RBAC may take a minute to propagate)

---

## 8) Server‑side copy: S3 ➜ Azure (target)

### Pull VHD from the **presigned S3 URL** into a **block blob** in Azure first.

```bash
export CONTAINER="vhds"
export DST_BLOCK_BLOB="imported-${SUFFIX}.vhd"   # block blob first

az storage blob copy start \
  --account-name "$SA_NAME" \
  --destination-container "$CONTAINER" \
  --destination-blob "$DST_BLOCK_BLOB" \
  --source-uri "$SRC_S3_URL" \
  --auth-mode login
```

#### Monitor until completed:
```bash
az storage blob show \
  --account-name "$SA_NAME" \
  -c "$CONTAINER" -n "$DST_BLOCK_BLOB" \
  --auth-mode login \
  --query "properties.copy | {Status:status, Progress:progress, CompletionTime:completionTime}" \
  -o table
```

> If you see `AuthorizationPermissionMismatch`, wait a minute for RBAC or re‑assign the role above.

---

## 9) Convert **Block Blob** ➜ **Page Blob** (**required for Managed Disk**)

> Managed disks can only be created from **Page Blobs** and sizes must be **512‑byte aligned**.

```bash
# Choose final page blob name
export DST_PAGE_BLOB="imported-${SUFFIX}-page.vhd"

# 1) Get size of the block blob and round up to 512-byte boundary
SIZE=$(az storage blob show \
  --account-name "$SA_NAME" -c "$CONTAINER" -n "$DST_BLOCK_BLOB" \
  --auth-mode login --query "properties.contentLength" --output text)
PAGE_SIZE=$(( ((SIZE + 511) / 512) * 512 ))
echo "Block=$SIZE  PageAligned=$PAGE_SIZE"

# 2) Create an empty Page Blob of that size
az storage blob create \
  --account-name "$SA_NAME" -c "$CONTAINER" -n "$DST_PAGE_BLOB" \
  --type page --size "$PAGE_SIZE" --auth-mode login

# 3) Make a short SAS to read the source block blob
EXPIRY=$(date -u -d "+2 hours" '+%Y-%m-%dT%H:%MZ')
SRC_SAS=$(az storage blob generate-sas \
  --account-name "$SA_NAME" -c "$CONTAINER" -n "$DST_BLOCK_BLOB" \
  --permissions r --expiry "$EXPIRY" --https-only \
  --auth-mode login --output tsv)
SRC_URL="https://${SA_NAME}.blob.core.windows.net/${CONTAINER}/${DST_BLOCK_BLOB}?${SRC_SAS}"

# 4) Copy into the Page Blob (server-side)
az storage blob copy start \
  --account-name "$SA_NAME" \
  --destination-container "$CONTAINER" \
  --destination-blob "$DST_PAGE_BLOB" \
  --source-uri "$SRC_URL" \
  --auth-mode login

# 5) Watch until Status=success
az storage blob show \
  --account-name "$SA_NAME" -c "$CONTAINER" -n "$DST_PAGE_BLOB" \
  --auth-mode login --query "properties.copy" -o table
```

---

## 10) Create a Managed Disk from the Page Blob (**target**)

```bash
az disk create \
  --resource-group "$TGT_RG" \
  --location "$TGT_LOCATION" \
  --name "aws-imported-disk-${SUFFIX}-target" \
  --source "https://${SA_NAME}.blob.core.windows.net/${CONTAINER}/${DST_PAGE_BLOB}" \
  --os-type Linux
```

---

## 11) Create the migrated VM (**target**, password auth)

```bash
read -s -p "Enter a secure password for the migrated VM admin user: " ADMIN_PASSWORD && echo

az vm create \
  --resource-group "$TGT_RG" \
  --location "$TGT_LOCATION" \
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

> If your NSG is associated at the **subnet**, the VM‑level `--nsg` is ignored. `lab3-env.sh` already attached NSG to the subnet with 22/80/443 allowed (by default).

---

## 12) Validate (SSH + Web)

```bash
# Environment health
./lab3-env.sh status

# Public IP
PUBLIC_IP=$(az vm show -d \
  --resource-group "$TGT_RG" \
  --name "aws-migrated-vm-${SUFFIX}-target" \
  --query publicIps --output text)
echo "Public IP: $PUBLIC_IP"

# SSH
ssh -o StrictHostKeyChecking=no azureuser@"$PUBLIC_IP" hostname

# Web (Apache)
curl -I "http://$PUBLIC_IP"
# Optional:
curl -Ik "https://$PUBLIC_IP"
```

Open your browser to `http://$PUBLIC_IP` (and `https://$PUBLIC_IP` if configured).

---

## 13) Cleanup (optional)

```bash
# Remove Azure target landing zone resources
./lab3-env.sh cleanup

# Delete the storage account that held the VHD
az storage account delete \
  --name "$SA_NAME" \
  --resource-group "$TGT_RG" \
  --yes --no-wait
```

In AWS, optionally delete the S3 export bucket and the AMI.

---

## 🧰 Troubleshooting
- **`InvalidApiVersionParameter` when creating storage account:** upgrade Azure CLI (`az upgrade`) or create via ARM with `--api-version 2024-03-01`.
- **`AuthorizationPermissionMismatch` on blob ops:** ensure your signed‑in user has **Storage Blob Data Contributor** on the storage account.
- **Managed disk creation fails:** confirm the source is a **Page Blob** and size is 512‑byte aligned.
- **Presigned URL expired during copy:** generate a fresh presigned URL and restart the copy.

---

## ✅ Summary
You exported an AWS EC2 VM (**-source**), imported its VHD to Azure, converted it to a **Page Blob**, created a **Managed Disk**, provisioned an Azure VM (**-target**), and validated access over **SSH + HTTP/HTTPS**.