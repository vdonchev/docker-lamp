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

echo "[init] Launching Apache..."