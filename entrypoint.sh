#!/bin/bash

set -e  # Stop on error

# Path to the environment file
ENV_FILE="/config/.env"

# Check if the .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "[init] WARNING: .env file not found at $ENV_FILE"
    echo "[init] Using default values defined in docker-compose.yml"
    echo ""
else
    echo "[init] .env file successfully loaded from $ENV_FILE"
fi

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
