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

---

## 🛠️ Step-by-Step Instructions

### 🔹 Step 1: Login to Azure

```bash
az login --use-device-code
```

✨ *This logs you into Azure using a device code, ideal for secure terminal sessions.*

### 🔹 Step 2: Create Resource Group

```bash
az group create \
  --name rg-immutable-demo \
  --location australiaeast
```

✨ *Creates a logical container for related Azure resources.*

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

✨ *Creates a geo-redundant storage account with enhanced security.*

### 🔹 Step 4: Create Container

```bash
az storage container create \
  --name audit-logs \
  --account-name "$STORAGE_NAME" \
  --auth-mode login
```

✨ *Creates a private container named **``** inside the storage account.*

### 🔹 Step 5: Assign Required Role in Azure Portal

Before performing blob-level operations (e.g., uploading, setting policies), ensure that your logged-in identity has the **Storage Blob Data Contributor** role assigned on the storage account.

To do this via the Azure Portal:

1. Go to the **Storage Account** you just created.
2. In the left menu, select **Access Control (IAM)**.
3. Click **+ Add → Add role assignment**.
4. Under **Role**, select: `Storage Blob Data Contributor` and `Storage Blob Data Owner`
5. Under **Assign access to**, select: `User, group, or service principal`
6. Click **+ Select members** and choose your username from the directory.
7. Click **Next**, review the assignment, and then click **Save**.

⏳ *Wait 1–2 minutes for the role assignment to propagate.*

---

### 🔹 Step 6: Set Unlocked WORM Policy (7 Years)

```bash
az storage container immutability-policy create \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --period 2555 \
  --allow-protected-append-writes true
```

✨ *Enables a 7-year Write Once Read Many policy, allowing appends only. The policy remains modifiable.*

### 🔹 Step 7: Upload Log File with AzCopy and CLI Fallback

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

✨ *Uploads a new log file using AzCopy. If that fails, it falls back to Azure CLI.*

### 🔹 Step 8: Apply Legal Hold (Optional)

```bash
az storage container legal-hold set \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --tags APRACPS234 SOX2024Audit
```

✨ *Adds legal tags that prevent blob/container deletion until cleared.*

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
| **WORM Immutability Policy (7 yrs)** | ✅ Unlocked  | Can be modified or removed               |
| **Protected Append Writes**          | ✅ Enabled   | Log files can only be added, not altered |
| **Legal Hold Tags**                  | ✅ Applied   | (`APRA-CPS234`, `SOX2024Audit`)          |
| **Blob Upload with Fallback**        | ✅ Robust    | AzCopy → CLI fallback logic              |
| **Delete Operation (Unlocked)**      | ✅ Allowed   | After legal hold is cleared              |
| **Final Message**                    | ✅ Completed | End-to-end workflow succeeded            |

### 🔍 Check Policy State

```bash
az storage container immutability-policy show \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME"
```

✨ *Verifies that the WORM policy is active and still unlocked.*

### 📄 Upload Another Log

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

✨ *Adds a new log file using append semantics allowed by the WORM policy.*

### ⛔ Try to Overwrite Existing Log (Should Fail)

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

❌ *Fails due to append-only protection in WORM.*

### 📃 View Legal Hold

```bash
az storage container legal-hold show \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs
```

✨ *Confirms the current legal hold tags on the container.*

### ⛔ Attempt to Delete Blob (Should Fail)

```bash
az storage blob delete \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --name "$FILENAME" \
  --auth-mode login
```

❌ *Fails because legal hold prevents deletion even if WORM is unlocked.*

---

### ✅ Delete WORM (Immutability) Policy via Azure Portal

- Go to [https://portal.azure.com](https://portal.azure.com) and sign in.
- In the top search bar, enter the name of your Storage Account and select it.
- In the left menu, click **Containers** under **Data Storage**.
- Click on the container that has the WORM policy (e.g., `audit-logs`).
- At the top of the container view, click **Immutability policies**.
  - ⚠️ If this is not visible, the container might not have an immutability policy enabled.
- If the policy is **unlocked**, select it and click **Delete**, then confirm.
- If the policy is **locked**, you **cannot delete it** until the retention period expires.


✨ *Removes legal hold so deletion can proceed.*

---
### ✅ Delete a specific blob 

```bash
az storage blob delete \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --name "$FILENAME" \
  --auth-mode login
```

### ✅ Delete Storage Account
```bash
az storage account delete \
  --name "$STORAGE_NAME" \
  --resource-group "$RG_NAME" \
  --yes
```

✨ *The blob and storage account are deleted safely.*

### ❌ Delete Resource Group

```bash
RG_NAME="rg-immutable-demo"
az group delete --name "$RG_NAME" --yes --no-wait
```

✨ *Cleans up all resources created during the lab.*

---

🚀 **Lab Complete: You successfully configured and validated unlocked immutable storage in Azure!**

