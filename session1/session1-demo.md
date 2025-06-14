# 🧪 Hands-On Lab: Secure Storage Access Using ARM Template and RFC 1918 IP Strategy

## 🏷️ Lab Title
Deploy a Secure Logging Architecture with Private Endpoint and RFC 1918 IP Strategy Using ARM JSON

---

## 🎯 Lab Objective
Deploy a logging subnet and storage account using RFC 1918 IP address space, and integrate it with a Private Endpoint and Private DNS Zone to enforce internal-only access — following best practice cloud security architecture.

---

## ✅ Lab Scenario
A centralized logging application resides within AppSubnet. This app must write logs to an Azure Storage account, which must not be accessible over the internet.

**Design requires:**
- A custom VNet (10.50.0.0/16)
- A subnet (10.50.1.0/24)
- A Private Endpoint and Private DNS Zone for secure access to the Storage service

---

## 🧰 Pre-Requisites
- Visual Studio Code installed
- Azure CLI installed (`az version`)
- Logged in to Azure CLI (`az login`)
- Active Azure subscription
- Permissions to deploy VNets, Storage, Private Endpoints, and DNS Zones
- A globally unique storage account name (e.g., `logstore001`)
- Internet access or Cloud Shell

---

## 🛠️ Step-by-Step Instructions

### 🔹 Step 1: Create the Resource Group

```bash
az group create \
  --name secure-logging-rg \
  --location australiaeast
```

### 🔹 Step 2: Create the ARM Template

Create a file named `secure-logging.json` and paste the following:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": { "type": "string", "defaultValue": "australiaeast" },
    "vnetName": { "type": "string", "defaultValue": "core-vnet" },
    "addressPrefix": { "type": "string", "defaultValue": "10.50.0.0/16" },
    "subnetName": { "type": "string", "defaultValue": "AppSubnet" },
    "subnetPrefix": { "type": "string", "defaultValue": "10.50.1.0/24" },
    "storageAccountName": { "type": "string" }
  },
  "resources": [
    {
      "type": "Microsoft.Network/virtualNetworks",
      "apiVersion": "2023-05-01",
      "name": "[parameters('vnetName')]",
      "location": "[parameters('location')]",
      "properties": {
        "addressSpace": {
          "addressPrefixes": [ "[parameters('addressPrefix')]" ]
        },
        "subnets": [
          {
            "name": "[parameters('subnetName')]",
            "properties": {
              "addressPrefix": "[parameters('subnetPrefix')]"
            }
          }
        ]
      }
    },
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2022-09-01",
      "name": "[parameters('storageAccountName')]",
      "location": "[parameters('location')]",
      "sku": { "name": "Standard_LRS" },
      "kind": "StorageV2",
      "properties": {
        "accessTier": "Hot",
        "allowBlobPublicAccess": false,
        "networkAcls": {
          "bypass": "AzureServices",
          "defaultAction": "Deny"
        }
      }
    }
  ]
}
```

### 🔹 Step 3: Deploy the ARM Template

```bash
az deployment group create \
  --resource-group secure-logging-rg \
  --template-file secure-logging.json \
  --parameters storageAccountName=logstore001
```

### 🔹 Step 4: Add Private Endpoint

```bash
STORAGE_ID=$(az storage account show \
  --name logstore001 \
  --resource-group secure-logging-rg \
  --query id -o tsv)

az network private-endpoint create \
  --name storage-pe \
  --resource-group secure-logging-rg \
  --vnet-name core-vnet \
  --subnet AppSubnet \
  --private-connection-resource-id $STORAGE_ID \
  --group-id blob \
  --connection-name storage-pe-conn
```

### 🔹 Step 5: Create & Link Private DNS Zone

```bash
az network private-dns zone create \
  --resource-group secure-logging-rg \
  --name privatelink.blob.core.windows.net

az network private-dns link vnet create \
  --resource-group secure-logging-rg \
  --zone-name privatelink.blob.core.windows.net \
  --name dns-link \
  --virtual-network core-vnet \
  --registration-enabled false

az network private-endpoint dns-zone-group create \
  --resource-group secure-logging-rg \
  --endpoint-name storage-pe \
  --name dns-zone-group \
  --private-dns-zone privatelink.blob.core.windows.net \
  --zone-name blob
```

---

## ✅ Post-Deployment Validation

### 🔹 Step 6: Verify DNS Resolution

```bash
nslookup logstore001.blob.core.windows.net
```

### 🔹 Step 7: Confirm Public Access Blocked

```bash
az storage blob list \
  --account-name logstore001 \
  --container-name logs \
  --auth-mode login
```

---

## 🧪 Optional: VM-Based Testing

### 🔹 Step 8: Create VM

```bash
read -s -p "Enter admin password: " VM_PASSWORD && echo

az vm create \
  --resource-group secure-logging-rg \
  --name log-test-vm \
  --vnet-name core-vnet \
  --subnet AppSubnet \
  --image UbuntuLTS \
  --admin-username azureuser \
  --admin-password "$VM_PASSWORD" \
  --authentication-type password
```

### 🔹 Step 9: SSH into the VM

```bash
ssh azureuser@<public-ip-of-vm>
```

### 🔹 Step 10: Test from VM

```bash
nslookup logstore001.blob.core.windows.net

curl -I https://logstore001.blob.core.windows.net
```

---

## 🔐 Optional: Test Internet Blocking via NSG

- Add outbound NSG rule to block `0.0.0.0/0`
- Confirm blob access via private endpoint still works

---

## 🎯 Final Validation Summary

| ✅ Check                        | 🧪 How to Validate                                |
|--------------------------------|---------------------------------------------------|
| DNS resolution (private IP)    | `nslookup logstore001.blob.core.windows.net`      |
| Public access blocked          | CLI/Browser externally should fail (403/timeout) |
| Blob access from VM            | `curl` or SDK from inside = 403/401               |
| Internet isolation (optional)  | NSG blocks outbound, private access still works   |
---