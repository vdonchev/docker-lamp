#!/bin/bash

# Absolute path to the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Base project directory (assumed to be the parent of the scripts directory)
BASE_DIR="$(realpath "$SCRIPT_DIR/..")"

# Paths
PROJECTS_DIR="$BASE_DIR/config/projects"
VHOSTS_DIR="$BASE_DIR/config/apache/vhosts"
SSL_DIR="$BASE_DIR/config/apache/ssl"
OUTPUT_FILE="$VHOSTS_DIR/generated/httpd.conf"

LIST_MAIN="$PROJECTS_DIR/list.txt"
LIST_LOCAL="$PROJECTS_DIR/list.local.txt"

DEFAULT_VHOSTS="$VHOSTS_DIR/httpd.default.conf"
LOCAL_VHOSTS="$VHOSTS_DIR/httpd.local.conf"

CRT_FILE="$SSL_DIR/dev.crt"
KEY_FILE="$SSL_DIR/dev.key"

# Check if SSL certificates exist
SSL_ENABLED=false
if [[ -f "$CRT_FILE" && -f "$KEY_FILE" ]]; then
  SSL_ENABLED=true
fi

# Create (and empty) a temporary file for dynamic vhost entries
TMP_VHOSTS="$(mktemp)"

# Truncate the temporary vhosts file (no-op + redirect)
: > "$TMP_VHOSTS"

# Read the project list files
read_projects() {
  local file="$1"
  [[ -f "$file" ]] || return

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue

    # Validate format: domain,path
    if [[ ! "$line" =~ ^[[:space:]]*[^,#[:space:]][^,]*,[^[:space:]].*$ ]]; then
      echo "⚠️  Invalid line format, skipping: $line"
      continue
    fi

    IFS=',' read -r domain path <<< "$line"
    [[ -z "$domain" || -z "$path" ]] && continue

    generate_http_vhost "$domain" "$path"
    if $SSL_ENABLED; then
      generate_https_vhost "$domain" "$path"
    fi
  done < "$file"
}

# Generate HTTP vhost entry
generate_http_vhost() {
  local domain="$1"
  local path="$2"

  cat <<EOF >> "$TMP_VHOSTS"
<VirtualHost *:80>
    ServerName $domain
    DocumentRoot $path

    <Directory $path>
        Options +Indexes
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /dev/stderr
    CustomLog /dev/stdout combined
</VirtualHost>

EOF
}

# Generate HTTPS vhost entry
generate_https_vhost() {
  local domain="$1"
  local path="$2"

  cat <<EOF >> "$TMP_VHOSTS"
<VirtualHost *:443>
    ServerName $domain
    DocumentRoot $path

    <Directory $path>
        Options +Indexes
        AllowOverride All
        Require all granted
    </Directory>

	  SSLEngine on
    SSLCertificateFile "/etc/ssl/lamp/dev.crt"
    SSLCertificateKeyFile "/etc/ssl/lamp/dev.key"

    ErrorLog /dev/stderr
    CustomLog /dev/stdout combined
</VirtualHost>

EOF
}

# Generate vhosts from the project lists
read_projects "$LIST_MAIN"
read_projects "$LIST_LOCAL"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# Combine everything and remove comments and empty lines
{
  [[ -f "$DEFAULT_VHOSTS" ]] && sed '/^\s*#/d;/^\s*\/\//d' "$DEFAULT_VHOSTS" && echo
  sed '/^\s*#/d;/^\s*\/\//d' "$TMP_VHOSTS" && echo
  [[ -f "$LOCAL_VHOSTS" ]] && sed '/^\s*#/d;/^\s*\/\//d' "$LOCAL_VHOSTS"
} | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' > "$OUTPUT_FILE"

chmod -R a+rw "$VHOSTS_DIR/generated"

# Cleanup
rm "$TMP_VHOSTS"

printf " ✔ Generated %s\n" "$OUTPUT_FILE"

