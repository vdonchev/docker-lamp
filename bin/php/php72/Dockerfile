FROM php:7.2-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
    nano \
    unzip \
    curl \
    libcurl4-openssl-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    apt-utils build-essential libonig-dev \
    libpng-dev \
    imagemagick libmagickwand-dev \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install curl \
    xml \
    zip \
    mysqli \
    pdo_mysql \
    intl \
    mbstring \
    gd \
    bcmath \
    exif \
    opcache

# Install Redis
RUN pecl install redis-5.3.7 && docker-php-ext-enable redis

# Install imagick php extension
RUN pecl install imagick-3.4.4 \
 && docker-php-ext-enable imagick

# Install xdebug
RUN pecl install xdebug-3.1.6 \
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

# Enable extensions
RUN a2enmod ssl rewrite headers proxy proxy_http

# Set FQDN
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf