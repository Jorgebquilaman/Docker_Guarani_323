# syntax=docker/dockerfile:1.7
FROM php:8.1-apache-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PROJECT_DIR=/opt/guarani \
    TZ=America/Argentina/Buenos_Aires

# Sistema + extensiones PHP requeridas por Guaraní 3.23
RUN apt-get update && apt-get install -y --no-install-recommends \
        git subversion unzip zip curl ca-certificates \
        libpq-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev libzip-dev \
        default-jre-headless graphviz fonts-dejavu-core fonts-liberation \
        postgresql-client cron \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        pgsql pdo_pgsql gd zip exif bcmath opcache \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && a2enmod rewrite setenvif headers expires \
    && echo 'ServerName localhost' > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY docker/php/guarani.ini /usr/local/etc/php/conf.d/99-guarani.ini

WORKDIR /opt/guarani

# Capa 1: dependencias (se cachea aunque cambie el código del proyecto)
COPY src/composer.json src/composer.lock ./
RUN composer install --no-dev --prefer-dist --no-scripts --no-autoloader --no-interaction

# Capa 2: código + autoload + scripts de compatibilidad del proyecto
COPY src/ ./
RUN composer dump-autoload --optimize --no-scripts \
    && php -r 'require "vendor/autoload.php"; \SIU\Guarani\Scripts\Composer::postInstallCmd();' \
    && printf 'menu=2\n' > menu.ini \
    && mkdir -p instalacion www temp metadatos_compilados /var/log/guarani \
    && chown -R www-data:www-data instalacion www temp metadatos_compilados \
        vendor/siu-toba/framework/www vendor/siu-toba/framework/temp /var/log/guarani \
    && chmod -R g+rwX instalacion www temp metadatos_compilados \
        vendor/siu-toba/framework/www vendor/siu-toba/framework/temp

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 8081

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
