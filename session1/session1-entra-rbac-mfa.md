# 🛠️ Entra ID Governance: RBAC + Conditional Access (MFA)

## 🎯 Objective  
Combine **RBAC** (least-privilege Reader at RG scope) with **Conditional Access (MFA)** to demonstrate identity governance end-to-end.

---

## 🧰 Pre-Reqs
- **Global Administrator** or **Privileged Role Administrator** (for CA/user ops)  
- **Owner** or **User Access Administrator** on the subscription  
- Azure CLI installed (`az version`)  
- Secondary email/phone for the demo user (for MFA registration)

---

## 🛠️ Steps

### 1) Create Resource Group
```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az group create --name entra-demo-rg --location australiaeast
```

### 2) Create Demo User
```bash
TENANT_DOMAIN=$(az rest --method get --url https://graph.microsoft.com/v1.0/domains   --query "value[?isInitial==true].id" -o tsv)

USER_PASSWORD=$(openssl rand -base64 16)
USER_UPN="demo.user@${TENANT_DOMAIN}"

az ad user create   --display-name "Demo User"   --user-principal-name "$USER_UPN"   --password "$USER_PASSWORD"   --force-change-password-next-login true

USER_OBJECT_ID=$(az ad user show --id "$USER_UPN" --query id -o tsv)
echo "UPN: $USER_UPN"; echo "Password: $USER_PASSWORD"; echo "ObjectId: $USER_OBJECT_ID"
```

### 3) Assign Reader Role (Portal *or* CLI)
**Portal:**  
- Resource Group → IAM → Add role assignment → Reader → Demo User  

**CLI alternative:**
```bash
az role assignment create   --assignee "$USER_OBJECT_ID"   --role "Reader"   --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/entra-demo-rg"
```

### 4) Create Conditional Access Policy (Portal)
- Entra admin center → Protection → Conditional Access → + New policy  
- Name: `Require MFA for Demo User`  
- Users: include Demo User  
- Cloud apps: All apps  
- Grant: Require MFA  
- Enable → Save  

---

## 🧪 Validation
1. Login as Demo User → forced password reset + MFA setup  
2. Check RBAC: only `entra-demo-rg`, read-only  
3. Confirm MFA enforced  

---

## 🧹 Cleanup
```bash
az role assignment delete   --assignee "$USER_OBJECT_ID"   --role "Reader"   --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/entra-demo-rg"

az ad user delete --id "$USER_UPN"
az group delete -n entra-demo-rg -y
```

---

## ✅ Key Learnings
- RBAC = scope-limited, least privilege  
- Conditional Access enforces MFA  
- Combined for governance and security
