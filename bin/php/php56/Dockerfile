ARG PHP_IMAGE_TAG
FROM php:${PHP_IMAGE_TAG:-5.6}-apache

RUN sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list \
 && sed -i 's|http://security.debian.org/debian-security|http://archive.debian.org/debian-security|g' /etc/apt/sources.list \
 && find /etc/apt/sources.list.d -type f -name '*.list' -exec sed -i '/stretch-updates/d' {} + \
 && sed -i '/stretch-updates/d' /etc/apt/sources.list \
 && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

# Install required system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano \
    unzip \
    curl \
    libcurl4-openssl-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    apt-utils build-essential \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libmcrypt-dev \
    imagemagick libmagickwand-dev \
    && rm -rf /var/lib/apt/lists/*

# Configure GD manually for legacy PHP
RUN docker-php-ext-configure gd \
    --with-freetype-dir=/usr/include/ \
    --with-jpeg-dir=/usr/include/

# Install PHP extensions
RUN docker-php-ext-install \
    curl \
    xml \
    zip \
    mysqli \
    pdo_mysql \
    intl \
    mbstring \
    gd \
    bcmath \
    exif \
    opcache \
    mcrypt

# Install Redis (final compatible version for PHP 5.6)
RUN pecl install redis-3.1.6 \
 && docker-php-ext-enable redis

# Install imagick php extension
RUN pecl install imagick-3.4.4 \
 && docker-php-ext-enable imagick

# Install Xdebug (final compatible version for PHP 5.6)
RUN pecl install xdebug-2.5.5 \
 && docker-php-ext-enable xdebug \
 && mkdir -p /var/log/xdebug

# Copy Xdebug configs
COPY config/php/xdebug/xdebug.ini /tmp/xdebug.ini
COPY config/php/xdebug/xdebug.legacy.ini /tmp/xdebug.legacy.ini

# Dynamically choose which to load based on PHP version
RUN php -r "exit(version_compare(PHP_VERSION, '7.2', '<') ? 0 : 1);" \
      && cp /tmp/xdebug.legacy.ini /usr/local/etc/php/conf.d/100-xdebug.ini \
      || cp /tmp/xdebug.ini /usr/local/etc/php/conf.d/100-xdebug.ini \
      && rm /tmp/xdebug.*

# Install Composer binary
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

# Enable Apache modules
RUN a2enmod ssl rewrite headers proxy proxy_http

# Custom install hook
COPY config/php/custom/ /docker-custom/
RUN if [ -d /docker-custom ]; then \
      chmod +x /docker-custom/*.sh 2>/dev/null || true; \
      for f in /docker-custom/*.sh; do \
        [ -f "$f" ] || continue; \
        echo "Running custom script: $f"; \
        /bin/sh "$f"; \
      done; \
      echo "All custom install scripts executed."; \
    else \
      echo "No custom scripts found, skipping."; \
    fi \

# Set FQDN
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf
