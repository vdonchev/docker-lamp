#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(realpath "$SCRIPT_DIR/..")"

PROJECTS_DIR="$BASE_DIR/config/projects"
VHOSTS_DIR="$BASE_DIR/config/apache/vhosts"
SSL_DIR="$BASE_DIR/config/apache/ssl"

LIST_MAIN="$PROJECTS_DIR/domains.conf"
LIST_LOCAL="$PROJECTS_DIR/domains.local.conf"

DEFAULT_VHOSTS="$VHOSTS_DIR/vhost.conf"
LOCAL_VHOSTS="$VHOSTS_DIR/vhost.local.conf"

CRT_FILE="$SSL_DIR/dev.crt"
KEY_FILE="$SSL_DIR/dev.key"

OUT_DIR="$VHOSTS_DIR/generated"
OUT_LOCAL="$OUT_DIR/000-vhost.local.conf"
OUT_DOMAINS="$OUT_DIR/100-domains.conf"
OUT_DEFAULT="$OUT_DIR/999-vhost.conf"

mkdir -p "$OUT_DIR"

SSL_ENABLED=false
if [[ -f "$CRT_FILE" && -f "$KEY_FILE" ]]; then
  SSL_ENABLED=true
fi

generate_http_vhost() {
  local domain="$1"
  local path="$2"
  cat <<EOF
<VirtualHost *:80>
    ServerName $domain
    DocumentRoot $path

    <Directory $path>
        Options +Indexes
        AllowOverride All
        Require all granted
    </Directory>

    <IfModule dir_module>
        DirectoryIndex index.php index.html
    </IfModule>

    AddDefaultCharset UTF-8

    Header set X-Environment "Development"

    ErrorLog /dev/stderr
    CustomLog /dev/stdout combined
</VirtualHost>

EOF
}

generate_https_vhost() {
  local domain="$1"
  local path="$2"
  cat <<EOF
<VirtualHost *:443>
    ServerName $domain
    DocumentRoot $path

    <Directory $path>
        Options +Indexes
        AllowOverride All
        Require all granted
    </Directory>

    <IfModule dir_module>
        DirectoryIndex index.php index.html
    </IfModule>

    AddDefaultCharset UTF-8

    Header set X-Environment "Development"

    SSLEngine on
    SSLCertificateFile "/etc/ssl/lamp/dev.crt"
    SSLCertificateKeyFile "/etc/ssl/lamp/dev.key"

    ErrorLog /dev/stderr
    CustomLog /dev/stdout combined
</VirtualHost>

EOF
}

process_domains() {
  local file="$1"
  [[ -f "$file" ]] || return

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ ! "$line" =~ ^[[:space:]]*[^,#[:space:]][^,]*,[^[:space:]].*$ ]]; then
      echo "[X] Invalid line format, skipping: $line"
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

# Write 000-vhost.local.conf
if [[ -f "$LOCAL_VHOSTS" ]]; then
  sed '/^\s*#/d;/^\s*\/\//d' "$LOCAL_VHOSTS" > "$OUT_LOCAL"
else
  : > "$OUT_LOCAL"
fi

# Write 100-domains.conf
{
  process_domains "$LIST_MAIN"
  process_domains "$LIST_LOCAL"
} > "$OUT_DOMAINS"

# Write 999-vhost.conf
if [[ -f "$DEFAULT_VHOSTS" ]]; then
  sed '/^\s*#/d;/^\s*\/\//d' "$DEFAULT_VHOSTS" > "$OUT_DEFAULT"
else
  : > "$OUT_DEFAULT"
fi

chmod -R a+rw "$OUT_DIR"
printf "[OK] Generated vhost files in %s\n" "$OUT_DIR"
