FROM php:7.4.10-fpm

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN docker-php-ext-install pdo_mysql
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libpng-dev \
    libzip-dev \
    libmcrypt-dev \
    curl \
    openssl \
    zip \
    unzip \
    git \
    && docker-php-ext-install -j$(nproc) pdo \
    && docker-php-ext-install -j$(nproc) pdo_pgsql \
    && docker-php-ext-install -j$(nproc) pdo_mysql \
    && docker-php-ext-install  bcmath \
    && docker-php-ext-install  gd \
    && docker-php-ext-install  zip \
    && docker-php-ext-install opcache

RUN pecl install -o -f redis \
    &&  rm -rf /tmp/pear \
    &&  docker-php-ext-enable redis

ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0"

ADD ./deploy/opcache.ini "$PHP_INI_DIR/conf.d/opcache.ini"

RUN apt-get install nano -y

RUN apt-get install supervisor -y

RUN apt-get install -y nginx  && \
    rm -rf /var/lib/apt/lists/*

# Prestissimo is a spiffing plugin
#RUN composer global require hirak/prestissimo --no-plugins --no-scripts

WORKDIR /var/www/html

# copy env file
COPY ./.env.example .env

# Install dependencies
COPY composer.json composer.json
COPY composer.lock composer.lock
RUN composer install --no-scripts --no-autoloader && rm -rf /root/.composer

# Copy codebase
COPY . ./

# Finish composer
RUN composer dump-autoload --optimize --no-scripts
# && composer run-script post-install-cmd

RUN rm /etc/nginx/sites-enabled/default

COPY ./deploy/nginx.conf /etc/nginx/nginx.conf
COPY ./deploy/deploy.conf /etc/nginx/conf.d/default.conf

RUN mv /usr/local/etc/php-fpm.d/www.conf /usr/local/etc/php-fpm.d/www.conf.backup
COPY ./deploy/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./deploy/supervisord.conf /etc/supervisord.conf

RUN usermod -a -G www-data root
RUN chgrp -R www-data storage

RUN chown -R www-data:www-data ./storage
RUN chmod -R 0777 ./storage

RUN chmod +x ./deploy/run

# create a Symlink that references  your  error log
RUN ln -s /app/storage/logs /opt/logs


ENTRYPOINT ["./deploy/run"]

EXPOSE 80
