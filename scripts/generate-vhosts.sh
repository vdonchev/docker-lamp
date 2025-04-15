#!/bin/bash

# Абсолютна пътека до директорията, където се намира скриптът
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Базова директория на проекта (приемаме, че е родителската директория на scripts)
BASE_DIR="$(realpath "$SCRIPT_DIR/..")"

# Пътища
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

# Проверка за SSL сертификати
SSL_ENABLED=false
if [[ -f "$CRT_FILE" && -f "$KEY_FILE" ]]; then
  SSL_ENABLED=true
fi

# Създаваме (и изчистваме) временен файл за динамичните vhost-и
TMP_VHOSTS="$(mktemp)"
> "$TMP_VHOSTS"

# Четене на списъците с проекти
read_projects() {
  local file="$1"
  [[ -f "$file" ]] || return

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Пропускаме коментари и празни редове
    [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue

    IFS=',' read -r domain path <<< "$line"
    [[ -z "$domain" || -z "$path" ]] && continue

    generate_http_vhost "$domain" "$path"
    if $SSL_ENABLED; then
      generate_https_vhost "$domain" "$path"
    fi
  done < "$file"
}

# Генериране на HTTP vhost
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

# Генериране на HTTPS vhost
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

# Генерираме vhost-ите от списъците
read_projects "$LIST_MAIN"
read_projects "$LIST_LOCAL"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# Обединяваме всичко и премахваме коментари и празни редове
{
  [[ -f "$DEFAULT_VHOSTS" ]] && sed '/^\s*#/d;/^\s*\/\//d' "$DEFAULT_VHOSTS" && echo
  sed '/^\s*#/d;/^\s*\/\//d' "$TMP_VHOSTS" && echo
  [[ -f "$LOCAL_VHOSTS" ]] && sed '/^\s*#/d;/^\s*\/\//d' "$LOCAL_VHOSTS"
} | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' > "$OUTPUT_FILE"

# Почистване
rm "$TMP_VHOSTS"

printf " ✔ Generated %s\n" "$OUTPUT_FILE"

