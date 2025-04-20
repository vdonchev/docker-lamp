#!/bin/bash
set -e

check() {
  printf "✔ %s\\n" "$1"
}

echo "🔧 Starting environment initialization..."

# Check if docker-compose.yml exists
if [ -f docker-compose.yml ]; then
  check "docker-compose.yml found"
else
  echo "✖ docker-compose.yml not found. Initialization aborted."
  exit 1
fi

# Check for .env file
if [ ! -f .env ]; then
  if [ -f example.env ]; then
    cp example.env .env
    check ".env created from example.env"
  else
    echo "✖ .env and example.env missing"
    exit 1
  fi
else
  check ".env already exists"
fi

# Fix executable permissions
find scripts -type f -name "*.sh" -exec chmod +x {} \;
check "script permissions fixed"

# Create required directories
mkdir -p var/log config/apache/vhosts/generated
check "required directories created (or already exist)"

# Create missing config files
declare -A files_to_create=(
  ["config/apache/vhosts/https.local.conf"]="# Local HTTPS Apache config (auto-created)"
  ["config/php/conf.d/php.local.ini"]="; Local PHP overrides (auto-created)"
  ["config/projects/sites.local.list"]="# List of project domains (auto-created)"
  ["config/sql/my.local.cnf"]="# Local MySQL config (auto-created)"
)

for file in "${!files_to_create[@]}"; do
  if [ ! -f "$file" ]; then
    mkdir -p "$(dirname "$file")"
    echo "${files_to_create[$file]}" > "$file"
    check "created $file"
  else
    check "$file already exists"
  fi
done

# Generate SSL certificate if needed
CERT="config/apache/ssl/dev.crt"
KEY="config/apache/ssl/dev.key"
if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
  ./scripts/generate-multidomain-ssl.sh
  check "SSL certificate generated"
else
  check "SSL certificate already exists"
fi

echo "Initialization complete. You can now run: docker compose up"
