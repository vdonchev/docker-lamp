FROM php:7.4-apache

RUN apt-get update && \
    apt-get install -y curl && \
    apt-get install -y libcurl4-openssl-dev && \
    apt-get install -y libxml2-dev && \
    apt-get install -y libzip-dev && \
    apt-get install -y libicu-dev && \
    apt-get install -y apt-utils build-essential libonig-dev && \
    apt-get install -y libpng-dev && \
    rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install curl && \
    docker-php-ext-install xml && \
    docker-php-ext-install zip && \
    docker-php-ext-install mysqli && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install intl && \
    docker-php-ext-install mbstring && \
    docker-php-ext-install gd

# Install Redis
RUN pecl install redis && \
    docker-php-ext-enable redis

# Install xdebug
RUN pecl install xdebug-3.1.5 && \
    docker-php-ext-enable xdebug && \
    mkdir /var/log/xdebug

RUN a2enmod ssl && \
    a2enmod rewrite