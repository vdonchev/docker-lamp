FROM php:7.3-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libcurl4-openssl-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    apt-utils build-essential libonig-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install curl \
    xml \
    zip \
    mysqli \
    pdo_mysql \
    intl \
    mbstring \
    gd

# Install xdebug
RUN pecl install xdebug-3.1.6 \
 && docker-php-ext-enable xdebug \
 && mkdir -p /var/log/xdebug

# Enable extensions
RUN a2enmod ssl rewrite headers proxy proxy_http

# Set FQDN
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf