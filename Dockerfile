# use ubuntu 20.04 as base image
FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris

# Use build arguments instead of ENV for these variables
ARG ITOP_URL
ARG PHP_VERSION

# Install required packages
RUN apt-get update -y && \
    apt-get install -y apache2 mysql-client software-properties-common && \
    add-apt-repository ppa:ondrej/php -y && \
    apt-get update -y && \
    apt-get install -y \
    php${PHP_VERSION} \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-ldap \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-apcu \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-xdebug \
    libapache2-mod-php${PHP_VERSION} \
    graphviz \
    unzip \
    wget \
    cron

# Enable php-openssl
RUN phpenmod openssl

# iTop performance tuning
RUN echo "apc.shm_size=128M" >> /etc/php/${PHP_VERSION}/apache2/php.ini && \
    echo "apc.ttl=7200" >> /etc/php/${PHP_VERSION}/apache2/php.ini

# Enable Apache modules
RUN a2enmod expires headers

# Add Apache configuration for caching
RUN echo '<IfModule mod_expires.c>\n\
    ExpiresActive On\n\
    ExpiresByType image/gif  A172800\n\
    ExpiresByType image/jpeg A172800\n\
    ExpiresByType image/png  A172800\n\
    ExpiresByType text/css   A172800\n\
    ExpiresByType text/javascript A172800\n\
    ExpiresByType application/x-javascript A172800\n\
    </IfModule>\n\
    <IfModule mod_headers.c>\n\
    <FilesMatch "\\\.(gif|jpe?g|png|css|swf|js)$">\n\
    Header set Cache-Control "max-age=2592000, public"\n\
    </FilesMatch>\n\
    </IfModule>' >> /etc/apache2/apache2.conf

# Download and install iTop
RUN wget -c ${ITOP_URL} -O /tmp/itop.zip && \
    unzip /tmp/itop.zip -d /tmp/itop && \
    mkdir -p /var/www/html/itop && \
    mv /tmp/itop/web/* /var/www/html/itop && \
    rm -rf /tmp/itop.zip /tmp/itop

# Add iTop toolkit
RUN mkdir /var/www/html/itop/toolkit && \
    wget -c https://github.com/Combodo/itop-toolkit-community/archive/refs/tags/3.0.0.zip -O /tmp/itop-toolkit.zip && \
    unzip /tmp/itop-toolkit.zip -d /tmp/itop-toolkit && \
    mv /tmp/itop-toolkit/itop-toolkit-community-3.0.0/* /var/www/html/itop/toolkit && \
    rm -rf /tmp/itop-toolkit.zip /tmp/itop-toolkit

# Set correct ownership
RUN chown -R www-data:www-data /var/www/html/itop

# Modify Apache configuration to /itop
RUN sed -i 's/\/var\/www\/html/\/var\/www\/html\/itop/g' /etc/apache2/sites-available/000-default.conf

# Init iTop crontab
RUN echo "*/5 * * * * www-data /usr/bin/php /var/www/html/itop/webservices/cron.php --param_file=/etc/itop/cron/params >> /etc/itop/cron/cron.log 2>&1" > /etc/cron.d/itop

# Start Apache in foreground
CMD ["apachectl", "-D", "FOREGROUND"]