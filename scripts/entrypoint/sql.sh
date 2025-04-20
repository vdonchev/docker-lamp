#!/bin/bash
set -e

echo "[init] Starting SQL entrypoint logic..."

LOCAL_CNF="/config/sql/my.local.cnf"
TARGET_CNF="/etc/mysql/conf.d/999-local.cnf"

if [ -f "$LOCAL_CNF" ]; then
    echo "[init] Found local SQL config. Copying to $TARGET_CNF"
    cp "$LOCAL_CNF" "$TARGET_CNF"
else
    echo "[init] No local SQL config found. Continuing..."
fi

echo "[init] Executing: $@"
exec "$@"
