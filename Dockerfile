FROM php:8.3-apache

ENV DEBIAN_FRONTEND=noninteractive

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libzip-dev \
        zip \
        unzip \
        git \
        libicu-dev \
        libxml2-dev \
        zlib1g-dev \
        libonig-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd intl mbstring xml zip pdo_mysql mysqli opcache soap exif \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && a2enmod rewrite headers expires \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Ajustar UID para evitar problemas de permisos con volúmenes
RUN usermod -u 1000 www-data || true

WORKDIR /var/www/html

# Crear directorio para datos de Moodle
RUN mkdir -p /var/moodledata && chown -R www-data:www-data /var/moodledata
# Configurar PHP para Moodle
RUN echo 'memory_limit = 512M' > /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'upload_max_filesize = 100M' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'post_max_size = 100M' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'max_input_vars = 5000' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'max_execution_time = 300' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'opcache.enable = 1' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'opcache.memory_consumption = 128' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'opcache.max_accelerated_files = 10000' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'zend.exception_ignore_args = On' >> /usr/local/etc/php/conf.d/moodle.ini
# Configurar Apache para usar /public como DocumentRoot
RUN echo '<VirtualHost *:80>\n\
    ServerAdmin webmaster@localhost\n\
    DocumentRoot /var/www/html/public\n\
    <Directory /var/www/html/public>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

# En desarrollo este COPY se sobreescribe por el volumen
COPY . /var/www/html

# Instalar dependencias de Composer (solo si composer.json existe)
RUN if [ -f "composer.json" ]; then \
        composer install --no-dev --no-interaction --optimize-autoloader --classmap-authoritative; \
    fi

RUN chown -R www-data:www-data /var/www/html

EXPOSE 80

CMD ["apache2-foreground"]
