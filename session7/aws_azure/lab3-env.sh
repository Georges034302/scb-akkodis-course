#!/usr/bin/env bash
# Session 7 - Lab 3 Environment (AWS -> Azure via Azure Migrate)
# TARGET landing zone in Azure for Lab 3-A (VHD import) and Lab 3-B (Azure Migrate)
# NOTE: This script DOES NOT create any storage accounts/containers. Follow Lab 3-A for storage steps.
# Safe, idempotent, and CI-friendly
set -euo pipefail
IFS=$'\n\t'

# -------- Config (overridable via env vars) --------
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"

# Target landing zone (single region for both Lab 3 variants) — use *-target naming*
TGT_LOCATION="${TGT_LOCATION:-australiaeast}"
TGT_RG="${TGT_RG:-rg-migrate-target}"
TGT_VNET="${TGT_VNET:-vnet-migrate-target}"
TGT_SUBNET="${TGT_SUBNET:-subnet-migrate-target}"
TGT_ADDR_SPACE="${TGT_ADDR_SPACE:-10.10.0.0/16}"
TGT_SUBNET_PREFIX="${TGT_SUBNET_PREFIX:-10.10.1.0/24}"
TGT_CREATE_NSG="${TGT_CREATE_NSG:-true}"
TGT_NSG="${TGT_NSG:-nsg-migrate-target}"

# NSG rules configuration
SSH_SOURCE="${SSH_SOURCE:-0.0.0.0/0}"            # "auto" to detect your /32
CREATE_WEB_RULES="${CREATE_WEB_RULES:-true}"      # if true, create allow-http/allow-https
HTTP_PRIORITY="${HTTP_PRIORITY:-1010}"
HTTPS_PRIORITY="${HTTPS_PRIORITY:-1020}"

# Azure Migrate: Project is typically created via Portal UI (recommended)
MIGRATE_PROJECT_NAME="${MIGRATE_PROJECT_NAME:-aws-migrate-target}"
CREATE_MIGRATE_PROJECT="${CREATE_MIGRATE_PROJECT:-false}" # set true to attempt CLI create via az resource

# Common
TAGS="${TAGS:-workshop=session7 lab=lab3}"    # space-separated key=value pairs
HANDOFF_FILE="${HANDOFF_FILE:-.lab.env}"

trap 'echo "❌ Error on line $LINENO. Exiting."; exit 1' ERR

# -------- Helpers --------
dequote() {
  local v="$1"
  v="${v%\"}"; v="${v#\"}"
  v="${v%\'}"; v="${v#\'}"
  printf "%s" "$v"
}

need_az() { command -v az >/dev/null 2>&1 || { echo "Azure CLI (az) not found. Install it first."; exit 1; }; }
ensure_login() { az account show >/dev/null 2>&1 || { echo "Please run: $0 login"; exit 1; }; }

