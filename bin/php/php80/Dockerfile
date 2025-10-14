ARG PHP_IMAGE_TAG
FROM php:${PHP_IMAGE_TAG:-8.0}-apache

# Install required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano \
    unzip \
    curl \
    git \
    libcurl4-openssl-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    apt-utils build-essential libonig-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    imagemagick libmagickwand-dev \
    && rm -rf /var/lib/apt/lists/*

# Install php extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install curl \
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

# Install imagick php extension
RUN pecl install imagick \
 && docker-php-ext-enable imagick

# Install redis php extension
RUN pecl install redis && docker-php-ext-enable redis

# Install xdebug php extension
RUN pecl install xdebug-3.4.2 \
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
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install Symfony CLI
RUN curl -sS https://get.symfony.com/cli/installer | bash \
    && mv /root/.symfony*/bin/symfony /usr/local/bin/symfony

# Enable additional extensions
RUN a2enmod ssl rewrite headers proxy proxy_http

# Set FQDN
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf