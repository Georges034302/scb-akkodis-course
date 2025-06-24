# 🧪 Hands-On Lab: Immutable Storage for Audit Compliance

## 🏷️ Lab Title

Configure Immutable Blob Storage with Protected Append Writes and Legal Hold Using Azure CLI and Portal

---

## 🌟 Lab Objective

Implement enterprise-grade immutable storage in Azure Blob to retain critical logs for 7 years in WORM (Write Once Read Many) mode, using CLI and Portal.

---

## ✅ Lab Scenario

You are tasked with ensuring security audit logs are immutable and verifiable for a 7-year compliance period.

Design includes:

- Storage Account
- Container with time-based WORM policy (2555 days)
- Protected append writes
- Legal hold (optional)
- Upload with fallback mechanism (AzCopy ➡️ CLI)

---

## 🧠 Pre-Requisites

- Azure CLI installed and authenticated (`az login`)
- Run `az upgrade` to ensure latest version
- Install required CLI extension:
  ```bash
  az extension add --name storage-preview
  ```
- Install AzCopy CLI:
  ```bash
  wget https://aka.ms/downloadazcopy-v10-linux
  tar -xvf downloadazcopy-v10-linux
  sudo cp ./azcopy_linux_amd64_*/azcopy /usr/local/bin/
  azcopy --version
  ```
- Contributor role on your Azure subscription
- Storage Blob Data Contributor role on the storage account
- GitHub Codespace or local shell with `azcopy` (optional)

---

## 🛠️ Step-by-Step Instructions

### 🔹 Step 1: Login to Azure

```bash
az login --use-device-code
```

### 🔹 Step 2: Create Resource Group

```bash
az group create \
  --name rg-immutable-demo \
  --location australiaeast
```

### 🔹 Step 3: Create Storage Account

```bash
STORAGE_NAME="auditstore$(date +%s)"

az storage account create \
  --name "$STORAGE_NAME" \
  --resource-group rg-immutable-demo \
  --location australiaeast \
  --sku Standard_GRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2
```

### 🔹 Step 4: Create Container

```bash
az storage container create \
  --name audit-logs \
  --account-name "$STORAGE_NAME" \
  --auth-mode login
```

### 🔹 Step 5: Assign Required Role in Azure Portal

Before performing blob-level operations (e.g., uploading, setting policies), ensure that your logged-in identity has the **Storage Blob Data Contributor** role assigned on the storage account.

**To do this via the Azure Portal:**

1. Go to the **Storage Account** you just created.
2. In the left menu, select **Access Control (IAM)**.
3. Click **+ Add** → **Add role assignment**.
4. Role: `Storage Blob Data Contributor`
5. Assign access to: `User, group, or service principal`
6. Select your username.
7. Click **Save**.

⏳ Wait 1–2 minutes for the role assignment to take effect.

---

### 🔹 Step 6: Set Immutable Policy (Unlocked Only — DO NOT LOCK IN TEST)

> ⚠️ **Do not lock in test/demo environments. Locked policies are permanent and prevent deletion.**

```bash
az storage container immutability-policy create \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --period 2555 \
  --allow-protected-append-writes true
```

### 🔹 Step 7: Upload Log File with AzCopy and Fallback

```bash
FILENAME="log-$(date +%s)-entry.txt"
echo "SECURITY LOG: $(date)" > "$FILENAME"

SAS_EXPIRY=$(date -u -d "1 hour" '+%Y-%m-%dT%H:%MZ')
SAS_TOKEN=$(az storage container generate-sas \
  --name audit-logs \
  --account-name "$STORAGE_NAME" \
  --permissions acwl \
  --expiry "$SAS_EXPIRY" \
  --auth-mode login \
  --as-user \
  -o tsv)

SAS_URL="https://$STORAGE_NAME.blob.core.windows.net/audit-logs/$FILENAME?$SAS_TOKEN"

echo "Uploading file using AzCopy..."
azcopy copy "$FILENAME" "$SAS_URL" --overwrite=false --log-level=INFO || {
  echo "AzCopy failed. Trying CLI fallback..."
  az storage blob upload \
    --account-name "$STORAGE_NAME" \
    --container-name audit-logs \
    --name "$FILENAME" \
    --file "$FILENAME" \
    --auth-mode login
}
```

---

### 🔹 Step 8: Apply Legal Hold (Optional)

```bash
az storage container legal-hold set \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --tags APRACPS234 SOX2024Audit
```

---

## ✅ Post-Deployment Validation

| Resource         | Configuration                                  |
| ---------------- | ---------------------------------------------- |
| Storage Account  | Geo-redundant (GRS), TLS 1.2+, StorageV2       |
| Blob Container   | Named `audit-logs`, private, with WORM policy  |
| Immutable Policy | **Unlocked**, 2555 days, append-only writes    |
| Legal Hold       | Applied with tags (e.g., `APRA-CPS234`)        |
| Blob Uploaded    | File uploaded successfully using AzCopy or CLI |

### ✅ Immutable Storage Outcome Review

| ✅ Criterion                          | Status      | Notes                                    |
| ------------------------------------ | ----------- | ---------------------------------------- |
| **Storage Account**                  | ✅ Created   | GRS + TLS 1.2                            |
| **Container**                        | ✅ Created   | `audit-logs`                             |
| **WORM Immutability Policy (7 yrs)** | ✅ Unlocked  | Can be deleted for cleanup               |
| **Protected Append Writes**          | ✅ Enabled   | Log files can only be added, not altered |
| **Legal Hold Tags**                  | ✅ Applied   | (`APRA-CPS234`, `SOX2024Audit`)          |
| **Blob Upload with Fallback**        | ✅ Robust    | AzCopy → CLI fallback logic              |
| **Delete Operation (Unlocked)**      | ✅ Allowed   | Can delete blob or container             |
| **Final Message**                    | ✅ Completed | End-to-end workflow succeeded            |

---

## 🔍 Test Scenarios

### ✅ Immutability Policy State

```bash
az storage container immutability-policy show \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs
```

### ✅ Upload Another Log File

```bash
NEWFILE="log-$(date +%s)-append.txt"
echo "SECURITY APPEND: $(date)" > "$NEWFILE"

az storage blob upload \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --name "$NEWFILE" \
  --file "$NEWFILE" \
  --auth-mode login
```

### ❌ Attempt to Overwrite Blob (Should Fail)

```bash
echo "TAMPERED LOG" > "$FILENAME"
az storage blob upload \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --name "$FILENAME" \
  --file "$FILENAME" \
  --overwrite true \
  --auth-mode login
```

### ✅ Legal Hold View

```bash
az storage container legal-hold show \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs
```

### ❌ Attempt to Delete Blob (Should Fail Due to Legal Hold)

```bash
az storage blob delete \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --name "$FILENAME" \
  --auth-mode login
```

### ✅ Remove Legal Hold

```bash
az storage container legal-hold clear \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --tags APRACPS234 SOX2024Audit
```

### ✅ Delete Blob (After Legal Hold Removed)

```bash
az storage blob delete \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --name "$FILENAME" \
  --auth-mode login
```

### ✅ Cleanup (Remove Resource Group)

```bash
az group delete --name "$RG_NAME" --yes --no-wait
```

---

