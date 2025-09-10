#!/bin/bash
set -euo pipefail

# Unset Actions token if present (avoid gh using it)
unset GITHUB_TOKEN || true

# ---- Auth materials ----
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
else
  echo "ERROR: .env not found. Create it with: export ADMIN_TOKEN=yourPAT" >&2
  exit 1
fi
: "${ADMIN_TOKEN:?ERROR: ADMIN_TOKEN not set in .env}"

# ---- GitHub CLI auth ----
gh auth logout --hostname github.com >/dev/null 2>&1 || true
echo "$ADMIN_TOKEN" | gh auth login --with-token --hostname github.com >/dev/null
gh auth status --hostname github.com --show-token >/dev/null || { echo "ERROR: gh auth failed"; exit 1; }

# ---- Azure context ----
az account show >/dev/null 2>&1 || { echo "ERROR: run 'az login' first"; exit 1; }
AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZ_TENANT_ID=$(az account show --query tenantId -o tsv)
az account set --subscription "$AZ_SUBSCRIPTION_ID"

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
APP_NAME="github-actions-policy-demo-${RANDOM}"

# ---- App registration (idempotent) ----
EXISTING_APP_ID=$(az ad app list --display-name "$APP_NAME" --query '[0].appId' -o tsv)
if [[ -z "${EXISTING_APP_ID}" ]]; then
  echo "Creating app: $APP_NAME"
  az ad app create --display-name "$APP_NAME" --enable-id-token-issuance true --sign-in-audience AzureADMyOrg --only-show-errors >/dev/null
  AZ_CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query '[0].appId' -o tsv)
else
  AZ_CLIENT_ID="$EXISTING_APP_ID"
  echo "App exists: $APP_NAME ($AZ_CLIENT_ID)"
fi

# ---- Service principal (idempotent) ----
if ! az ad sp show --id "$AZ_CLIENT_ID" --only-show-errors >/dev/null 2>&1; then
  echo "Creating service principal for $AZ_CLIENT_ID"
  az ad sp create --id "$AZ_CLIENT_ID" --only-show-errors >/dev/null
fi

# ---- Federated credential (idempotent) ----
FC_NAME="github-actions-federated-credential"
if ! az ad app federated-credential list --id "$AZ_CLIENT_ID" --query "[?name=='$FC_NAME']" -o tsv | grep -q .; then
  echo "Adding federated credential for repo $REPO (main)"
  az ad app federated-credential create --id "$AZ_CLIENT_ID" --parameters "{
    \"name\": \"$FC_NAME\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$REPO:ref:refs/heads/main\",
    \"description\": \"GitHub Actions OIDC federated credential for main branch\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" >/dev/null
fi

# ---- Role assignments (idempotent) ----
assign_role() {
  local role="$1"
  local scope="/subscriptions/$AZ_SUBSCRIPTION_ID"
  if ! az role assignment list --assignee "$AZ_CLIENT_ID" --role "$role" --scope "$scope" --query "[0]" -o tsv | grep -q .; then
    echo "Assigning role: $role"
    az role assignment create --assignee "$AZ_CLIENT_ID" --role "$role" --scope "$scope" --only-show-errors >/dev/null
  fi
}
assign_role "Contributor"
assign_role "Resource Policy Contributor"

# ---- Repo secrets ----
gh secret set AZURE_CLIENT_ID -b"$AZ_CLIENT_ID" >/dev/null
gh secret set AZURE_TENANT_ID -b"$AZ_TENANT_ID" >/dev/null
gh secret set AZURE_SUBSCRIPTION_ID -b"$AZ_SUBSCRIPTION_ID" >/dev/null

# ---- Propagation wait (short) ----
echo "Waiting 15s for role assignment propagation..."
sleep 15

cat <<EOF

OIDC ready for GitHub Actions.

AZURE_CLIENT_ID:        $AZ_CLIENT_ID
AZURE_TENANT_ID:        $AZ_TENANT_ID
AZURE_SUBSCRIPTION_ID:  $AZ_SUBSCRIPTION_ID
Federated Credential:   $FC_NAME (repo: $REPO, branch: main)

Use these in your workflow with azure/login@v1.
EOF
