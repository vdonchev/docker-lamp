#!/bin/bash
set -e

echo "[init] Starting web entrypoint..."

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
