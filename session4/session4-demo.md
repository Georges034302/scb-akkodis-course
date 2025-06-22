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

---

### 🔹 Step 2: Create Resource Group

```bash
az group create \
  --name rg-immutable-demo \
  --location australiaeast
```

---

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

---

### 🔹 Step 4: Create Container

```bash
az storage container create \
  --name audit-logs \
  --account-name "$STORAGE_NAME" \
  --auth-mode login
```

---

### 🔹 Step 5: Set Immutable Policy (Unlocked)

```bash
az storage container immutability-policy set \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --period 2555 \
  --allow-protected-append-writes true \
  --auth-mode login
```

---

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

---

### 🔹 Step 7: Lock Immutability Policy

```bash
az storage container immutability-policy lock \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --if-match "*"
```

---

### 🔹 Step 8: Apply Legal Hold (Optional)

```bash
az storage container legal-hold set \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --tags "APRA-CPS234" "SOX-2024-Audit"
```

---

## ✅ Post-Deployment Validation

### 🔹 Attempt to Delete Blob (Expect Failure)

```bash
az storage blob delete \
  --account-name "$STORAGE_NAME" \
  --container-name audit-logs \
  --name log1.txt \
  --auth-mode login
```

Expected: Failure due to locked WORM policy.

---

### 🔹 Check Immutability Policy

```bash
az storage container show \
  --account-name "$STORAGE_NAME" \
  --name audit-logs \
  --query "immutabilityPolicy"
```

---

## 🌍 Portal Instructions

1. Navigate to the [Azure Portal](https://portal.azure.com) and select **Resource groups** > **+ Create**.

   - Resource group name: `rg-immutable-demo`
   - Region: `Australia East`

2. In the Portal search bar, go to **Storage accounts** > **+ Create**.

   - Name: `auditstoreXXXX`
   - Region: `Australia East`
   - Performance: Standard
   - Redundancy: GRS
   - Advanced: Minimum TLS version: 1.2 or higher
   - Click **Review + Create** > **Create**

3. After deployment, go to the storage account > **Containers** > **+ Container**

   - Name: `audit-logs`
   - Public access level: **Private (no anonymous access)**
   - Click **Create**

4. Select the container > Go to **Access policy** tab

   - Click **+ Add policy**
   - Enable **Time-based retention policy**
   - Enter **Retention period**: `2555` days
   - Check **Allow protected append writes**
   - Leave policy mode as **Unlocked** and click **Add**

5. Once verified, click the **Lock** icon in the Immutability Policy panel to permanently enforce the policy

6. (Optional) Go to **Legal hold** tab > Click **+ Add**

   - Tags: `APRA-CPS234`, `SOX-2024-Audit`
   - Click **Add** to apply legal hold

---

## 📈 Final Validation Summary

| Validation Step               | Method                                 |
| ----------------------------- | -------------------------------------- |
| Container is Immutable        | `az storage container show`            |
| Blob Deletion is Blocked      | `az storage blob delete` fails         |
| Append Writes Allowed         | `azcopy` succeeds                      |
| Legal Hold Visible (Optional) | `az storage container legal-hold show` |