ensure_providers() {
  # Include Microsoft.Migrate for Azure Migrate projects, and core dependencies
  for ns in Microsoft.Network Microsoft.Compute Microsoft.Migrate Microsoft.OperationalInsights Microsoft.Storage; do
    state=$(az provider show -n "$ns" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
    if [[ "$state" != "Registered" ]]; then
      echo "Registering resource provider: $ns"
      az provider register -n "$ns" -o none || true
    fi
  done
}

resolve_ssh_source() {
  if [[ "${SSH_SOURCE}" == "auto" ]]; then
    if command -v curl >/dev/null 2>&1; then
      local ip; ip="$(curl -s https://ifconfig.me || true)"
      if [[ -n "${ip}" ]]; then SSH_SOURCE="${ip}/32"; fi
    fi
  fi
}

exists_rg()     { az group exists -n "$1" | grep -q true; }
exists_vnet()   { az network vnet show -g "$1" -n "$2" >/dev/null 2>&1; }
exists_subnet() { az network vnet subnet show -g "$1" --vnet-name "$2" -n "$3" >/dev/null 2>&1; }
exists_nsg()    { az network nsg show -g "$1" -n "$2" >/dev/null 2>&1; }
has_rule()      { az network nsg rule show -g "$1" --nsg-name "$2" -n "$3" >/dev/null 2>&1; }

maybe_create_migrate_project() {
  if [[ "${CREATE_MIGRATE_PROJECT}" != "true" ]]; then
    echo "ℹ️ Skipping Azure Migrate project creation (CREATE_MIGRATE_PROJECT=false). Create it in the Portal if needed."
    return 0
  fi
  echo "Attempting to create Azure Migrate project '${MIGRATE_PROJECT_NAME}' in RG '${TGT_RG}' (${TGT_LOCATION})..."
  az resource create \
    --resource-group "${TGT_RG}" \
    --name "${MIGRATE_PROJECT_NAME}" \
    --resource-type "Microsoft.Migrate/migrateProjects" \
    --properties '{}' \
    --location "${TGT_LOCATION}" \
    --api-version "2019-10-01" \
    -o none || echo "⚠️ Could not create Azure Migrate project via CLI. Create it via Portal instead."
}

# -------- Commands --------
login() {
  need_az
  if az account show >/dev/null 2>&1; then
    echo "✅ Already logged into Azure."
  else
    echo "Logging in to Azure (device code)..."
    az login --use-device-code -o none
  fi
  if [[ -n "${SUBSCRIPTION_ID}" ]]; then
    echo "Setting subscription: ${SUBSCRIPTION_ID}"
    az account set --subscription "${SUBSCRIPTION_ID}" -o none
  fi
  echo "Active subscription:"
  az account show --query '{name:name, id:id}' -o table
  ensure_providers
}

init() {
  need_az; ensure_login; resolve_ssh_source

  # Clean variables (strip accidental quotes)
  _TGT_RG="$(dequote "${TGT_RG}")"
  _TGT_VNET="$(dequote "${TGT_VNET}")"
  _TGT_SUBNET="$(dequote "${TGT_SUBNET}")"
  _TGT_NSG="$(dequote "${TGT_NSG}")"
  _MIGRATE_PROJECT="$(dequote "${MIGRATE_PROJECT_NAME}")"

  echo "== Target (Australia East) landing zone configuration =="
  echo "  RG=$_TGT_RG  VNET=$_TGT_VNET  SUBNET=$_TGT_SUBNET  NSG=$_TGT_NSG  LOCATION=${TGT_LOCATION}"
  echo "  TAGS='${TAGS}'  SSH_SOURCE=${SSH_SOURCE}  CREATE_WEB_RULES=${CREATE_WEB_RULES}"
  echo "  NOTE: Storage accounts/containers are NOT created here; follow Lab 3-A for those steps."

  # Resource Group
  if ! exists_rg "$_TGT_RG"; then
    echo "Creating TGT RG '$_TGT_RG' in ${TGT_LOCATION}..."
    az group create -n "$_TGT_RG" -l "${TGT_LOCATION}" --tags "$TAGS" -o none
  else
    echo "TGT RG '$_TGT_RG' exists ✔"
  fi

  # VNet
  if ! exists_vnet "$_TGT_RG" "$_TGT_VNET"; then
    echo "Creating TGT VNet '$_TGT_VNET'..."
    az network vnet create -g "$_TGT_RG" -n "$_TGT_VNET" -l "${TGT_LOCATION}" \
      --address-prefixes "${TGT_ADDR_SPACE}" \
      --tags "$TAGS" -o none
  else
    echo "TGT VNet '$_TGT_VNET' exists ✔"
  fi

  # Subnet
  if ! exists_subnet "$_TGT_RG" "$_TGT_VNET" "$_TGT_SUBNET"; then
    echo "Creating TGT Subnet '$_TGT_SUBNET'..."
    az network vnet subnet create -g "$_TGT_RG" --vnet-name "$_TGT_VNET" -n "$_TGT_SUBNET" \
      --address-prefixes "${TGT_SUBNET_PREFIX}" -o none
  else
    echo "TGT Subnet '$_TGT_SUBNET' exists ✔"
  fi

  # NSG + rules + association (optional)
  if [[ "${TGT_CREATE_NSG}" == "true" ]]; then
    if ! exists_nsg "$_TGT_RG" "$_TGT_NSG"; then
      echo "Creating TGT NSG '$_TGT_NSG'..."
      az network nsg create -g "$_TGT_RG" -n "$_TGT_NSG" -l "${TGT_LOCATION}" --tags "$TAGS" -o none
    else
      echo "TGT NSG '$_TGT_NSG' exists ✔"
    fi

    # SSH (22) allow rule (create or update)
    if ! has_rule "$_TGT_RG" "$_TGT_NSG" "allow-ssh"; then
      echo "Adding TGT NSG rule 'allow-ssh'..."
      az network nsg rule create -g "$_TGT_RG" --nsg-name "$_TGT_NSG" -n allow-ssh \
        --priority 1000 --access Allow --protocol Tcp --direction Inbound \
        --source-address-prefixes "${SSH_SOURCE}" --destination-port-ranges 22 -o none
    else
      echo "Updating TGT NSG rule 'allow-ssh'..."
      az network nsg rule update -g "$_TGT_RG" --nsg-name "$_TGT_NSG" -n allow-ssh \
        --priority 1000 --access Allow --protocol Tcp --direction Inbound \
        --source-address-prefixes "${SSH_SOURCE}" --destination-port-ranges 22 -o none
    fi

    # Web rules (HTTP/HTTPS) if enabled
    if [[ "${CREATE_WEB_RULES}" == "true" ]]; then
      if ! has_rule "$_TGT_RG" "$_TGT_NSG" "allow-http"; then
        echo "Adding TGT NSG rule 'allow-http' (80)..."
        az network nsg rule create -g "$_TGT_RG" --nsg-name "$_TGT_NSG" -n allow-http \
          --priority "${HTTP_PRIORITY}" --access Allow --protocol Tcp --direction Inbound \
          --source-address-prefixes "*" --destination-port-ranges 80 -o none
      else
        echo "Updating TGT NSG rule 'allow-http' (80)..."
        az network nsg rule update -g "$_TGT_RG" --nsg-name "$_TGT_NSG" -n allow-http \
          --priority "${HTTP_PRIORITY}" --access Allow --protocol Tcp --direction Inbound \
          --source-address-prefixes "*" --destination-port-ranges 80 -o none
      fi

      if ! has_rule "$_TGT_RG" "$_TGT_NSG" "allow-https"; then
        echo "Adding TGT NSG rule 'allow-https' (443)..."
        az network nsg rule create -g "$_TGT_RG" --nsg-name "$_TGT_NSG" -n allow-https \
          --priority "${HTTPS_PRIORITY}" --access Allow --protocol Tcp --direction Inbound \
          --source-address-prefixes "*" --destination-port-ranges 443 -o none
      else
        echo "Updating TGT NSG rule 'allow-https' (443)..."
        az network nsg rule update -g "$_TGT_RG" --nsg-name "$_TGT_NSG" -n allow-https \
          --priority "${HTTPS_PRIORITY}" --access Allow --protocol Tcp --direction Inbound \
          --source-address-prefixes "*" --destination-port-ranges 443 -o none
      fi
    else
      echo "Skipping web NSG rules (CREATE_WEB_RULES=false)"
    fi

    echo "Associating TGT NSG with subnet..."
    az network vnet subnet update -g "$_TGT_RG" --vnet-name "$_TGT_VNET" -n "$_TGT_SUBNET" \
      --network-security-group "$_TGT_NSG" -o none
  else
    echo "Skipping NSG creation (TGT_CREATE_NSG=false)"
  fi

  # Optional: attempt creating Azure Migrate project (recommended via Portal)
  maybe_create_migrate_project

  echo "Writing environment variables to ${HANDOFF_FILE}..."
  cat > "${HANDOFF_FILE}" <<EOF
# Generated by lab3-env.sh (Lab 3 - AWS -> Azure)
export TGT_LOCATION="${TGT_LOCATION}"
export TGT_RG="${TGT_RG}"
export TGT_VNET="${TGT_VNET}"
export TGT_SUBNET="${TGT_SUBNET}"
export TGT_NSG="${TGT_NSG}"
export MIGRATE_PROJECT_NAME="${MIGRATE_PROJECT_NAME}"
export SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null || true)"
export TGT_VNET_ID="$(az network vnet show -g "${TGT_RG}" -n "${TGT_VNET}" --query id -o tsv 2>/dev/null || true)"
export TGT_SUBNET_ID="$(az network vnet subnet show -g "${TGT_RG}" --vnet-name "${TGT_VNET}" -n "${TGT_SUBNET}" --query id -o tsv 2>/dev/null || true)"
EOF
  echo "✅ Environment handoff file created: ${HANDOFF_FILE}"
  echo "✅ Lab 3 TARGET landing zone ready."
}

