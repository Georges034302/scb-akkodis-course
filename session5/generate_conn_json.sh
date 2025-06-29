#!/bin/bash

echo "⚙️  Generating Azure SQL MI migration config files..."
sleep 2
# Load SQL_SA_PASSWORD from .env if available
if [ -f .env ]; then
  source .env
fi

# Prompt for Azure SQL MI name and admin password
if [ -z "$SQL_MI_NAME" ]; then
  SQL_MI_NAME="sqlmi$RANDOM"
  echo "🆕 Generated SQL MI Name: $SQL_MI_NAME"
fi

# Generate a random strong password for Azure SQL MI admin
SQL_MI_PASSWORD="P@ssw0rd$(date +%s%N | sha256sum | head -c 12)"
echo "🔑 Generated Azure SQL MI admin password: $SQL_MI_PASSWORD"

# Export to .env for later use
sed -i '/^export SQL_MI_NAME=/d' .env 2>/dev/null
sed -i '/^export SQL_MI_PASSWORD=/d' .env 2>/dev/null
echo "export SQL_MI_NAME=$SQL_MI_NAME" >> .env
echo "export SQL_MI_PASSWORD=$SQL_MI_PASSWORD" >> .env
echo "💾 Exported SQL_MI_NAME and SQL_MI_PASSWORD to .env"

# Create source.json
echo "📝 Creating source.json..."
cat > source.json <<EOF
{
  "dataSource": "127.0.0.1",
  "authentication": "SqlAuthentication",
  "userName": "sa",
  "password": "$SQL_SA_PASSWORD"
}
EOF
echo "✅ source.json created."

# Create target.json
echo "📝 Creating target.json..."
cat > target.json <<EOF
{
  "dataSource": "${SQL_MI_NAME}.public.australiaeast.database.windows.net",
  "authentication": "SqlAuthentication",
  "userName": "sqladmin",
  "password": "$SQL_MI_PASSWORD"
}
EOF
echo "✅ target.json created."

# Create db-options.json
echo "📝 Creating db-options.json..."
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
echo "✅ db-options.json created."

echo "🎉 Migration config files ready: source.json, target.json, db-options.json"
echo "✅ SQL_MI_NAME and SQL_MI_PASSWORD exported to .env"
# Protect JSON files from being committed
echo "🔒 Adding JSON files to .gitignore..."
for f in source.json target.json db-options.json; do
  grep -qxF "$f" .gitignore || echo "$f" >> .gitignore
done
sleep 2
echo "✅ JSON files added to .gitignore (prevent accidental commit)"
