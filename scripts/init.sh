#!/bin/bash
set -e

check() {
  printf "[OK] %s\n" "$1"
}

echo "Starting environment initialization..."

# Check if docker-compose.yml exists
if [ -f docker-compose.yml ]; then
  check "docker-compose.yml found"
else
  echo "docker-compose.yml not found. Initialization aborted."
  exit 1
fi

# Generate .env file with absolute paths
ENV_FILE=".env"
PWD_ABS="$(pwd)"

if [ -f "$ENV_FILE" ]; then
  read -p ".env already exists. Overwrite it? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    check "skipped .env generation"
  else
    generate_env=true
  fi
else
  generate_env=true
fi

if [ "$generate_env" = true ]; then
  cat > "$ENV_FILE" <<EOF
PHP_VERSION=php84
SQL_VERSION=mysql84
SQL_PORT=3306
SQL_ROOT_PWD=root
SQL_HOST=${PWD_ABS}/var/db
WEB_HOST=${PWD_ABS}/app
WEB_STORAGE=${PWD_ABS}/var/temp
HTTP_PORT=80
HTTPS_PORT=443
PMA_PORT=8080
EOF

  check ".env file generated with absolute paths"
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

echo "Initialization complete!"
