# Azure DMS Migration Demo: SQL Server (Docker) to Azure SQL Managed Instance (MI)

## ✅ Objective
Simulate a real-world **online migration** using Azure Database Migration Service (DMS) from an on-premises SQL Server (simulated in Docker) to Azure SQL Managed Instance (MI). All steps use **Azure CLI and JSON configuration files**, designed for GitHub Codespaces.

---

## 🔧 STEP 0: Prepare Docker SQL Server (Source)

```bash
# Set SA password securely
export SQL_SA_PASSWORD='Pass@word1'

# Launch SQL Server 2019 in Docker (GitHub Codespaces)
docker run -e "ACCEPT_EULA=Y" \
           -e "SA_PASSWORD=$SQL_SA_PASSWORD" \
           -p 1433:1433 \
           --name sqlsource \
           -d mcr.microsoft.com/mssql/server:2019-latest

# Create test database and table (optional but recommended)
docker exec -it sqlsource /opt/mssql-tools/bin/sqlcmd \
   -S localhost -U sa -P "$SQL_SA_PASSWORD" \
   -Q "CREATE DATABASE MyDatabase; USE MyDatabase; CREATE TABLE Users (id INT, name NVARCHAR(50)); INSERT INTO Users VALUES (1, 'Alice'), (2, 'Bob');"
```

---

## 🔧 STEP 1: Define Connection Configuration Files

```bash
# source.json
cat <<EOF > source.json
{
  "dataSource": "127.0.0.1",
  "authentication": "SqlAuthentication",
  "userName": "sa",
  "password": "$SQL_SA_PASSWORD"
}
EOF

# Set Azure SQL MI password securely
export SQL_MI_PASSWORD='<REPLACE_WITH_SECURE_PASSWORD>'

# target.json
cat <<EOF > target.json
{
  "dataSource": "<sql-mi-name>.public.australiaeast.database.windows.net",
  "authentication": "SqlAuthentication",
  "userName": "sqladmin",
  "password": "$SQL_MI_PASSWORD"
}
EOF

# db-options.json
cat <<EOF > db-options.json
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

## 🔧 STEP 2: Create Azure DMS Instance, Project, and Task

```bash
# Create Resource Group
az group create --name rg-demo --location australiaeast

# Create Azure DMS instance (ensure subnet is delegated to Microsoft.DataMigration)
az dms create \
  --location australiaeast \
  --name dms-demo \
  --resource-group rg-demo \
  --sku-name "Standard_1vCore" \
  --subnet "/subscriptions/<subscription-id>/resourceGroups/rg-demo/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<subnet-name>"

# Create migration project
az dms project create \
  --resource-group rg-demo \
  --service-name dms-demo \
  --name sqlmig-project \
  --source-platform SQL \
  --target-platform SQLMI

# Create migration task
az dms task create \
  --resource-group rg-demo \
  --project-name sqlmig-project \
  --service-name dms-demo \
  --name sqlmig-task \
  --task-type OnlineMigration \
  --source-connection-json source.json \
  --target-connection-json target.json \
  --database-options-json db-options.json

# Monitor migration status
az dms task show \
  --resource-group rg-demo \
  --project-name sqlmig-project \
  --service-name dms-demo \
  --name sqlmig-task
```

---

## ✅ STEP 3: Post-Migration Validation (Manual or Scripted)

Connect to Azure SQL MI using Azure Data Studio, `sqlcmd`, or `pyodbc`:

```sql
-- Expected SQL queries:
SELECT COUNT(*) FROM Users;
SELECT TOP 5 * FROM Users;
```

To connect using sqlcmd (if public access enabled):
```bash
sqlcmd -S <sql-mi-name>.public.australiaeast.database.windows.net -U sqladmin -P "$SQL_MI_PASSWORD" -d MyDatabase
```

Validate:
- Record count matches source
- Schema integrity preserved
- Row contents migrated as expected

---

## 📌 Expected Outcome

- Docker container simulates SQL Server source
- Azure SQL MI receives data via DMS online migration
- CLI automates full workflow (config, provisioning, execution)
- Manual or scripted query confirms migration success

---

✅ *This lab supports real-world migration scenarios from hybrid environments with rollback planning, audit readiness, and modernization foundations.*

