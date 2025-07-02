# 🛠️ Azure DMS Migration Demo: Azure SQL ➞ Azure SQL Database (Offline)

---

<table>
<tr>
<td>

## 🎯 Objectives

This hands-on lab demonstrates a **complete offline migration** of a SQL Server database from one **Azure SQL Server (PaaS)** to another using **Azure Database Migration Service (DMS)**.

By completing this lab, you will:

- Create a source Azure SQL Server and populate it with data.
- Create a target Azure SQL Server VM and empty database.
- Provision Azure DMS with required networking.
- Execute the migration using Azure Portal + REST API.
- Validate the migration using `sqlcmd`.

</td>
<td>

<img src="https://github.com/user-attachments/assets/cef9c11e-8c64-4e3d-b10e-a8ec0069c85c" alt="DMS Diagram" width="900"/>

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
# Set Azure region and resource group
LOCATION="australiaeast"
RESOURCE_GROUP="rg-dms-demo"

# Set SQL admin username and randomized password
ADMIN_USER="sqladmin"
ADMIN_PASSWORD="P@ssw0rd$RANDOM"

# Set source SQL Server and database names (randomized for uniqueness)
SQL_SOURCE_SERVER="sqlsource$RANDOM"
SQL_SOURCE_DB="sqldb$(date +%s%N | sha256sum | head -c 8)"

# Set networking names
VNET_NAME="dms-vnet"
SUBNET_NAME="dms-subnet"

# Set target SQL VM name and image
SQL_VM_NAME="sqlvmdemo$RANDOM"
SQL_IMAGE="MicrosoftSQLServer:sql2019-ws2022:sqldev:15.0.250227"

# Set storage account, container, and backup folder for SQL backups
STORAGE_NAME="sourcesqlbackup$RANDOM"
STORAGE_CONTAINER="sqlcontainerbackup$RANDOM"
BACKUP_FOLDER="backupfolder$(date +%Y%m%d)"

# Get current Azure subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

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
  --admin-user "$ADMIN_USER" \
  --admin-password "$ADMIN_PASSWORD"

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
  -U "$ADMIN_USER" -P "$ADMIN_PASSWORD" \
  -d "$SQL_DB_NAME" \
  -Q "CREATE TABLE Users (id INT, name NVARCHAR(50)); INSERT INTO Users VALUES (1,'Alice'), (2,'Bob');"

# Validate data
docker run --rm mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd -S "$SQL_SOURCE_NAME.database.windows.net" \
  -U "$ADMIN_USER" -P "$ADMIN_PASSWORD" \
  -d "$SQL_DB_NAME" \
  -Q "SELECT * FROM Users;"
```

---

## ☁️ Step 3: Deploy Target SQL Server VM (SQL Server VM for Migration)

```bash
# --- Prompt for password (hidden input) ---
read -s -p "🔑 Enter SQL VM admin password: " ADMIN_PASSWORD
echo

# --- Create VM ---
az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$SQL_VM_NAME" \
  --image "$SQL_IMAGE" \
  --admin-username "$ADMIN_USER" \
  --admin-password "$ADMIN_PASSWORD" \
  --size Standard_D2s_v3 \
  --public-ip-sku Standard \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME"

# --- Register as SQL VM in Azure ---
az sql vm create \
  --name "$SQL_VM_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --license-type PAYG \
  --image-sku Developer \
  --sql-mgmt-type Full

# --- Open SQL TCP port 1433 (optional, for DMS or remote access) ---
az vm open-port --resource-group "$RESOURCE_GROUP" --name "$SQL_VM_NAME" --port 1433

```

## ☁️ Step 4: Setup Storage Blob for SQL backups

```bash
# --- Create storage account ---
az storage account create \
  --name "$STORAGE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS
echo "✅ Storage account created."

# --- Create blob container ---
az storage container create \
  --account-name "$STORAGE_NAME" \
  --name "$STORAGE_CONTAINER" \
  --auth-mode login
echo "✅ Blob container created."
```
#### 🔒 Add Role Permission to upload files

In the Storage account IAM:

- Select ➕ Add Role Assignment
- Search and Select `Storage Blob Data Contributor`
- Assign the role to (service principle, user, group)

#### 🧑‍🚀  Upload placeholder to make backup folder visible
```bash
# --- Upload placeholder to make backup folder visible ---
az storage blob upload \
  --account-name "$STORAGE_NAME" \
  --container-name "$STORAGE_CONTAINER" \
  --name "$BACKUP_FOLDER/placeholder.txt" \
  --file /dev/null \
  --auth-mode login
echo "✅ Placeholder file uploaded."

```

---

## 🛡️ Step 5: Register Provider + Provision DMS

#### 🛠️ DMS Instance Creation and Project Setup (Azure Portal)

Follow these steps if the CLI-based creation of the Azure Database Migration Service (DMS) is delayed or failing:

1. Go to the Azure Portal: Database Migration Service
  - Select:  `➕ Create`
2. When prompted, set:
  - **Source server type:** SQL Server
  - **Target server type:** Azure SQL Viratual Machine
  - **Backup file storage:** Blob Storage
  - **Migration Mode:** Offline
  - **Name:** `$DMS_NAME`
3. Select the DMS: `$DMS_NAME`:
  - **Source Details:**
    - **Is your source SQL Server instance tracked in Azure?:** `Yes`  
    - **Resource Group:** `$RESOURCE_GROUP`
    - **Region:** `$LOCATION`
    - **SQL Server Instance:** `$SQL_VM_NAME`
  - **Select migration target:**
    - **Resource Group:** `$RESOURCE_GROUP`
    - **Target SQL Virtual Machine:** `$SQL_VM_NAME`
  - **Data source configuration:**
    - **Resource Group:** `$RESOURCE_GROUP`
    - **Storage account:** `$STORAGE_NAME`
    - **Storage conatiner:** `$STORAGE_CONTAINER`
    - **Storage conatiner:** `$SBACKUP_FOLDER`
    - **Last backup file:** `placeholder.bak`
    - **Target database:** `$SQL_DB_NAME`
4. Next ➡️ Database migration summary
5. **Start Migration**

---

## ✅ Step 7: Validate Target Data

```bash
docker run --rm mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd -S "$SQL_VM_NAME" \
  -U "$ADMIN_USER" -P "$ADMIN_PASSWORD" \
  -d "$SQL_DB_NAME" \
  -Q "SELECT * FROM Users;"
```

---

## 📘 Summary

| Item           | Value                                 |
|----------------|----------------------------------------|
| **Source**     | Azure SQL Database                    |
| **Target**     | Azure SQL VM                    |
| **Tool**       | Azure Database Migration Service (DMS) |
| **Mode**       | Offline                                |
| **UI Used**    | Azure CLI + Azure Portal               |
| **Validation** | Docker `sqlcmd` query check            |

