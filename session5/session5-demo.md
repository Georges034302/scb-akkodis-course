# 🛠️ Azure DMS Migration Demo: Azure SQL ➞ Azure SQL Database (Offline)

---

<table>
<tr>
<td>

## 🎯 Objectives

This hands-on lab demonstrates a **complete offline migration** of a SQL Server database from one **Azure SQL Server (PaaS)** to another using **Azure Database Migration Service (DMS)**.

By completing this lab, you will:

- Create a source Azure SQL Server and populate it with data.
- Create a target Azure SQL Server and empty database.
- Provision Azure DMS with required networking.
- Execute the migration using Azure Portal + REST API.
- Validate the migration using `sqlcmd`.

</td>
<td>

<img src="dms.png" alt="DMS Diagram" width="400"/>

</td>
</tr>
</table>

---

## ✅ Prerequisites

Ensure the following are available:

- Active Azure Subscription
- Azure CLI installed and authenticated (`az login`)
- Docker installed (for `sqlcmd` container usage)

---

## 🔧 Step 0: Set Required Variables

```bash
# Azure settings
RESOURCE_GROUP="rg-dms-demo"
LOCATION="australiaeast"
VNET_NAME="dms-vnet"
SUBNET_NAME="dms-subnet"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# SQL Server & DB
SQL_SOURCE_NAME="sqlsource$RANDOM"
SQL_TARGET_NAME="sqltarget$RANDOM"
SQL_ADMIN_USER="sqladmin"
SQL_ADMIN_PASSWORD="P@ssw0rd$RANDOM"
SQL_DB_NAME="sqldb$(date +%s%N | sha256sum | head -c 8)"

# Derived/compatibility
SQL_SA_USER="$SQL_ADMIN_USER"
SQL_SA_PASSWORD="$SQL_ADMIN_PASSWORD"

# DMS setup
DMS_NAME="dms-demo"
PROJECT_NAME="sqlmig-project"
```

---

## 🌐 Step 1: Provision Networking (VNet and Subnet)

```bash
# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create VNet + Subnet
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --location "$LOCATION" \
  --address-prefix 10.10.0.0/16 \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix 10.10.1.0/24

# Get subnet ID
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --query "id" -o tsv)
```

---

## 🧱 Step 2: Create Source SQL Server & Populate Data

```bash
# Create source SQL Server
az sql server create \
  --name "$SQL_SOURCE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$SQL_ADMIN_USER" \
  --admin-password "$SQL_ADMIN_PASSWORD"

# Create DB
az sql db create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SOURCE_NAME" \
  --name "$SQL_DB_NAME" \
  --service-objective S0

# Allow firewall access
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_SOURCE_NAME" \
  --name AllowAllAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Insert data
docker run --rm mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd -S "$SQL_SOURCE_NAME.database.windows.net" \
  -U "$SQL_ADMIN_USER" -P "$SQL_ADMIN_PASSWORD" \
  -d "$SQL_DB_NAME" \
  -Q "CREATE TABLE Users (id INT, name NVARCHAR(50)); INSERT INTO Users VALUES (1,'Alice'), (2,'Bob');"

# Validate data
docker run --rm mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd -S "$SQL_SOURCE_NAME.database.windows.net" \
  -U "$SQL_ADMIN_USER" -P "$SQL_ADMIN_PASSWORD" \
  -d "$SQL_DB_NAME" \
  -Q "SELECT * FROM Users;"
```

---

## ☁️ Step 3: Create Target SQL Server

```bash
# Create target SQL Server
az sql server create \
  --name "$SQL_TARGET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --admin-user "$SQL_ADMIN_USER" \
  --admin-password "$SQL_ADMIN_PASSWORD"

# Create empty DB
az sql db create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_TARGET_NAME" \
  --name "$SQL_DB_NAME" \
  --service-objective S0

# Allow firewall access
az sql server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --server "$SQL_TARGET_NAME" \
  --name AllowAllAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

---

## 🛡️ Step 4: Register Provider + Provision DMS

```bash
# Register DMS provider
az provider register --namespace Microsoft.DataMigration --wait

# Create DMS instance
az dms create \
  --location $LOCATION \
  --name $DMS_NAME \
  --resource-group $RESOURCE_GROUP \
  --sku-name Standard_2vCores \
  --subnet $SUBNET_ID
```

---

## 📂 Step 5: Create Migration Project

```bash
# Create migration project (Target = SQLDB)
az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataMigration/services/$DMS_NAME/projects/$PROJECT_NAME?api-version=2022-03-30-preview" \
  --body "{\"location\": \"$LOCATION\", \"properties\": {\"sourcePlatform\": \"SQL\", \"targetPlatform\": \"SQLDB\"}}" \
  --headers "Content-Type=application/json"

# Verify project
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataMigration/services/$DMS_NAME/projects?api-version=2022-03-30-preview" \
  --query "value[].name" -o tsv
```

---

## 🚧 Step 6: Complete Migration in Azure Portal

> Azure CLI does **not** support creating the final SQL ➞ SQL migration task.

### 👉 Use Azure Portal:

1. Go to **DMS instance → Project → + New Activity**
2. Choose **Offline data migration**
3. Fill in:
   - Source: `$SQL_SOURCE_NAME.database.windows.net`
   - Target: `$SQL_TARGET_NAME.database.windows.net`
   - DB name: `$SQL_DB_NAME`
4. Use `SQL_ADMIN_USER` / `SQL_ADMIN_PASSWORD`
5. Start migration and monitor progress

---

## ✅ Step 7: Validate Target Data

```bash
docker run --rm mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd -S "$SQL_TARGET_NAME.database.windows.net" \
  -U "$SQL_ADMIN_USER" -P "$SQL_ADMIN_PASSWORD" \
  -d "$SQL_DB_NAME" \
  -Q "SELECT * FROM Users;"
```

---

## 📘 Summary

| Item           | Value                                 |
|----------------|----------------------------------------|
| **Source**     | Azure SQL Database                    |
| **Target**     | Azure SQL Database                    |
| **Tool**       | Azure Database Migration Service (DMS) |
| **Mode**       | Offline                                |
| **UI Used**    | Azure CLI + Azure Portal               |
| **Validation** | Docker `sqlcmd` query check            |

