#!/bin/bash

set -e  # Stop on error

echo "[init] Starting entrypoint logic..."

if [ -f /scripts/generate-vhosts.sh ]; then
    echo "[init] Running vhost generation..."
    chmod +x /scripts/generate-vhosts.sh
    /scripts/generate-vhosts.sh
    echo "[init] Vhost generation complete."
else
    echo "[init] /scripts/generate-vhosts.sh not found. Skipping."
fi

# Set projects permission
chmod -R a+rwX /var/www

echo "[init] Starting Apache..."
exec apache2-foreground
