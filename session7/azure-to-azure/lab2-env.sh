#!/usr/bin/env bash
# Session 7 - Lab 2 Environment (ASR: Source -> Target Cross-Region)
# Prepares SOURCE (Australia East) + TARGET (Australia Southeast) infra for ASR demo
# Safe, idempotent, and CI-friendly
set -euo pipefail
IFS=$'\n\t'

# -------- Config (overridable via env vars) --------
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"

# Source (simulated on-prem) in Australia East
SRC_LOCATION="${SRC_LOCATION:-australiaeast}"
SRC_RG="${SRC_RG:-rg-migrate-source}"
SRC_VNET="${SRC_VNET:-vnet-migrate-source}"
SRC_SUBNET="${SRC_SUBNET:-subnet-migrate-source}"
SRC_ADDR_SPACE="${SRC_ADDR_SPACE:-10.10.0.0/16}"
SRC_SUBNET_PREFIX="${SRC_SUBNET_PREFIX:-10.10.1.0/24}"
SRC_CREATE_NSG="${SRC_CREATE_NSG:-true}"
SRC_NSG="${SRC_NSG:-nsg-migrate-source}"

# Target (Azure DR region) in Australia Southeast
TGT_LOCATION="${TGT_LOCATION:-australiasoutheast}"
TGT_RG_VAULT="${TGT_RG_VAULT:-rg-migrate-target-vault}"   # Vault lives here
TGT_VAULT_NAME="${TGT_VAULT_NAME:-migrateVaultSEA-target}" # Recovery Services Vault
TGT_RG_ASR="${TGT_RG_ASR:-rg-migrate-target}"              # Replicated items land here
TGT_VNET="${TGT_VNET:-vnet-migrate-target}"
TGT_SUBNET="${TGT_SUBNET:-subnet-migrate-target}"
TGT_ADDR_SPACE="${TGT_ADDR_SPACE:-10.20.0.0/16}"
TGT_SUBNET_PREFIX="${TGT_SUBNET_PREFIX:-10.20.1.0/24}"
TGT_CREATE_NSG="${TGT_CREATE_NSG:-false}"                  # Usually created by wizard; optional here
TGT_NSG="${TGT_NSG:-nsg-migrate-target}"