status() {
  echo ""
  echo "=============================="
  echo "🔍 Lab 3 TARGET Environment Status"
  echo "=============================="
  echo ""

  echo "== Target Landing Zone (${TGT_LOCATION}) ==""
  TGT_RG_INFO=$(az group show -n "${TGT_RG}" --query '{Name:name, Location:location, ProvisioningState:properties.provisioningState}' -o tsv 2>/dev/null || true)
  [[ -n "$TGT_RG_INFO" ]] && echo "  • Resource Group: $TGT_RG_INFO" || echo "  • Resource Group: ${TGT_RG} (not found)"

  VNET_NAME=$(az network vnet show -g "${TGT_RG}" -n "${TGT_VNET}" --query 'name' -o tsv 2>/dev/null || true)
  if [[ -n "$VNET_NAME" ]]; then
    echo "  • VNet: $VNET_NAME"
    SUBNET_INFO=$(az network vnet subnet show -g "${TGT_RG}" --vnet-name "${TGT_VNET}" -n "${TGT_SUBNET}" --query '[name, addressPrefix]' -o tsv 2>/dev/null || true)
    [[ -n "$SUBNET_INFO" ]] && echo "    • Subnet: $(echo $SUBNET_INFO | awk '{print $1 " (" $2 ")"}')" || echo "    • Subnet: ${TGT_SUBNET} (not found)"
  else
    echo "  • VNet: ${TGT_VNET} (not found)"
  fi

  NSG_INFO=$(az network nsg show -g "${TGT_RG}" -n "${TGT_NSG}" --query '[name, provisioningState]' -o tsv 2>/dev/null || true)
  if [[ -n "$NSG_INFO" ]]; then
    echo "  • NSG: $(echo $NSG_INFO | awk '{print $1 " (" $2 ")"}')"
    for RULE in allow-ssh allow-http allow-https; do
      INFO=$(az network nsg rule show -g "${TGT_RG}" --nsg-name "${TGT_NSG}" -n "$RULE" --query '[name,priority]' -o tsv 2>/dev/null || true)
      [[ -n "$INFO" ]] && echo "    • Rule: $RULE (priority $(echo $INFO | awk '{print $2}') )"
    done
  else
    echo "  • NSG: ${TGT_NSG} (not found)"
  fi
  echo ""

  echo "== Azure Migrate Project (optional) =="
  MIG_PROJ=$(az resource show -g "${TGT_RG}" -n "${MIGRATE_PROJECT_NAME}" --resource-type "Microsoft.Migrate/migrateProjects" --query '[name,location,properties.provisioningState]' -o tsv 2>/dev/null || true)
  if [[ -n "$MIG_PROJ" ]]; then
    echo "  • Migrate Project: $(echo $MIG_PROJ | awk '{print $1 " (" $2 ", " $3 ")"}')"
  else
    echo "  • Migrate Project: ${MIGRATE_PROJECT_NAME} (not found / Portal-created projects may not appear immediately)"
  fi
  echo ""
}

