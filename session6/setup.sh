#!/bin/bash
set -e

# Unset GITHUB_TOKEN if set in this shell (prevents GitHub CLI from using Actions token)
unset GITHUB_TOKEN

# Source admin token from .env
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found! Please create one with export ADMIN_TOKEN=yourPAT"
  exit 1
fi

if [[ -z "$ADMIN_TOKEN" ]]; then
  echo "❌ ADMIN_TOKEN not set in .env!"
  exit 1
fi

# Log out old sessions for a clean start
gh auth logout --hostname github.com || true

# Authenticate gh CLI using your admin PAT
echo "$ADMIN_TOKEN" | gh auth login --with-token --hostname github.com

if gh auth status --hostname github.com --show-token &>/dev/null; then
  echo "✅ gh CLI authenticated for github.com!"
else
  echo "❌ gh CLI authentication failed!"
  exit 1
fi



# --- 3. Variables ---
APP_NAME="github-actions-policy-demo-$RANDOM"
AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZ_TENANT_ID=$(az account show --query tenantId -o tsv)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

echo "🔧 Creating Azure AD app registration: $APP_NAME ..."
az ad app create --display-name "$APP_NAME" --enable-id-token-issuance true --sign-in-audience AzureADMyOrg

AZ_CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query '[0].appId' -o tsv)

echo "🔧 Creating service principal for AppId: $AZ_CLIENT_ID ..."
az ad sp create --id "$AZ_CLIENT_ID"

echo "🔧 Assigning Contributor role to the service principal ..."
az role assignment create --assignee "$AZ_CLIENT_ID" --role "Contributor" --scope "/subscriptions/$AZ_SUBSCRIPTION_ID"

echo "🔧 Adding federated credential for OIDC authentication from GitHub Actions ..."
az ad app federated-credential create --id "$AZ_CLIENT_ID" \
  --parameters '{
    "name": "github-actions-federated-credential",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$REPO"':ref:refs/heads/main",
    "description": "GitHub Actions OIDC federated credential for main branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

echo "🔧 Setting GitHub repo secrets ..."
gh secret set AZURE_CLIENT_ID -b"$AZ_CLIENT_ID"
gh secret set AZURE_TENANT_ID -b"$AZ_TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID -b"$AZ_SUBSCRIPTION_ID"


echo ""
echo "✅ All Azure OIDC secrets set in your GitHub repo!"
echo "--------------------------------------------------"
echo "AZURE_CLIENT_ID: $AZ_CLIENT_ID"
echo "AZURE_TENANT_ID: $AZ_TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $AZ_SUBSCRIPTION_ID"
echo "OIDC Federated Credential created for $REPO"
echo ""

echo "🔧 Assigning Contributor role to the service principal ..."
az role assignment create \
  --assignee "$AZ_CLIENT_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$AZ_SUBSCRIPTION_ID"

echo "🔧 Assigning Resource Policy Contributor role to the service principal ..."
az role assignment create \
  --assignee "$AZ_CLIENT_ID" \
  --role "Resource Policy Contributor" \
  --scope "/subscriptions/$AZ_SUBSCRIPTION_ID"
  
echo ""
echo "You are now fully ready to run passwordless Azure deployments from GitHub Actions!"