# Common
TAGS="${TAGS:-workshop=session7 lab=lab2-asr}"              # space-separated key=value pairs
SSH_SOURCE="${SSH_SOURCE:-0.0.0.0/0}"                       # "auto" to detect your /32
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
  for ns in Microsoft.Network Microsoft.Compute Microsoft.RecoveryServices Microsoft.OperationalInsights Microsoft.Storage; do
    state=$(az provider show -n "$ns" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
    if [[ "$state" != "Registered" ]]; then
      echo "Registering resource provider: $ns"
      az provider register -n "$ns" -o none || true
    fi
  done
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
  need_az; ensure_login

  # Clean variables (strip accidental quotes)
  _SRC_RG="$(dequote "${SRC_RG}")"
  _SRC_VNET="$(dequote "${SRC_VNET}")"
  _SRC_SUBNET="$(dequote "${SRC_SUBNET}")"
  _SRC_NSG="$(dequote "${SRC_NSG}")"
  _TGT_RG_VAULT="$(dequote "${TGT_RG_VAULT}")"
  _TGT_VAULT_NAME="$(dequote "${TGT_VAULT_NAME}")"
  _TGT_RG_ASR="$(dequote "${TGT_RG_ASR}")"
  _TGT_VNET="$(dequote "${TGT_VNET}")"
  _TGT_SUBNET="$(dequote "${TGT_SUBNET}")"
  _TGT_NSG="$(dequote "${TGT_NSG}")"

  echo "== Source (Australia East) configuration =="
  echo "  RG=$_SRC_RG  VNET=$_SRC_VNET  SUBNET=$_SRC_SUBNET  NSG=$_SRC_NSG"

  # Source RG
  if ! az group exists -n "$_SRC_RG" | grep -q true; then
    echo "Creating SRC RG '$_SRC_RG'..."
    az group create -n "$_SRC_RG" -l "$SRC_LOCATION" --tags "$TAGS" -o none
  fi

  # Source VNet
  if ! az network vnet show -g "$_SRC_RG" -n "$_SRC_VNET" >/dev/null 2>&1; then
    echo "Creating SRC VNet '$_SRC_VNET'..."
    az network vnet create -g "$_SRC_RG" -n "$_SRC_VNET" -l "$SRC_LOCATION" \
      --address-prefixes "$SRC_ADDR_SPACE" \
      --tags "$TAGS" -o none
  fi
  # Ensure Source Subnet exists
  if ! az network vnet subnet show -g "$_SRC_RG" --vnet-name "$_SRC_VNET" -n "$_SRC_SUBNET" >/dev/null 2>&1; then
    echo "Creating SRC Subnet '$_SRC_SUBNET'..."
    az network vnet subnet create -g "$_SRC_RG" --vnet-name "$_SRC_VNET" -n "$_SRC_SUBNET" \
      --address-prefixes "$SRC_SUBNET_PREFIX" --tags "$TAGS" -o none
  fi

  # Source NSG + rule + association (optional)
  if [[ "$SRC_CREATE_NSG" == "true" ]]; then
    if ! az network nsg show -g "$_SRC_RG" -n "$_SRC_NSG" >/dev/null 2>&1; then
      echo "Creating SRC NSG '$_SRC_NSG'..."
      az network nsg create -g "$_SRC_RG" -n "$_SRC_NSG" -l "$SRC_LOCATION" --tags "$TAGS" -o none
    fi
    if ! az network nsg rule show -g "$_SRC_RG" --nsg-name "$_SRC_NSG" -n allow-ssh >/dev/null 2>&1; then
      echo "Adding SRC NSG rule 'allow-ssh'..."
      az network nsg rule create -g "$_SRC_RG" --nsg-name "$_SRC_NSG" -n allow-ssh \
        --priority 1000 --access Allow --protocol Tcp --direction Inbound \
        --source-address-prefixes "$SSH_SOURCE" --destination-port-ranges 22 -o none
    fi
    echo "Associating SRC NSG with Subnet..."
    az network vnet subnet update -g "$_SRC_RG" --vnet-name "$_SRC_VNET" -n "$_SRC_SUBNET" \
      --network-security-group "$_SRC_NSG" -o none
  fi

  echo "== Target (Australia Southeast) configuration =="
  echo "  Vault RG=$_TGT_RG_VAULT  Vault=$_TGT_VAULT_NAME"
  echo "  ASR RG=$_TGT_RG_ASR  VNET=$_TGT_VNET  SUBNET=$_TGT_SUBNET"

  # Target RGs
  if ! az group exists -n "$_TGT_RG_VAULT" | grep -q true; then
    echo "Creating TGT Vault RG '$_TGT_RG_VAULT'..."
    az group create -n "$_TGT_RG_VAULT" -l "$TGT_LOCATION" --tags "$TAGS" -o none
  fi
  if ! az group exists -n "$_TGT_RG_ASR" | grep -q true; then
    echo "Creating TGT ASR RG '$_TGT_RG_ASR'..."
    az group create -n "$_TGT_RG_ASR" -l "$TGT_LOCATION" --tags "$TAGS" -o none
  fi

  # Recovery Services Vault (must be Microsoft.RecoveryServices/vaults)
  if ! az backup vault show -g "$_TGT_RG_VAULT" -n "$_TGT_VAULT_NAME" >/dev/null 2>&1; then
    echo "Creating Recovery Services Vault '$_TGT_VAULT_NAME'..."
    az backup vault create -g "$_TGT_RG_VAULT" -n "$_TGT_VAULT_NAME" -l "$TGT_LOCATION" -o none
  fi

  # Target VNet
  if ! az network vnet show -g "$_TGT_RG_ASR" -n "$_TGT_VNET" >/dev/null 2>&1; then
    echo "Creating TGT VNet '$_TGT_VNET'..."
    az network vnet create -g "$_TGT_RG_ASR" -n "$_TGT_VNET" -l "$TGT_LOCATION" \
      --address-prefixes "$TGT_ADDR_SPACE" \
      --tags "$TAGS" -o none
  fi
  # Ensure Target Subnet exists
  if ! az network vnet subnet show -g "$_TGT_RG_ASR" --vnet-name "$_TGT_VNET" -n "$_TGT_SUBNET" >/dev/null 2>&1; then
    echo "Creating TGT Subnet '$_TGT_SUBNET'..."
    az network vnet subnet create -g "$_TGT_RG_ASR" --vnet-name "$_TGT_VNET" -n "$_TGT_SUBNET" \
      --address-prefixes "$TGT_SUBNET_PREFIX" --tags "$TAGS" -o none
  fi

  # Optional TGT NSG + rule + association
  if [[ "$TGT_CREATE_NSG" == "true" ]]; then
    if ! az network nsg show -g "$_TGT_RG_ASR" -n "$_TGT_NSG" >/dev/null 2>&1; then
      echo "Creating TGT NSG '$_TGT_NSG'..."
      az network nsg create -g "$_TGT_RG_ASR" -n "$_TGT_NSG" -l "$TGT_LOCATION" --tags "$TAGS" -o none
    fi
    if ! az network nsg rule show -g "$_TGT_RG_ASR" --nsg-name "$_TGT_NSG" -n allow-ssh >/dev/null 2>&1; then
      echo "Adding TGT NSG rule 'allow-ssh'..."
      az network nsg rule create -g "$_TGT_RG_ASR" --nsg-name "$_TGT_NSG" -n allow-ssh \
        --priority 1000 --access Allow --protocol Tcp --direction Inbound \
        --source-address-prefixes "$SSH_SOURCE" --destination-port-ranges 22 -o none
    fi
    echo "Associating TGT NSG with Subnet..."
    az network vnet subnet update -g "$_TGT_RG_ASR" --vnet-name "$_TGT_VNET" -n "$_TGT_SUBNET" \
      --network-security-group "$_TGT_NSG" -o none
  fi

  echo "Writing environment variables to ${HANDOFF_FILE}..."
  cat > "${HANDOFF_FILE}" <<EOF
export SRC_RG="${SRC_RG}"
export SRC_VNET="${SRC_VNET}"
export SRC_SUBNET="${SRC_SUBNET}"
export SRC_NSG="${SRC_NSG}"
export TGT_RG_VAULT="${TGT_RG_VAULT}"
export TGT_VAULT_NAME="${TGT_VAULT_NAME}"
export TGT_RG_ASR="${TGT_RG_ASR}"
export TGT_VNET="${TGT_VNET}"
export TGT_SUBNET="${TGT_SUBNET}"
export TGT_NSG="${TGT_NSG}"
EOF
  echo "✅ Environment handoff file created: ${HANDOFF_FILE}"
  echo "✅ Lab 2 environment ready."
}

