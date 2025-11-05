ARG PHP_IMAGE_TAG
FROM php:${PHP_IMAGE_TAG:-7.4}-apache

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
RUN pecl install redis && docker-php-ext-enable redis

# Install imagick php extension
RUN pecl install imagick-3.4.4 \
 && docker-php-ext-enable imagick

# Install xdebug
RUN pecl install xdebug-3.1.6 \
 && mkdir -p /var/log/xdebug

# Copy Xdebug configs
COPY config/php/xdebug/xdebug.ini /usr/local/etc/php/xdebug.ini
COPY config/php/xdebug/xdebug.legacy.ini /usr/local/etc/php/xdebug.legacy.ini

# Install Composer binary
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Enable extensions
RUN a2enmod ssl rewrite headers proxy proxy_http

# Configure Git identity
ARG GIT_USER_NAME
ARG GIT_USER_EMAIL
RUN if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then \
      git config --system user.name "$GIT_USER_NAME" && \
      git config --system user.email "$GIT_USER_EMAIL" && \
      echo "Configured git identity: $GIT_USER_NAME <$GIT_USER_EMAIL>"; \
    else \
      echo "No git identity provided, skipping git config."; \
    fi

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
    fi

# Set FQDN
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf