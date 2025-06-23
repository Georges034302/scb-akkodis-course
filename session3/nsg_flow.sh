#!/bin/bash

# filepath: nsg_flow.sh

RG="rg-flow-lab"
LOCATION="australiaeast"
VNET="vnet-demo"
SUBNET_WEB="web-subnet"
SUBNET_APP="app-subnet"
NSG="nsg-app"
USERNAME="azureuser"
VM_WEB="vm-web"
VM_APP="vm-app"
PIP_WEB="vm-web-pip"

echo "🗂️  Creating resource group: $RG..."
az group create --name $RG --location $LOCATION

echo "👁️  Enabling Network Watcher in $LOCATION..."
az network watcher configure --locations $LOCATION --resource-group $RG --enabled true

echo "🌐 Creating virtual network and web subnet..."
az network vnet create \
  --resource-group $RG \
  --name $VNET \
  --address-prefix 10.100.0.0/16 \
  --subnet-name $SUBNET_WEB \
  --subnet-prefix 10.100.1.0/24

echo "🌐 Adding app subnet to VNet..."
az network vnet subnet create \
  --resource-group $RG \
  --vnet-name $VNET \
  --name $SUBNET_APP \
  --address-prefix 10.100.2.0/24

echo "🛡️  Creating Network Security Group: $NSG..."
az network nsg create --resource-group $RG --name $NSG

echo "🚫 Adding NSG rule to deny SSH from web subnet to app subnet..."
az network nsg rule create \
  --resource-group $RG \
  --nsg-name $NSG \
  --name deny-web-to-app \
  --priority 100 \
  --direction Inbound \
  --access Deny \
  --protocol Tcp \
  --source-address-prefixes 10.100.1.0/24 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22

echo "🔗 Associating NSG to app subnet..."
az network vnet subnet update \
  --resource-group $RG \
  --vnet-name $VNET \
  --name $SUBNET_APP \
  --network-security-group $NSG

echo "🌐 Creating public IP for web VM..."
az network public-ip create \
  --resource-group $RG \
  --name $PIP_WEB \
  --sku Basic \
  --allocation-method Dynamic

echo "🔌 Creating NIC for web VM with public IP..."
az network nic create \
  --resource-group $RG \
  --name ${VM_WEB}-nic \
  --vnet-name $VNET \
  --subnet $SUBNET_WEB \
  --public-ip-address $PIP_WEB

echo "🔌 Creating NIC for app VM..."
az network nic create \
  --resource-group $RG \
  --name ${VM_APP}-nic \
  --vnet-name $VNET \
  --subnet $SUBNET_APP

echo "🔑 Please enter the VM admin password:"
read -s -p "🔒 Password: " PASSWORD
echo
echo "💻 Creating web VM (Ubuntu 18.04-LTS)..."
az vm create \
  --resource-group $RG \
  --name $VM_WEB \
  --nics ${VM_WEB}-nic \
  --image UbuntuLTS \
  --admin-username $USERNAME \
  --admin-password $PASSWORD \
  --authentication-type password

echo "💻 Creating app VM (Ubuntu 18.04-LTS)..."
az vm create \
  --resource-group $RG \
  --name $VM_APP \
  --nics ${VM_APP}-nic \
  --image UbuntuLTS \
  --admin-username $USERNAME \
  --admin-password $PASSWORD \
  --authentication-type password

echo "💾 Creating storage account for flow logs..."
az storage account create \
  --name flowlogstorage$RANDOM \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_LRS

echo "📊 Creating Log Analytics workspace..."
az monitor log-analytics workspace create \
  --resource-group $RG \
  --workspace-name flowlog-law \
  --location $LOCATION

echo "🔗 Configuring NSG flow logs and traffic analytics..."
STORAGE_ACCOUNT=$(az storage account list --resource-group $RG --query "[0].name" -o tsv)
WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group $RG --workspace-name flowlog-law --query id -o tsv)

az network watcher flow-log configure \
  --resource-group $RG \
  --nsg $NSG \
  --enabled true \
  --storage-account $STORAGE_ACCOUNT \
  --workspace $WORKSPACE_ID \
  --retention 0 \
  --traffic-analytics true \
  --interval 10

echo "🌐 Fetching public IP for web VM..."
WEB_PUBLIC_IP=$(az network public-ip show --resource-group $RG --name $PIP_WEB --query ipAddress -o tsv)
echo "🔑 You can SSH to your web VM using: ssh $USERNAME@$WEB_PUBLIC_IP"

echo "✅ NSG flow lab deployment complete!"