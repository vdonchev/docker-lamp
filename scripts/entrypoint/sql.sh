#!/bin/bash
set -e

echo "[init] Starting SQL entrypoint logic..."

# Normalize engine name
SQL_ENGINE=$(echo "${SQL_ENGINE:-mysql}" | tr '[:upper:]' '[:lower:]')

# Validate allowed engines
if [ "$SQL_ENGINE" != "mysql" ] && [ "$SQL_ENGINE" != "mariadb" ]; then
    echo "[error] Unsupported SQL_ENGINE='$SQL_ENGINE'. Only 'mysql' or 'mariadb' are allowed."
    exit 1
fi

# Normalize version: keep only major.minor (e.g. 8.4, 11.4)
SQL_VERSION_RAW="${SQL_VERSION:-8.4}"
SQL_VERSION_MAJOR_MINOR=$(echo "$SQL_VERSION_RAW" | awk -F. '{print $1"."$2}')
SQL_VERSION_CLEAN=$(echo "$SQL_VERSION_MAJOR_MINOR" | tr -d '.')

# Paths
BASE_DIR="/var/db-host"                           # mounted from host (./var/db)
TARGET_DIR="${BASE_DIR}/${SQL_ENGINE}${SQL_VERSION_CLEAN}"

echo "[init] Preparing versioned data directory: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

# Tell MySQL where to store data
export DATADIR="$TARGET_DIR"

# Handle optional local configuration override
# Config paths
DEFAULT_CNF="/config/sql/${SQL_ENGINE}/my.cnf"
LOCAL_CNF="/config/sql/${SQL_ENGINE}/my.local.cnf"
TARGET_DIR_CONF="/etc/mysql/conf.d"

# Apply default config
if [ -f "$DEFAULT_CNF" ]; then
    echo "[init] Applying default config from: $DEFAULT_CNF"
    cp "$DEFAULT_CNF" "${TARGET_DIR_CONF}/000-default.cnf"
else
    echo "[warn] Default config not found for engine: $SQL_ENGINE"
fi

# Apply local override if present
if [ -f "$LOCAL_CNF" ]; then
    echo "[init] Applying local override from: $LOCAL_CNF"
    cp "$LOCAL_CNF" "${TARGET_DIR_CONF}/999-local.cnf"
else
    echo "[init] No local override found."
fi

echo "[init] Using SQL_ENGINE=$SQL_ENGINE, SQL_VERSION=$SQL_VERSION_RAW"
echo "[init] Data directory: $DATADIR"

if [ -n "$1" ]; then
    echo "[init] Executing: $@"
    exec "$@" --datadir="$DATADIR"
else
    if [ "$SQL_ENGINE" = "mariadb" ]; then
        echo "[init] Executing default mariadbd startup"
        exec docker-entrypoint.sh mariadbd --datadir="$DATADIR"
    else
        echo "[init] Executing default mysqld startup"
        exec docker-entrypoint.sh mysqld --datadir="$DATADIR"
    fi
fi

