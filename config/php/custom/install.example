#!/bin/bash
# Example: custom installer hook
# Copy this file to install.sh to activate.
# It will run at build time if present.

set -e

echo "Custom install started..."

# Example: extra OS deps
apt-get update && apt-get install -y libpq-dev

# Example: PHP extensions
docker-php-ext-install pdo_pgsql

# Example: PECL extension
pecl install yaml && docker-php-ext-enable yaml

echo "Custom install finished."
