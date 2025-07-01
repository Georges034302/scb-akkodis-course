#!/bin/bash
set -e

echo "⚙️  Generating Azure SQL MI migration config files..."
sleep 2

# Load .env if available
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found. Run ./init_env.sh first."
  exit 1
fi

# Validate required environment variables
for var in SQL_SA_USER SQL_SA_PASSWORD SQL_MI_NAME SQL_MI_PASSWORD SQL_DB_NAME; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing $var in .env. Run ./init_env.sh first."
    exit 1
  fi
done

# Generate source.json
echo "📝 Creating source.json..."
cat > source.json <<EOF
{
  "dataSource": "sqlsource",
  "authentication": "SqlAuthentication",
  "userName": "$SQL_SA_USER",
  "password": "$SQL_SA_PASSWORD"
}
EOF

# Generate target.json
echo "📝 Creating target.json..."
cat > target.json <<EOF
{
  "dataSource": "${SQL_MI_NAME}.public.australiaeast.database.windows.net",
  "authentication": "SqlAuthentication",
  "userName": "sqladmin",
  "password": "$SQL_MI_PASSWORD"
}
EOF

# Generate db-options.json
echo "📝 Creating db-options.json..."
cat > db-options.json <<EOF
{
  "selectedDatabases": [
    {
      "name": "$SQL_DB_NAME",
      "tableMap": "*"
    }
  ]
}
EOF

echo "✅ Migration config files ready: source.json, target.json, db-options.json"

# Add these files to .gitignore
echo "🔒 Ensuring JSON files are in .gitignore..."
for f in source.json target.json db-options.json; do
  grep -qxF "$f" .gitignore || echo "$f" >> .gitignore
done
echo "✅ JSON files added to .gitignore"
