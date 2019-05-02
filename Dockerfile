FROM php:7.1-apache

# envs
ENV INSTALL_DIR /var/www/html

# install composer
RUN curl -sS https://getcomposer.org/installer | php \
&& mv composer.phar /usr/local/bin/composer

COPY ./auth.json /var/www/.composer/

# install libraries
RUN requirements="cron libpng-dev libmcrypt-dev libmcrypt4 libcurl3-dev libfreetype6 libjpeg62-turbo libjpeg62-turbo-dev libfreetype6-dev libicu-dev libxslt1-dev" \
 && apt-get update \
 && apt-get install -y $requirements \
 && rm -rf /var/lib/apt/lists/* \
 && docker-php-ext-install pdo_mysql \
 && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
 && docker-php-ext-install gd \
 && docker-php-ext-install mcrypt \
 && docker-php-ext-install mbstring \
 && docker-php-ext-install zip \
 && docker-php-ext-install intl \
 && docker-php-ext-install xsl \
 && docker-php-ext-install soap \
 && docker-php-ext-install bcmath

# add magento cron job
COPY crontab /etc/cron.d/magento2-cron
RUN chmod 0644 /etc/cron.d/magento2-cron
RUN crontab -u www-data /etc/cron.d/magento2-cron 

# turn on mod_rewrite
RUN a2enmod rewrite

# set memory limits
RUN echo "memory_limit=2048M" > /usr/local/etc/php/conf.d/memory-limit.ini

# clean apt-get
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# www-data should own /var/www
RUN chown -R www-data:www-data /var/www

#copying and changing mode of composer file
COPY composer.json /var/www/html
RUN chmod 777 /var/www/html/composer.json

# switch user to www-data
USER www-data

# copy sources with proper user
COPY --chown=www-data . $INSTALL_DIR

# set working dir
WORKDIR $INSTALL_DIR

# composer install
RUN composer install
RUN composer config repositories.magento composer https://repo.magento.com/

# chmod directories
RUN chmod u+x bin/magento

# switch back
USER root

# run cron alongside apache
CMD [ "sh", "-c", "cron && apache2-foreground" ]