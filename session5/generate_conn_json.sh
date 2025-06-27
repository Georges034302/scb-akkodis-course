#!/bin/bash

# Load SQL_SA_PASSWORD from .env if available
if [ -f .env ]; then
  source .env
fi

# Prompt for Azure SQL MI name and admin password
read -p "Enter Azure SQL MI name (or press Enter to generate): " SQL_MI_NAME
if [ -z "$SQL_MI_NAME" ]; then
  SQL_MI_NAME="sqlmi$RANDOM"
  echo "Generated SQL MI Name: $SQL_MI_NAME"
fi

read -s -p "Enter Azure SQL MI admin password: " SQL_MI_PASSWORD && echo

# Export to .env for later use
sed -i '/^export SQL_MI_NAME=/d' .env 2>/dev/null
sed -i '/^export SQL_MI_PASSWORD=/d' .env 2>/dev/null
echo "export SQL_MI_NAME=$SQL_MI_NAME" >> .env
echo "export SQL_MI_PASSWORD=$SQL_MI_PASSWORD" >> .env

# Create source.json
cat > source.json <<EOF
{
  "dataSource": "127.0.0.1",
  "authentication": "SqlAuthentication",
  "userName": "sa",
  "password": "$SQL_SA_PASSWORD"
}
EOF

# Create target.json
cat > target.json <<EOF
{
  "dataSource": "${SQL_MI_NAME}.public.australiaeast.database.windows.net",
  "authentication": "SqlAuthentication",
  "userName": "sqladmin",
  "password": "$SQL_MI_PASSWORD"
}
EOF

# Create db-options.json
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

echo "✅ Migration config files created: source.json, target.json, db-options.json"
echo "✅ SQL_MI_NAME and SQL_MI_PASSWORD exported to .env"