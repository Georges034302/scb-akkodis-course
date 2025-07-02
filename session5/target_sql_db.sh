#!/bin/bash
set -e

echo "🏗️ Provisioning target Azure SQL Managed Instance (SQL MI)..."
sleep 1

# Load environment variables
echo "📦 Loading environment variables from .env..."
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found. Run ./init_env.sh first."
  exit 1
fi

# Create SQL Managed Instance (can take up to an hour)
echo "🛠️ Creating SQL MI: $SQL_TARGET_NAME ..."
az sql mi create \
  --name "$SQL_TARGET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$SQL_MI_ADMIN_USER" \
  --admin-password "$SQL_MI_PASSWORD" \
  --subnet-id "$SUBNET_ID" \
  --license-type BasePrice \
  --edition GeneralPurpose \
  --family Gen5 \
  --vcores 4 \
  --storage-size 64GB

echo "✅ SQL Managed Instance provisioning started (may take up to 1 hour)."
echo "📌 You can monitor progress in the Azure Portal."
