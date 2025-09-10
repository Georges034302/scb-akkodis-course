#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: create-dns.sh
# Description: Links a Private DNS zone to the VNet and associates it with the
#              existing private endpoint to support internal name resolution.
# Usage:       ./create-dns.sh
# -----------------------------------------------------------------------------
export MSYS_NO_PATHCONV=1

RESOURCE_GROUP="secure-logging-rg"
VNET_NAME="core-vnet"
DNS_ZONE_NAME="privatelink.blob.core.windows.net"
DNS_LINK_NAME="dns-link"
PE_NAME="storage-pe"
ZONE_GROUP_NAME="dns-zone-group"

# Step 1: Create the private DNS zone
echo "🔧 Creating Private DNS Zone: $DNS_ZONE_NAME..."
az network private-dns zone create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DNS_ZONE_NAME"

# Step 2: Link the DNS zone to the VNet
echo "🔗 Linking DNS zone to VNet: $VNET_NAME..."
az network private-dns link vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --zone-name "$DNS_ZONE_NAME" \
  --name "$DNS_LINK_NAME" \
  --virtual-network "$VNET_NAME" \
  --registration-enabled false

# Step 3: Create the DNS zone group for the private endpoint
echo "📎 Creating DNS zone group for Private Endpoint: $PE_NAME..."
az network private-endpoint dns-zone-group create \
  --resource-group "$RESOURCE_GROUP" \
  --endpoint-name "$PE_NAME" \
  --name "$ZONE_GROUP_NAME" \
  --private-dns-zone "$DNS_ZONE_NAME" \
  --zone-name blob

echo "✅ Private DNS setup completed."
