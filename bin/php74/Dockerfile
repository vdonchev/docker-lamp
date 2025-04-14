FROM php:7.4-apache

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

# Install Redis
RUN pecl install redis && docker-php-ext-enable redis

# Install xdebug
#RUN pecl install xdebug-3.1.5 && docker-php-ext-enable xdebug && mkdir /var/log/xdebug

# Enable extensions
RUN a2enmod ssl rewrite headers proxy proxy_http