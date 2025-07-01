# 🛠️ Azure DMS Migration Demo: Azure SQL ➞ Azure SQL

---

## 🎯 Objectives

This hands-on lab demonstrates a **complete online migration** of a SQL Server database from **one Azure SQL Server** to another using **Azure Database Migration Service (DMS)**.

By completing this lab, you will:

- Create a source Azure SQL Server and populate it with data.
- Create a target Azure SQL Server and empty database.
- Provision Azure DMS with required networking.
- Execute the migration using CLI and REST API.
- Validate the migration using `sqlcmd`.

---

## ✅ Prerequisites

Ensure the following are available:

- Active Azure Subscription
- Azure CLI installed and authenticated (`az login`)
- Docker installed (for `sqlcmd` container usage)

---

## 🧱 Step 1: Create Source SQL Server & Populate Database

```bash
# Variables
RESOURCE_GROUP="rg-dms-demo"
LOCATION="australiaeast"
SQL_SOURCE_NAME="sqlsource$RANDOM"
SQL_TARGET_NAME="sqltarget$RANDOM"
SQL_ADMIN_USER="sqladmin"
SQL_ADMIN_PASSWORD="P@ssw0rd$RANDOM"
SQL_DB_NAME="MyDatabase"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create source SQL Server
az sql server create \
  --name $SQL_SOURCE_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --admin-user $SQL_ADMIN_USER \
  --admin-password $SQL_ADMIN_PASSWORD

# Create source DB
az sql db create \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_SOURCE_NAME \
  --name $SQL_DB_NAME \
  --service-objective S0

# Allow Azure services to access
az sql server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_SOURCE_NAME \
  --name AllowAllAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Insert data
docker run --rm mcr.microsoft.com/mssql-tools \
  sqlcmd -S ${SQL_SOURCE_NAME}.database.windows.net \
  -U $SQL_ADMIN_USER -P $SQL_ADMIN_PASSWORD \
  -d $SQL_DB_NAME -Q "CREATE TABLE Users (id INT, name NVARCHAR(50)); INSERT INTO Users VALUES (1,'Alice'), (2,'Bob');"
```

---

## ☁️ Step 2: Prepare Target SQL Server

```bash
# Create target SQL Server
az sql server create \
  --name $SQL_TARGET_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --admin-user $SQL_ADMIN_USER \
  --admin-password $SQL_ADMIN_PASSWORD

# Create empty target DB
az sql db create \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_TARGET_NAME \
  --name $SQL_DB_NAME \
  --service-objective S0

# Allow Azure access
az sql server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_TARGET_NAME \
  --name AllowAllAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

---

## 🌐 Step 3: Provision DMS + VNet

```bash
VNET_NAME="dms-vnet"
SUBNET_NAME="dms-subnet"
DMS_NAME="dms-demo"
PROJECT_NAME="sqlmig-project"
TASK_NAME="sqlmig-task"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create VNet and delegated subnet
az network vnet create \
  --name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --address-prefixes 10.10.0.0/16 \
  --subnet-name $SUBNET_NAME \
  --subnet-prefixes 10.10.1.0/24

# Delegate subnet to Microsoft.DataMigration
az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $SUBNET_NAME \
  --delegations Microsoft.DataMigration/services

# Get subnet ID
SUBNET_ID=$(az network vnet subnet show \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $SUBNET_NAME \
  --query id -o tsv)

# Register provider
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

## 📂 Step 4: Create Project and Task

```bash
# Create migration project
az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataMigration/services/$DMS_NAME/projects/$PROJECT_NAME?api-version=2022-03-30-preview" \
  --body "{\"location\": \"$LOCATION\", \"properties\": {\"sourcePlatform\": \"SQL\", \"targetPlatform\": \"SQLDB\"}}" \
  --headers "Content-Type=application/json"

# Create migration task (CLI does not support Azure SQL ➞ Azure SQL directly)
# Use Portal UI to finish the last step: selecting source/target and starting migration.
```

---

## 🔍 Step 5: Validate in Target Server

```bash
docker run --rm -it mcr.microsoft.com/mssql-tools \
  sqlcmd -S ${SQL_TARGET_NAME}.database.windows.net \
  -U $SQL_ADMIN_USER -P $SQL_ADMIN_PASSWORD \
  -d $SQL_DB_NAME -Q "SELECT * FROM Users;"
```

---

## 🧾 Summary

| Component      | Description                            |
|----------------|----------------------------------------|
| **Source**     | Azure SQL Server (demo data)           |
| **Target**     | Azure SQL Server (empty DB)            |
| **Tool**       | Azure Database Migration Service (DMS) |
| **Method**     | Online migration (Azure ➞ Azure)       |
| **Validation** | `sqlcmd` in Docker                     |

---

🚀 This updated lab provides a 100% Azure-native, network-compatible, and DMS-supported demo without relying on local containers or hybrid setups.
