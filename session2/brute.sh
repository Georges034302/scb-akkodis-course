#!/bin/bash

RG="Demo-RG"
LOCATION="australiaeast"

echo "🔑 Fetching Key Vault name in $RG..."
KV_NAME=$(az keyvault list --resource-group "$RG" --query "[0].name" -o tsv)
echo "Key Vault Name: $KV_NAME"

echo "🚀 Starting brute force retrieval of 'testsecret' from Key Vault: $KV_NAME..."

for i in {1..10}
do
  echo "🔎 Attempt $i: Retrieving 'testsecret' from $KV_NAME..."
  az keyvault secret show --vault-name "$KV_NAME" --name testsecret || true
done

echo "✅ All brute force retrieval attempts completed."
