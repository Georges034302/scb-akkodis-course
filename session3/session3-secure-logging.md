# 🧪 Secure Storage Access Using ARM Template and RFC 1918 IP Strategy

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
- A globally unique storage account name 
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
    "location": {
      "type": "string",
      "defaultValue": "australiaeast"
    },
    "vnetName": {
      "type": "string",
      "defaultValue": "core-vnet"
    },
    "addressPrefix": {
      "type": "string",
      "defaultValue": "10.50.0.0/16"
    },
    "subnetName": {
      "type": "string",
      "defaultValue": "AppSubnet"
    },
    "subnetPrefix": {
      "type": "string",
      "defaultValue": "10.50.1.0/24"
    },
    "storageAccountName": {
      "type": "string"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Network/virtualNetworks",
      "apiVersion": "2023-05-01",
      "name": "[parameters('vnetName')]",
      "location": "[parameters('location')]",
      "properties": {
        "addressSpace": {
          "addressPrefixes": [
            "[parameters('addressPrefix')]"
          ]
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
      "sku": {
        "name": "Standard_LRS"
      },
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
STORAGE_NAME="logstore$(date +%s)"  # Set a unique storage name
```
```bash
az deployment group create \
  --resource-group secure-logging-rg \
  --template-file secure-logging.json \
  --parameters storageAccountName="$STORAGE_NAME"
```

### 🔹 Step 4: Add Private Endpoint

```bash
./create-endpoint.sh
```

### 🔹 Step 5: Create & Link Private DNS Zone

```bash
./create-dns.sh
```

---

## ✅ Post-Deployment Validation

### 🔹 Step 6: Confirm Public Access Is Blocked (Run Locally or Outside VNet)

```bash
az storage blob list \
  --account-name "$STORAGE_NAME" \
  --container-name logs \
  --auth-mode login
```
```
❌ Expected: Operation fails with 403 or network error — confirms internet access is disabled on the storage account.
```

### 🔹 Step 7: Deploy a Test VM (Inside the VNet)

```bash
read -s -p "Enter admin password: " VM_PASSWORD && echo

az vm create \
  --resource-group secure-logging-rg \
  --name log-test-vm \
  --vnet-name core-vnet \
  --subnet AppSubnet \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --admin-password "$VM_PASSWORD" \
  --authentication-type password
```

---

### 🔹 Step 8: SSH into the VM

```bash
VM_PUBLIC_IP=$(az vm show \
  --resource-group secure-logging-rg \
  --name log-test-vm \
  --show-details \
  --query publicIps \
  -o tsv)
 
ssh azureuser@"$VM_PUBLIC_IP"
```

### 🔹 Step 9: Test from VM

```bash
nslookup "$STORAGE_NAME".blob.core.windows.net

curl -I https://"$STORAGE_NAME".blob.core.windows.net
```
```
✅ Expected:
nslookup returns 10.50.x.x (Private IP)
curl returns 403/401 (private access working, authentication not yet provided)
```
---

## 🔐  Step 10 (Optional): Simulate Internet Isolation via NSG

- Create an NSG denying outbound to 0.0.0.0/0.\
- Associate it with the AppSubnet or VM NIC.
  - Confirm:
  - Public internet is blocked ❌
  - Blob access still works privately ✅
---

## 🎯 Final Validation Summary

| ✅ Check                       | 🧪 How to Validate                               |
|--------------------------------|---------------------------------------------------|
| DNS resolution (private IP)    | `nslookup "$STORAGE_NAME".blob.core.windows.net`  |
| Public access blocked          | CLI/Browser externally should fail (403/timeout)  |
| Blob access from VM            | `curl` or SDK from inside VM = 403/401            |
| Internet isolation (optional)  | NSG blocks outbound, private access still works   |

---