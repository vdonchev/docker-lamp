#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECTS_DIR="$BASE_DIR/config/projects"
SSL_DIR="$BASE_DIR/config/apache/ssl"
CA_DIR="$BASE_DIR/var/local-ca"

LIST_MAIN="$PROJECTS_DIR/domains.conf"
LIST_LOCAL="$PROJECTS_DIR/domains.local.conf"

CA_CERT_FILE="$CA_DIR/dev-ca.crt"
CA_KEY_FILE="$CA_DIR/dev-ca.key"
CA_SERIAL_FILE="$CA_DIR/dev-ca.srl"
PUBLIC_CA_FILE="$SSL_DIR/dev-ca.crt"
CRT_FILE="$SSL_DIR/dev.crt"
KEY_FILE="$SSL_DIR/dev.key"

ROTATE_CA=false
if [[ "${1:-}" == "--rotate-ca" ]]; then
  ROTATE_CA=true
elif [[ $# -gt 0 ]]; then
  printf '[error] Unknown option: %s\n' "$1" >&2
  exit 1
fi

command -v openssl >/dev/null 2>&1 || {
  echo "[error] OpenSSL is required to generate local certificates." >&2
  exit 1
}

mkdir -p "$SSL_DIR" "$CA_DIR"
chmod 700 "$CA_DIR"

TMP_DIR="$(mktemp -d)"
PUBLISH_STARTED=false
PUBLISH_PATHS=()
cleanup() {
  local status=$? index path backup
  if [[ $status -ne 0 ]] && $PUBLISH_STARTED; then
    echo "[error] Publication failed; restoring the previous certificate set." >&2
    for ((index = 0; index < ${#PUBLISH_PATHS[@]}; index++)); do
      path="${PUBLISH_PATHS[$index]}"
      backup="$TMP_DIR/backups/$index"
      rm -f "$path"
      [[ -f "$backup" ]] && cp -p "$backup" "$path"
    done
  fi
  rm -rf "$TMP_DIR"
  exit "$status"
}
trap cleanup EXIT

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

is_valid_domain() {
  local domain="$1" label
  local -a labels

  [[ ${#domain} -le 253 && "$domain" != .* && "$domain" != *. && "$domain" != *..* ]] || return 1
  IFS='.' read -r -a labels <<< "$domain"
  for label in "${labels[@]}"; do
    [[ ${#label} -le 63 && "$label" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || return 1
  done
}

get_domains() {
  local file="$1" line domain path
  [[ -f "$file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
    IFS=',' read -r domain path _ <<< "$line"
    domain="$(trim "$domain" | tr '[:upper:]' '[:lower:]')"
    path="$(trim "$path")"
    [[ -n "$domain" && -n "$path" ]] || continue
    if ! is_valid_domain "$domain"; then
      printf '[error] Invalid domain in %s: %s\n' "$file" "$domain" >&2
      return 1
    fi
    printf '%s\n' "$domain"
  done < "$file"
}

DOMAINS_FILE="$TMP_DIR/domains"
RAW_DOMAINS_FILE="$TMP_DIR/domains.raw"
get_domains "$LIST_MAIN" > "$RAW_DOMAINS_FILE"
get_domains "$LIST_LOCAL" >> "$RAW_DOMAINS_FILE"
LC_ALL=C sort -u "$RAW_DOMAINS_FILE" > "$DOMAINS_FILE"
if [[ ! -s "$DOMAINS_FILE" ]]; then
  echo "[error] No valid domains found in domains.conf or domains.local.conf." >&2
  exit 1
fi
PRIMARY_DOMAIN="$(LC_ALL=C head -n 1 "$DOMAINS_FILE")"

validate_ca_pair() {
  openssl x509 -in "$CA_CERT_FILE" -noout -checkend 71366400 >/dev/null 2>&1 || return 1
  openssl verify -CAfile "$CA_CERT_FILE" "$CA_CERT_FILE" >/dev/null 2>&1 || return 1
  openssl x509 -in "$CA_CERT_FILE" -noout -text | grep -q 'CA:TRUE' || return 1
  cmp -s \
    <(openssl x509 -in "$CA_CERT_FILE" -pubkey -noout 2>/dev/null) \
    <(openssl pkey -in "$CA_KEY_FILE" -pubout 2>/dev/null)
}

GENERATE_CA=false
if $ROTATE_CA; then
  if [[ -t 0 ]]; then
    echo "[warn] Rotating the local CA invalidates existing host trust and all issued certificates."
    read -r -p "Type ROTATE to continue: " confirmation
    [[ "$confirmation" == "ROTATE" ]] || {
      echo "[error] CA rotation cancelled." >&2
      exit 1
    }
  else
    echo "[error] CA rotation requires an interactive terminal." >&2
    exit 1
  fi
  GENERATE_CA=true
fi

if ! $GENERATE_CA && [[ -e "$CA_CERT_FILE" || -e "$CA_KEY_FILE" ]]; then
  if [[ ! -f "$CA_CERT_FILE" || ! -f "$CA_KEY_FILE" ]]; then
    echo "[error] Partial local CA state found in $CA_DIR; restore or remove it explicitly." >&2
    exit 1
  fi
  if ! validate_ca_pair; then
    echo "[error] The existing local CA is invalid, mismatched, or expires too soon; rotate it explicitly." >&2
    exit 1
  fi
  chmod 600 "$CA_KEY_FILE"
  echo "[OK] Reusing persistent local CA: $CA_CERT_FILE"
elif ! $GENERATE_CA; then
  if [[ -e "$CA_CERT_FILE" || -e "$CA_KEY_FILE" ]]; then
    echo "[error] Partial local CA state found in $CA_DIR; restore or remove it explicitly." >&2
    exit 1
  fi
  GENERATE_CA=true
fi

if $GENERATE_CA; then
  CA_CONF="$TMP_DIR/ca.cnf"
  cat > "$CA_CONF" <<'EOF'
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = ca_ext

[dn]
CN = Docker LAMP Development CA

[ca_ext]
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

  openssl req -x509 -new -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$TMP_DIR/dev-ca.key" -out "$TMP_DIR/dev-ca.crt" \
    -config "$CA_CONF"
  chmod 600 "$TMP_DIR/dev-ca.key"
  SIGNING_CA_CERT="$TMP_DIR/dev-ca.crt"
  SIGNING_CA_KEY="$TMP_DIR/dev-ca.key"
  SIGNING_CA_SERIAL="$TMP_DIR/dev-ca.srl"
else
  SIGNING_CA_CERT="$CA_CERT_FILE"
  SIGNING_CA_KEY="$CA_KEY_FILE"
  SIGNING_CA_SERIAL="$TMP_DIR/dev-ca.srl"
  [[ -f "$CA_SERIAL_FILE" ]] && cp "$CA_SERIAL_FILE" "$SIGNING_CA_SERIAL"
fi

LEAF_CONF="$TMP_DIR/leaf.cnf"
{
  cat <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
CN = $PRIMARY_DOMAIN

[req_ext]
subjectAltName = @alt_names

[leaf_ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
subjectAltName = @alt_names

[alt_names]
EOF
  index=1
  while IFS= read -r domain; do
    printf 'DNS.%d = %s\n' "$index" "$domain"
    index=$((index + 1))
  done < "$DOMAINS_FILE"
} > "$LEAF_CONF"

openssl req -new -nodes -newkey rsa:2048 \
  -keyout "$TMP_DIR/dev.key" -out "$TMP_DIR/dev.csr" \
  -config "$LEAF_CONF"

SERIAL_ARGS=(-CAserial "$SIGNING_CA_SERIAL")
[[ -f "$SIGNING_CA_SERIAL" ]] || SERIAL_ARGS+=(-CAcreateserial)
openssl x509 -req -days 825 -sha256 \
  -in "$TMP_DIR/dev.csr" -CA "$SIGNING_CA_CERT" -CAkey "$SIGNING_CA_KEY" \
  "${SERIAL_ARGS[@]}" -extfile "$LEAF_CONF" -extensions leaf_ext \
  -out "$TMP_DIR/dev.crt"

openssl verify -CAfile "$SIGNING_CA_CERT" -purpose sslserver "$TMP_DIR/dev.crt" >/dev/null
chmod 600 "$TMP_DIR/dev.key"
chmod 644 "$TMP_DIR/dev.crt" "$SIGNING_CA_CERT"
cp "$SIGNING_CA_CERT" "$TMP_DIR/public-dev-ca.crt"
chmod 644 "$TMP_DIR/public-dev-ca.crt"

PUBLISH_PATHS=("$CA_KEY_FILE" "$CA_CERT_FILE" "$CA_SERIAL_FILE" "$KEY_FILE" "$CRT_FILE" "$PUBLIC_CA_FILE")
mkdir -p "$TMP_DIR/backups"
for index in "${!PUBLISH_PATHS[@]}"; do
  [[ -f "${PUBLISH_PATHS[$index]}" ]] && cp -p "${PUBLISH_PATHS[$index]}" "$TMP_DIR/backups/$index"
done
PUBLISH_STARTED=true
if $GENERATE_CA; then
  mv "$TMP_DIR/dev-ca.key" "$CA_KEY_FILE"
  mv "$TMP_DIR/dev-ca.crt" "$CA_CERT_FILE"
  echo "[OK] Created persistent local CA: $CA_CERT_FILE"
fi
mv "$TMP_DIR/dev-ca.srl" "$CA_SERIAL_FILE"
mv "$TMP_DIR/dev.key" "$KEY_FILE"
mv "$TMP_DIR/dev.crt" "$CRT_FILE"
mv "$TMP_DIR/public-dev-ca.crt" "$PUBLIC_CA_FILE"
PUBLISH_STARTED=false

printf '[OK] Generated CA-signed multi-domain certificate:\n - %s\n - %s\n' "$CRT_FILE" "$KEY_FILE"
printf '[OK] Public CA certificate:\n - %s\n' "$PUBLIC_CA_FILE"
