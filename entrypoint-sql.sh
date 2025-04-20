#!/bin/bash

set -e  # Stop on error

echo "[init] Starting SQL entrypoint logic..."

# Optional: load local SQL config if it exists
LOCAL_CNF="/config/sql/my.local.cnf"
TARGET_CNF="/etc/mysql/conf.d/999-local.cnf"

if [ -f "$LOCAL_CNF" ]; then
    echo "[init] Loading my.local.cnf..."
    cp "$LOCAL_CNF" "$TARGET_CNF"
fi

echo "[init] Continuing with original entrypoint..."
exec "$@"
