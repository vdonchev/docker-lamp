FROM php:8.0-apache

# Install required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
#    passwd \
    curl \
    libcurl4-openssl-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    apt-utils build-essential libonig-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

# Install php extensions
RUN docker-php-ext-install curl \
    xml \
    zip \
    mysqli \
    pdo_mysql \
    intl \
    mbstring \
    gd

# Install redis php extension
RUN pecl install redis && docker-php-ext-enable redis

# Install xdebug php extension
RUN pecl install xdebug-3.4.2 \
 && docker-php-ext-enable xdebug \
 && mkdir -p /var/log/xdebug

# Enable additional extensions
RUN a2enmod ssl rewrite headers proxy proxy_http

# Set FQDN
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf