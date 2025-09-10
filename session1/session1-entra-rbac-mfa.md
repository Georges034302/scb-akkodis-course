# 🛠️ Entra ID Governance: RBAC + Conditional Access (MFA)

## 🎯 Objective
Demonstrate how **identity governance** works by combining:  
- **RBAC** (least privilege Reader role at resource group scope)  
- **Conditional Access policy** (enforce MFA)  

---

## 🧰 Pre-Requisites
- Global Administrator or Privileged Role Administrator in Entra ID  
- Owner or User Access Administrator role on the Azure subscription  
- Azure CLI installed (`az version`)  
- Secondary email/phone for the demo user (to complete MFA)  

---

## 🛠️ Step-by-Step Instructions

### 🔹 Step 1: Create Resource Group
```bash
# Capture subscription ID dynamically
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create resource group
az group create \
  --name entra-demo-rg \
  --location australiaeast
```

---

### 🔹 Step 2: Create Demo User
```bash
# Capture tenant primary domain
TENANT_DOMAIN=$(az rest --method get --url https://graph.microsoft.com/v1.0/domains --query "value[?isInitial==true].id" -o tsv)

# Generate random password
USER_PASSWORD=$(openssl rand -base64 16)

# Define user principal name
USER_UPN="demo.user@${TENANT_DOMAIN}"

# Create the user
az ad user create \
  --display-name "Demo User" \
  --user-principal-name "$USER_UPN" \
  --password "$USER_PASSWORD" \
  --force-change-password-next-login true

# Capture user object ID
USER_OBJECT_ID=$(az ad user show --id "$USER_UPN" --query id -o tsv)

echo "Demo user created:"
echo "  UPN: $USER_UPN"
echo "  Password: $USER_PASSWORD"
echo "  ObjectId: $USER_OBJECT_ID"
```

---

### 🔹 Step 3: Assign Reader Role (Azure Portal)
For accuracy, role assignment should be demonstrated in the **Azure Portal**:  

1. Navigate to **Azure Portal → Resource groups → entra-demo-rg**  
2. Select **Access control (IAM)**  
3. Click **+ Add → Add role assignment**  
4. Choose **Role: Reader**  
5. Assign to **User** → search for `Demo User`  
6. Save  

This ensures learners see how **RBAC works visually** in the Portal.  

---

### 🔹 Step 4: Create Conditional Access Policy (Portal)
Conditional Access cannot be created via `az` today; it requires the **Entra admin portal**.  

1. Go to **Microsoft Entra admin center** → **Protection → Conditional Access**  
2. Click **+ New policy** → name it `Require MFA for Demo User`  
3. **Users** → Include → select `Demo User`  
4. **Cloud apps** → Include → **All cloud apps**  
5. **Grant controls** → select **Require multifactor authentication**  
6. Enable the policy → **On** → Save  

---

## 🧪 Validation

1. **Login as Demo User**  
   - Open **Azure Portal** with `demo.user@<tenant>.onmicrosoft.com`  
   - Enter the generated password (forced to reset)  

2. **RBAC Test**  
   - User should see **only `entra-demo-rg`** in the Portal  
   - No ability to create/delete resources (Reader role only)  

3. **MFA Test**  
   - Conditional Access should enforce MFA during login  

---

## 🧹 Cleanup

```bash
# Remove role assignment (if you want to clean via CLI)
az role assignment delete \
  --assignee "$USER_OBJECT_ID" \
  --role "Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/entra-demo-rg"

# Delete user
az ad user delete --id "$USER_UPN"

# Delete resource group
az group delete -n entra-demo-rg -y
```

---

## ✅ Key Learnings
- RBAC via **Portal** = clear visual of scope + least privilege  
- Conditional Access via **Entra** = real-world MFA enforcement  
- Combined, these demonstrate **identity governance** as part of cloud security  
