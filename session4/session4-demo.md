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

---

## 🧠 Pre-Requisites

- Azure CLI installed and authenticated (`az login`)
- Contributor role on your Azure subscription
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

### 🔹 Step 5: Set Immutable Policy (Unlocked)

```bash
az storage container immutability-policy set \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --period 2555 \
  --allow-protected-append-writes true \
  --auth-mode login
```

### 🔹 Step 6: Upload Sample Log File

```bash
echo "SECURITY LOG: $(date)" > log1.txt
```

```bash
az storage container generate-sas \
  --name audit-logs \
  --account-name "$STORAGE_NAME" \
  --permissions acw \
  --expiry $(date -u -d "1 hour" '+%Y-%m-%dT%H:%MZ') \
  -o tsv
```

```bash
azcopy copy "log1.txt" "https://$STORAGE_NAME.blob.core.windows.net/audit-logs/log1.txt?<SAS_TOKEN>" --overwrite=false
```

### 🔹 Step 7: Lock Immutability Policy

```bash
az storage container immutability-policy lock \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --if-match "*"
```

### 🔹 Step 8: Apply Legal Hold (Optional)

```bash
az storage container legal-hold set \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --tags "APRA-CPS234" "SOX-2024-Audit"
```

---

## ✅ Post-Deployment Validation

### ✅ What Should Exist Post-Script

| Resource         | Configuration                                       |
| ---------------- | --------------------------------------------------- |
| Storage Account  | Geo-redundant (GRS), TLS 1.2+, StorageV2            |
| Blob Container   | Named `audit-logs`, private, with WORM policy       |
| Immutable Policy | Locked, 2555 days, append-only writes enabled       |
| Legal Hold       | Applied with tags (e.g., `APRA-CPS234`)             |
| Blob Uploaded    | `log1.txt` successfully uploaded using SAS & AzCopy |

---

### 🔍 Post-Script Test Scenarios

#### 🔹 1. Check Immutability Lock Status

```bash
az storage container show \
  --account-name "$STORAGE_NAME" \
  --name "$CONTAINER_NAME" \
  --query "immutabilityPolicy"
```

**Expected Output:**

```json
{
  "immutabilityPeriodSinceCreationInDays": 2555,
  "allowProtectedAppendWrites": true,
  "state": "Locked"
}
```

#### 🔹 2. Attempt to Delete the Blob

```bash
az storage blob delete \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME" \
  --name log1.txt \
  --auth-mode login
```

**Expected Behavior:** ❌ Operation fails\
**Error Message:**

```
This operation is not permitted as the blob is under a locked immutability policy.
```

#### 🔹 3. Try Overwriting the Blob

```bash
echo "MODIFIED CONTENT" > log1.txt
azcopy copy "log1.txt" \
  "https://$STORAGE_NAME.blob.core.windows.net/$CONTAINER_NAME/log1.txt?$SAS_TOKEN" \
  --overwrite=true
```

**Expected Behavior:** ❌ Upload fails — Blob cannot be overwritten under WORM lock

#### 🔹 4. Test Legal Hold View

```bash
az storage container legal-hold show \
  --account-name "$STORAGE_NAME" \
  --container-name "$CONTAINER_NAME"
```

**Expected Output:**

```json
{
  "hasLegalHold": true,
  "tags": [
    "APRA-CPS234",
    "SOX-2024-Audit"
  ]
}
```

#### 🧪 5. (Optional) Try Appending New File

```bash
echo "APPENDED LOG ENTRY: $(date)" > log2.txt
azcopy copy "log2.txt" \
  "https://$STORAGE_NAME.blob.core.windows.net/$CONTAINER_NAME/log2.txt?$SAS_TOKEN" \
  --overwrite=false
```

**Expected Behavior:** ✅ Upload succeeds — Append-only behavior is allowed

---

## 🧼 Want Cleanup?

```bash
az group delete --name "$RG_NAME" --yes --no-wait
```

---

