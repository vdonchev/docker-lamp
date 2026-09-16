#!/bin/bash
set -e

echo "[init] Starting web entrypoint..."

# Trust the stack CA for PHP/cURL clients without exposing the signing key.
SOURCE_CA="/etc/ssl/lamp/dev-ca.crt"
MANAGED_CA="/usr/local/share/ca-certificates/docker-lamp-dev-ca.crt"

if [ -f "$SOURCE_CA" ]; then
    if ! command -v update-ca-certificates >/dev/null 2>&1; then
        echo "[error] $SOURCE_CA exists, but update-ca-certificates is unavailable." >&2
        exit 1
    fi
    if [ ! -f "$MANAGED_CA" ] || ! cmp -s "$SOURCE_CA" "$MANAGED_CA"; then
        echo "[init] Installing Docker LAMP development CA..."
        cp "$SOURCE_CA" "$MANAGED_CA"
        chmod 644 "$MANAGED_CA"
        update-ca-certificates --fresh
    else
        echo "[init] Docker LAMP development CA is already trusted."
    fi
elif [ -f "$MANAGED_CA" ]; then
    if ! command -v update-ca-certificates >/dev/null 2>&1; then
        echo "[error] Cannot remove stale Docker LAMP CA: update-ca-certificates is unavailable." >&2
        exit 1
    fi
    echo "[init] Removing stale Docker LAMP development CA..."
    rm -f "$MANAGED_CA"
    update-ca-certificates --fresh
fi

# Load optional local PHP config
LOCAL_INI="/config/php/conf.d/php.local.ini"
TARGET_INI="/usr/local/etc/php/conf.d/999-local.ini"

if [ -f "$LOCAL_INI" ]; then
    echo "[init] Found local PHP config. Copying to $TARGET_INI"
    cp "$LOCAL_INI" "$TARGET_INI"
else
    echo "[init] No local PHP config found. Continuing..."
fi

# Run vhost generation script
if [ -f /scripts/generate-vhosts.sh ]; then
    echo "[init] Running vhost generation..."
    chmod +x /scripts/generate-vhosts.sh
    bash -n /scripts/generate-vhosts.sh && /scripts/generate-vhosts.sh
    echo "[init] Vhost generation complete."
else
    echo "[init] No generate-vhosts.sh found. Skipping vhost generation."
fi

# Fix permissions for development
echo "[init] Setting dev-friendly permissions for /var/www..."
chmod -R a+rwX /var/www

# Keep newly created files writable across users in dev
WEB_UMASK="${WEB_UMASK:-0000}"
umask "$WEB_UMASK"
echo "[init] Using umask: $WEB_UMASK"

# Xdebug runtime toggle
choose_xdebug_ini() {
  php -r 'exit(version_compare(PHP_VERSION, "7.2", "<") ? 0 : 1);'
  if [ $? -eq 0 ]; then
    echo "/usr/local/etc/php/xdebug.legacy.ini"
  else
    echo "/usr/local/etc/php/xdebug.ini"
  fi
}

if [ "${ENABLE_XDEBUG}" = "true" ]; then
  ini_src="$(choose_xdebug_ini)"
  echo "[init] Enabling Xdebug using $(basename "$ini_src")"
  cp "$ini_src" /usr/local/etc/php/conf.d/100-xdebug.ini
else
  rm -f /usr/local/etc/php/conf.d/100-xdebug.ini 2>/dev/null || true
  echo "[init] Xdebug disabled."
fi

echo "[init] Launching Apache..."
