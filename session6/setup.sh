#!/bin/bash
set -e

# 1. Login checks
az account show > /dev/null || { echo "Please run az login first."; exit 1; }
gh auth status > /dev/null || { echo "Please run gh auth login first."; exit 1; }

# 2. Variables
APP_NAME="github-actions-policy-demo-$RANDOM"
AZ_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZ_TENANT_ID=$(az account show --query tenantId -o tsv)

# 3. Create app registration and service principal
az ad app create --display-name "$APP_NAME" --enable-id-token-issuance true --sign-in-audience AzureADMyOrg
AZ_CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query '[0].appId' -o tsv)
az ad sp create --id "$AZ_CLIENT_ID"
az role assignment create --assignee "$AZ_CLIENT_ID" --role "Contributor" --scope "/subscriptions/$AZ_SUBSCRIPTION_ID"

# 4. Set GitHub repo secrets
gh secret set AZURE_CLIENT_ID -b"$AZ_CLIENT_ID"
gh secret set AZURE_TENANT_ID -b"$AZ_TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID -b"$AZ_SUBSCRIPTION_ID"

echo "✅ All Azure secrets set in GitHub repo!"
