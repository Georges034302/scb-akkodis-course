#!/usr/bin/env bash
# Common setup & cleanup for Session 7 labs (Linux VM landing zone)
set -euo pipefail

# -------- Config (overridable via env vars) --------
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"           # If set, we'll switch to it after login
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RG:-rg-migrate-demo}"
VNET_NAME="${VNET:-vnet-migrate}"
SUBNET_NAME="${SUBNET:-subnet-migrate}"
ADDR_SPACE="${ADDR_SPACE:-10.10.0.0/16}"
SUBNET_PREFIX="${SUBNET_PREFIX:-10.10.1.0/24}"
TAGS="${TAGS:-workshop=session7}"
CREATE_NSG="${CREATE_NSG:-true}"                 # true|false
NSG_NAME="${NSG_NAME:-nsg-migrate}"
SSH_SOURCE="${SSH_SOURCE:-0.0.0.0/0}"            # Optionally lock to your IP (e.g., "203.0.113.5/32")

trap 'echo "❌ Error on line $LINENO. Exiting."; exit 1' ERR

# -------- Helpers --------
need_az() {
  command -v az >/dev/null 2>&1 || { echo "Azure CLI (az) not found. Install it first."; exit 1; }
}

# -------- Commands --------
login() {
  need_az
  echo "Logging in to Azure (device code)..."
  az login --use-device-code -o none

  if [[ -n "${SUBSCRIPTION_ID}" ]]; then
    echo "Setting subscription: ${SUBSCRIPTION_ID}"
    az account set --subscription "${SUBSCRIPTION_ID}" -o none
  fi

  echo "Active subscription:"
  az account show --query '{name:name, id:id, tenantId:tenantId}' -o table
}

init() {
  need_az
  # Ensure logged in
  az account show >/dev/null 2>&1 || { echo "Please run: $0 login"; exit 1; }

  echo "Config:"
  echo "  LOCATION=${LOCATION}"
  echo "  RG=${RESOURCE_GROUP}"
  echo "  VNET=${VNET_NAME}  SUBNET=${SUBNET_NAME}"
  echo "  CIDRs: ${ADDR_SPACE} / ${SUBNET_PREFIX}"
  echo "  TAGS='${TAGS}'"
  echo "  NSG=${CREATE_NSG}  SSH_SOURCE=${SSH_SOURCE}"

  echo "Creating resource group '${RESOURCE_GROUP}' in ${LOCATION}..."
  az group create \
    -n "${RESOURCE_GROUP}" \
    -l "${LOCATION}" \
    --tags "${TAGS}" \
    -o none

  echo "Creating VNet '${VNET_NAME}' and subnet '${SUBNET_NAME}'..."
  az network vnet create \
    -g "${RESOURCE_GROUP}" \
    -n "${VNET_NAME}" \
    --address-prefixes "${ADDR_SPACE}" \
    --subnet-name "${SUBNET_NAME}" \
    --subnet-prefixes "${SUBNET_PREFIX}" \
    --tags "${TAGS}" \
    -o none

  if [[ "${CREATE_NSG}" == "true" ]]; then
    echo "Creating NSG '${NSG_NAME}' with SSH rule (source: ${SSH_SOURCE})..."
    az network nsg create -g "${RESOURCE_GROUP}" -n "${NSG_NAME}" --tags "${TAGS}" -o none

    # Remove existing rule if re-running
    az network nsg rule delete -g "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" -n allow-ssh >/dev/null 2>&1 || true

    az network nsg rule create \
      -g "${RESOURCE_GROUP}" \
      --nsg-name "${NSG_NAME}" \
      -n allow-ssh \
      --priority 1000 \
      --access Allow \
      --protocol Tcp \
      --direction Inbound \
      --source-address-prefixes "${SSH_SOURCE}" \
      --destination-port-ranges 22 \
      -o none

    echo "Associating NSG to subnet..."
    SUBNET_ID=$(az network vnet subnet show \
      -g "${RESOURCE_GROUP}" --vnet-name "${VNET_NAME}" -n "${SUBNET_NAME}" \
      --query id -o tsv)
    az network vnet subnet update --ids "${SUBNET_ID}" --network-security-group "${NSG_NAME}" -o none
  fi

  echo "✅ Environment ready: RG=${RESOURCE_GROUP}, VNet=${VNET_NAME}, Subnet=${SUBNET_NAME}"
}

status() {
  need_az
  # If not logged in, this will fail fast but cleanly
  if ! az account show >/dev/null 2>&1; then
    echo "Not logged in. Run: $0 login"
    exit 1
  fi

  echo "🔍 Checking environment status (subscription + resources)..."
  az account show --query '{name:name, id:id}' -o table

  printf "Resource Group '%s': " "${RESOURCE_GROUP}"
  if az group show -n "${RESOURCE_GROUP}" -o none 2>/dev/null; then
    echo "✅ exists"
  else
    echo "❌ not found"
    return
  fi

  printf "VNet '%s': " "${VNET_NAME}"
  if az network vnet show -g "${RESOURCE_GROUP}" -n "${VNET_NAME}" -o none 2>/dev/null; then
    echo "✅ exists"
  else
    echo "❌ not found"
  fi

  printf "Subnet '%s': " "${SUBNET_NAME}"
  if az network vnet subnet show -g "${RESOURCE_GROUP}" --vnet-name "${VNET_NAME}" -n "${SUBNET_NAME}" -o none 2>/dev/null; then
    echo "✅ exists"
  else
    echo "❌ not found"
  fi

  if [[ "${CREATE_NSG}" == "true" ]]; then
    printf "NSG '%s': " "${NSG_NAME}"
    if az network nsg show -g "${RESOURCE_GROUP}" -n "${NSG_NAME}" -o none 2>/dev/null; then
      echo "✅ exists"
    else
      echo "❌ not found"
    fi
  fi

  echo "VMs in RG '${RESOURCE_GROUP}' (name, public IP, power state):"
  az vm list -g "${RESOURCE_GROUP}" --show-details --query "[].{name:name, ip:publicIps, state:powerState}" -o table || true
}

cleanup() {
  need_az
  echo "Deleting resource group '${RESOURCE_GROUP}' (no-wait)..."
  az group delete -n "${RESOURCE_GROUP}" --yes --no-wait
  echo "🧹 Cleanup started."
}

usage() {
  cat <<EOF
Usage: $(basename "$0") {login|init|status|cleanup}

Env vars (optional):
  SUBSCRIPTION_ID     Azure subscription ID to target
  LOCATION            Region (default: australiaeast)
  RG                  Resource group (default: rg-migrate-demo)
  VNET                VNet name (default: vnet-migrate)
  SUBNET              Subnet name (default: subnet-migrate)
  ADDR_SPACE          VNet CIDR (default: 10.10.0.0/16)
  SUBNET_PREFIX       Subnet CIDR (default: 10.10.1.0/24)
  TAGS                Azure tags (default: workshop=session7)
  CREATE_NSG          true|false (default: true)
  NSG_NAME            NSG name (default: nsg-migrate)
  SSH_SOURCE          Allowed CIDR for SSH (default: 0.0.0.0/0)
EOF
}

case "${1:-}" in
  login)   login ;;
  init)    init ;;
  status)  status ;;
  cleanup) cleanup ;;
  *)       usage ;;
esac