status() {
  echo ""
  echo "=============================="
  echo "🔍 Lab 2 ASR Environment Status"
  echo "=============================="
  echo ""

  echo "== Source Environment =="
  SRC_RG_INFO=$(az group show -n "${SRC_RG}" --query '{Name:name, Location:location, ProvisioningState:properties.provisioningState}' -o tsv 2>/dev/null)
  [[ -n "$SRC_RG_INFO" ]] && echo "  • Resource Group: $SRC_RG_INFO" || echo "  • Resource Group: ${SRC_RG} (not found)"
  VNET_SRC=$(az network vnet show -g "${SRC_RG}" -n "${SRC_VNET}" --query 'name' -o tsv 2>/dev/null)
  if [[ -n "$VNET_SRC" ]]; then
    echo "  • VNet: $VNET_SRC"
    SUBNET_SRC=$(az network vnet subnet show -g "${SRC_RG}" --vnet-name "${SRC_VNET}" -n "${SRC_SUBNET}" --query '[name, addressPrefix]' -o tsv 2>/dev/null)
    [[ -n "$SUBNET_SRC" ]] && echo "    • Subnet: $(echo $SUBNET_SRC | awk '{print $1 " (" $2 ")"}')" || echo "    • Subnet: ${SRC_SUBNET} (not found)"
  else
    echo "  • VNet: ${SRC_VNET} (not found)"
  fi
  NSG_SRC=$(az network nsg show -g "${SRC_RG}" -n "${SRC_NSG}" --query '[name, provisioningState]' -o tsv 2>/dev/null)
  [[ -n "$NSG_SRC" ]] && echo "  • NSG: $(echo $NSG_SRC | awk '{print $1 " (" $2 ")"}')" || echo "  • NSG: ${SRC_NSG} (not found)"
  echo ""

  echo "== ASR Vault Environment =="
  TGT_RG_VAULT_INFO=$(az group show -n "${TGT_RG_VAULT}" --query '{Name:name, Location:location, ProvisioningState:properties.provisioningState}' -o tsv 2>/dev/null)
  [[ -n "$TGT_RG_VAULT_INFO" ]] && echo "  • Resource Group: $TGT_RG_VAULT_INFO" || echo "  • Resource Group: ${TGT_RG_VAULT} (not found)"
  VAULT_INFO=$(az backup vault show -g "${TGT_RG_VAULT}" -n "${TGT_VAULT_NAME}" --query '[name, location, provisioningState]' -o tsv 2>/dev/null)
  [[ -n "$VAULT_INFO" ]] && echo "  • Recovery Services Vault: $(echo $VAULT_INFO | awk '{print $1 " (" $2 ", " $3 ")"}')" || echo "  • Recovery Services Vault: ${TGT_VAULT_NAME} (not found)"
  echo ""

  echo "== Target (ASR) Environment =="
  TGT_RG_ASR_INFO=$(az group show -n "${TGT_RG_ASR}" --query '{Name:name, Location:location, ProvisioningState:properties.provisioningState}' -o tsv 2>/dev/null)
  [[ -n "$TGT_RG_ASR_INFO" ]] && echo "  • Resource Group: $TGT_RG_ASR_INFO" || echo "  • Resource Group: ${TGT_RG_ASR} (not found)"
  VNET_TGT=$(az network vnet show -g "${TGT_RG_ASR}" -n "${TGT_VNET}" --query 'name' -o tsv 2>/dev/null)
  if [[ -n "$VNET_TGT" ]]; then
    echo "  • VNet: $VNET_TGT"
    SUBNET_TGT=$(az network vnet subnet show -g "${TGT_RG_ASR}" --vnet-name "${TGT_VNET}" -n "${TGT_SUBNET}" --query '[name, addressPrefix]' -o tsv 2>/dev/null)
    [[ -n "$SUBNET_TGT" ]] && echo "    • Subnet: $(echo $SUBNET_TGT | awk '{print $1 " (" $2 ")"}')" || echo "    • Subnet: ${TGT_SUBNET} (not found)"
  else
    echo "  • VNet: ${TGT_VNET} (not found)"
  fi
  echo ""
}

cleanup() {
  echo "🧹 Cleanup starting..."
  echo "Target (ASR) Resource Group: $TGT_RG_ASR"
  echo "Target Vault Resource Group: $TGT_RG_VAULT"
  echo "Source Resource Group: $SRC_RG"
  echo "Deleting target ASR resource group ($TGT_RG_ASR)..."
  az group delete -n "$(dequote "$TGT_RG_ASR")" --yes --no-wait || true
  echo "Deleting target vault resource group ($TGT_RG_VAULT)..."
  az group delete -n "$(dequote "$TGT_RG_VAULT")" --yes --no-wait || true
  echo "Deleting source resource group ($SRC_RG)..."
  az group delete -n "$(dequote "$SRC_RG")" --yes --no-wait || true
  if [ -f "${HANDOFF_FILE}" ]; then
    echo "Removing handoff file: ${HANDOFF_FILE}"
    rm -f "${HANDOFF_FILE}"
  fi
  echo "🧹 Cleanup commands issued. Resource deletions are running in background."
}

# --- Command dispatcher ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 {login|init|status|cleanup}"
    exit 1
  fi
  "$@"
fi