cleanup() {
  echo "🧹 Cleanup starting..."
  echo "Target Resource Group: $TGT_RG"
  if exists_rg "$(dequote "$TGT_RG")"; then
    echo "Deleting target resource group (${TGT_RG})..."
    az group delete -n "$(dequote "$TGT_RG")" --yes --no-wait || true
  else
    echo "TGT RG '${TGT_RG}' not found; nothing to delete."
  fi
  if [ -f "${HANDOFF_FILE}" ]; then
    echo "Removing handoff file: ${HANDOFF_FILE}"
    rm -f "${HANDOFF_FILE}"
  fi
  echo "🧹 Cleanup commands issued. Resource deletions are running in background."
}

help() {
  echo "Usage: $0 {login|init|status|cleanup|help}"
  echo ""
  echo "  login    - Authenticate to Azure and set subscription; registers required providers"
  echo "  init     - Create TARGET RG, VNet, Subnet, optional NSG+rules (SSH/HTTP/HTTPS), and optionally Azure Migrate project"
  echo "  status   - Show a summary of created TARGET resources and (optional) Migrate project"
  echo "  cleanup  - Delete the TARGET resource group and the handoff file"
  echo "  help     - Show this help message"
  echo ""
  echo "Environment variables (optional):"
  echo "  SUBSCRIPTION_ID            Switch subscription after login"
  echo "  TGT_LOCATION               Default: australiaeast"
  echo "  TGT_RG                     Default: rg-migrate-target"
  echo "  TGT_VNET                   Default: vnet-migrate-target"
  echo "  TGT_SUBNET                 Default: subnet-migrate-target"
  echo "  TGT_ADDR_SPACE             Default: 10.10.0.0/16"
  echo "  TGT_SUBNET_PREFIX          Default: 10.10.1.0/24"
  echo "  TGT_CREATE_NSG             true|false (default: true)"
  echo "  TGT_NSG                    Default: nsg-migrate-target"
  echo "  SSH_SOURCE                 CIDR (default: 0.0.0.0/0, or \"auto\" for your /32)"
  echo "  CREATE_WEB_RULES           true|false (default: true)"
  echo "  HTTP_PRIORITY              Default: 1010"
  echo "  HTTPS_PRIORITY             Default: 1020"
  echo ""
  echo "  MIGRATE_PROJECT_NAME       Default: aws-migrate-target"
  echo "  CREATE_MIGRATE_PROJECT     true|false (default: false) – CLI attempt; Portal recommended"
  echo ""
  echo "  TAGS                       Space-separated key=value tags (default: \"workshop=session7 lab=lab3\")"
  echo "  HANDOFF_FILE               Output file (default: .lab.env)"
}

# --- Command dispatcher ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    help
    exit 1
  fi
  "$@"
fi