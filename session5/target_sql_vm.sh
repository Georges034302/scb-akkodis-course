#!/bin/bash
set -e

echo "🚀 Provisioning Azure SQL VM for migration demo..."
sleep 1

# Load environment variables
echo "📦 Loading environment variables from .env..."
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found. Run ./init_env.sh first."
  exit 1
fi

# --- Create VM ---
echo "🖥️ Creating Azure VM: $SQL_VM_NAME ..."
az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$SQL_VM_NAME" \
  --image "$SQL_IMAGE" \
  --admin-username "$ADMIN_USER" \
  --admin-password "$ADMIN_PASSWORD" \
  --size Standard_D2s_v3 \
  --public-ip-sku Standard \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME"
echo "✅ VM created."

# --- Register as SQL VM in Azure ---
echo "📝 Registering VM as Azure SQL VM..."
az sql vm create \
  --name "$SQL_VM_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --license-type PAYG \
  --image-sku Developer \
  --sql-mgmt-type Full
echo "✅ VM registered as SQL VM."

# --- Open SQL TCP port 1433 (optional, for DMS or remote access) ---
echo "🔓 Opening SQL TCP port 1433..."
az vm open-port --resource-group "$RESOURCE_GROUP" --name "$SQL_VM_NAME" --port 1433
echo "✅ Port 1433 opened."

# --- Create storage account ---
echo "💾 Creating sql backup storage account: $STORAGE_NAME ..."
az storage account create \
  --name "$STORAGE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS
echo "✅ Storage account created."

# --- Create blob container ---
echo "📦 Creating blob sql backup container: $STORAGE_CONTAINER ..."
az storage container create \
  --account-name "$STORAGE_NAME" \
  --name "$STORAGE_CONTAINER" \
  --auth-mode login
echo "✅ Blob container created."







