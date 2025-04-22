#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(realpath "$SCRIPT_DIR/..")"

PROJECTS_DIR="$BASE_DIR/config/projects"
SSL_DIR="$BASE_DIR/config/apache/ssl"

LIST_MAIN="$PROJECTS_DIR/sites.list"
LIST_LOCAL="$PROJECTS_DIR/sites.local.list"

CRT_FILE="$SSL_DIR/dev.crt"
KEY_FILE="$SSL_DIR/dev.key"

TMP_CONF="$(mktemp)"
mkdir -p "$SSL_DIR"

# collecting all domains
get_domains() {
  local file="$1"
  [[ -f "$file" ]] || return
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
    IFS=',' read -r domain path <<< "$line"
    [[ -z "$domain" || -z "$path" ]] && continue
    echo "$domain"
  done < "$file"
}

DOMAINS=$( (get_domains "$LIST_MAIN"; get_domains "$LIST_LOCAL") | sort -u)
PRIMARY_DOMAIN=$(echo "$DOMAINS" | head -n1)

#  Generating OpenSSL configuration with SAN
{
  echo "[req]"
  echo "default_bits = 2048"
  echo "prompt = no"
  echo "default_md = sha256"
  echo "distinguished_name = dn"
  echo "req_extensions = req_ext"
  echo
  echo "[dn]"
  echo "CN = $PRIMARY_DOMAIN"
  echo
  echo "[req_ext]"
  echo "subjectAltName = @alt_names"
  echo
  echo "[alt_names]"
  i=1
  for domain in $DOMAINS; do
    echo "DNS.$i = $domain"
    i=$((i + 1))
  done
} > "$TMP_CONF"

# Generating certificate
openssl req -x509 -nodes -days 3650 \
  -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CRT_FILE" \
  -config "$TMP_CONF" \
  -extensions req_ext > /dev/null 2>&1

rm "$TMP_CONF"

printf "[OK] Successfully generated multi-domain SSL cert:\n - %s\n - %s\n" "$CRT_FILE" "$KEY_FILE"
