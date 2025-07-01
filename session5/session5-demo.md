# 🛠️ Azure DMS Migration Demo: SQL Server (Docker) ➞ Azure SQL Managed Instance

---

## 🎯 Objectives

This hands-on lab demonstrates a **complete online migration** of a SQL Server database (simulated in Docker) to an **Azure SQL Managed Instance (MI)** using **Azure Database Migration Service (DMS)**.

By completing this lab, you will:

- Simulate an on-premises SQL Server using Docker.
- Create and populate a sample database (`MyDatabase`).
- Generate JSON connection files dynamically using variables.
- Provision Azure DMS and configure an online migration task.
- Execute the migration from Docker-hosted SQL to Azure SQL MI.
- Validate the migration using `sqlcmd`.

---

## ✅ Prerequisites

Ensure the following are available:

- Active Azure Subscription
- Azure SQL Managed Instance (provisioned and publicly accessible)
- Docker installed (GitHub Codespaces or local)
- Azure CLI installed and authenticated (`az login`)

---

## 🧱 Step 1: Simulate On-Prem SQL Server (Docker)

### 🐳 Run SQL Server in Docker

#### 🌐 Create Docker network
```bash
docker network create sqlnet
```

#### 🐳 Start SQL Server
```bash
docker run -d \
  --name sqlsource \
  --network sqlnet \
  -e "ACCEPT_EULA=Y" \
  -e "SA_PASSWORD=$SQL_SA_PASSWORD" \
  mcr.microsoft.com/mssql/server:2019-latest
```

#### 📦 Create the database
```bash
docker run --rm \
  --network sqlnet \
  mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd \
  -S sqlsource -U sa -P "$SQL_SA_PASSWORD" -Q "CREATE DATABASE MyDatabase;"
```

#### 🛠️ Create table + insert data inside MyDatabase
```bash
docker run --rm \
  --network sqlnet \
  mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd \
  -S sqlsource -U sa -P "$SQL_SA_PASSWORD" -d MyDatabase -Q "
    CREATE TABLE Users (id INT, name NVARCHAR(50));
    INSERT INTO Users VALUES (1, 'Alice'), (2, 'Bob');"
```

#### 🧪 Post On-prem SQL Simulation Test

```bash
docker run --rm \
  --network sqlnet \
  mcr.microsoft.com/mssql-tools \
  /opt/mssql-tools/bin/sqlcmd \
  -S sqlsource -U sa -P "$SQL_SA_PASSWORD" -d MyDatabase -Q "SELECT * FROM Users;"
```

---

## 🗂️ Step 2: Generate JSON Connection Files

### 🧾 Create `source.json`, `target.json`, and `db-options.json`

```bash
SQL_MI_NAME="sqlmi$RANDOM"
echo "Generated SQL MI Name: $SQL_MI_NAME"

read -s -p "Enter Azure SQL MI admin password: " SQL_MI_PASSWORD && echo

cat > source.json <<EOF
{
  "dataSource": "127.0.0.1",
  "authentication": "SqlAuthentication",
  "userName": "sa",
  "password": "$SQL_SA_PASSWORD"
}
EOF

cat > target.json <<EOF
{
  "dataSource": "${SQL_MI_NAME}.public.australiaeast.database.windows.net",
  "authentication": "SqlAuthentication",
  "userName": "sqladmin",
  "password": "$SQL_MI_PASSWORD"
}
EOF

cat > db-options.json <<EOF
{
  "selectedDatabases": [
    {
      "name": "MyDatabase",
      "tableMap": "*"
    }
  ]
}
EOF
```

---

## ☁️ Step 3: Provision Azure DMS and Configure Migration

#### 🔧 Set Environment Variables

```bash
RESOURCE_GROUP="rg-dms-demo"
VNET_NAME="dms-vnet"
SUBNET_NAME="dms-subnet"
LOCATION="australiaeast"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

#### 📁 Create Resource Group

```bash
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

#### 🛡️ Register required provider
```bash
az provider register --namespace Microsoft.DataMigration
```

#### 🌐 Create Virtual Network and Subnet

```bash
az network vnet create \
  --name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --address-prefixes 10.10.0.0/16 \
  --subnet-name $SUBNET_NAME \
  --subnet-prefixes 10.10.1.0/24
```

#### 🆔 Get Subnet Resource ID

```bash
SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"
```

#### 🏗️ Create Azure DMS Instance

```bash
az dms create \
  --location "$LOCATION" \
  --name dms-demo \
  --resource-group "$RESOURCE_GROUP" \
  --sku-name "Standard_2vCores" \
  --subnet "$SUBNET_ID"
```

#### 📂 Create DMS project using REST API

```bash
az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataMigration/services/$DMS_NAME/projects/$PROJECT_NAME?api-version=2022-03-30-preview" \
  --body "{\"location\": \"$LOCATION\", \"properties\": {\"sourcePlatform\": \"SQL\", \"targetPlatform\": \"SQLDB\"}}" \
  --headers "Content-Type=application/json"
```

#### 🚚 Create DMS Migration Task

```bash
az datamigration sql-db create \
  --resource-group "$RESOURCE_GROUP" \
  --sqldb-instance-name "$SQL_SERVER_NAME" \
  --target-db-name "$SQL_DB_NAME" \
  --migration-service "$MIGRATION_SERVICE_ID" \
  --scope "$SQL_SCOPE" \
  --source-database-name "$SQL_DB_NAME" \
  --source-sql-connection authentication="SqlAuthentication" data-source="sqlsource" user-name="$SQL_SA_USER" password="$SQL_SA_PASSWORD" encrypt-connection=true trust-server-certificate=true \
  --target-sql-connection authentication="SqlAuthentication" data-source="$SQL_SERVER_NAME.database.windows.net" user-name="$SQL_MI_ADMIN_USER" password="$SQL_MI_PASSWORD" encrypt-connection=true trust-server-certificate=true
```

---

## 🔍 Step 4: Post Migration Testing (Validate Migration Using `sqlcmd`)

#### 🚪 Login to Azure SQL Managed Instance

```bash
docker run --rm -it mcr.microsoft.com/mssql-tools \
  sqlcmd -S ${SQL_MI_NAME}.public.australiaeast.database.windows.net \
  -U sqladmin \
  -P "$SQL_MI_PASSWORD" \
  -d MyDatabase
```

#### 📋 Run These Queries in `sqlcmd`

```sql
SELECT COUNT(*) FROM Users;
GO

SELECT TOP 5 * FROM Users;
GO

EXIT
```

### ✅ Validation Checklist

| Item                 | Expected Outcome   |
|----------------------|--------------------|
| Table `Users` exists | ✅                 |
| Row count            | 2 rows             |
| Data consistency     | Alice, Bob present |
| Schema match         | Same as source     |

---

## 🧾 Summary

| Component      | Description                            |
|----------------|----------------------------------------|
| **Source**     | SQL Server 2019 running in Docker      |
| **Target**     | Azure SQL Managed Instance             |
| **Tool**       | Azure Database Migration Service (DMS) |
| **Method**     | Online migration                       |
| **Validation** | `sqlcmd` CLI (Docker)                  |

---

🚀 This lab simulates real-world **hybrid cloud migration** using **Azure-native services** with built-in support for **online migrations**. For more complex scenarios, consider exploring **Azure Migrate** and other advanced features of **Azure DMS**.