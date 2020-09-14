# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: monoue <marvin@student.42.fr>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2020/09/07 10:53:22 by monoue            #+#    #+#              #
#    Updated: 2020/09/14 10:05:19 by monoue           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM debian:buster

# install WordPress dependencies
RUN	set -ex; \
		apt-get update; \
		apt-get install -y --no-install-recommends \
				apt-utils \
				ca-certificates \
				mariadb-client \
				mariadb-server \
				nginx \
				php-bcmath \
				php-cgi \
				php-common \
				php-fpm \
				php-gd \
				php-gettext \
				php-mbstring \
				php-mysql \
				php-net-socket \
				php-pear \
				php-xml-util \
				php-zip \
				supervisor \
				wget \
		; \
		rm -rf /var/lib/apt/lists/*

# set MariaDB
ENV	DATABASE	wpdb
ENV	USER		wpuser
ENV	HOST		localhost
ENV	PASSWORD	dbpassword

RUN	set -eux; \
		service mysql start; \
		mysql -e "CREATE DATABASE $DATABASE;"; \
		mysql -e "CREATE USER '$USER'@'$HOST' IDENTIFIED BY '$PASSWORD';"; \
		mysql -e "GRANT ALL ON $DATABASE.* TO '$USER'@'$HOST';"

# set WordPress
ENV	WORDPRESS_DOWNLOAD_URL https://wordpress.org/latest.tar.gz

ENV	WORDPRESS_CONTENT /var/www/html/wordpress

RUN	set -eux; \
		wget -O wordpress.tar.gz "$WORDPRESS_DOWNLOAD_URL"; \
		mkdir -p "$WORDPRESS_CONTENT"; \
		tar -xzf wordpress.tar.gz -C "$WORDPRESS_CONTENT" --strip-components=1; \
		rm wordpress.tar.gz; \
		chown -R www-data:www-data "$WORDPRESS_CONTENT"

COPY ./srcs/wp-config.php "$WORDPRESS_CONTENT/wp-config.php"

RUN	chmod 777 "$WORDPRESS_CONTENT/wp-config.php"

# set phpMyAdmin
ENV PHPMYADMIN_VERSION 5.0.2

ENV	PHPMYADMIN_DOWNLOAD_URL https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VERSION/phpMyAdmin-$PHPMYADMIN_VERSION-all-languages.tar.gz

ENV	PHPMYADMIN_CONTENT /var/www/html/phpmyadmin

RUN	set -eux; \
		wget -O phpmyadmin.tar.gz "$PHPMYADMIN_DOWNLOAD_URL"; \
		mkdir -p "$PHPMYADMIN_CONTENT"; \
		tar -xzf phpmyadmin.tar.gz -C "$PHPMYADMIN_CONTENT" --strip-components=1; \
		rm phpmyadmin.tar.gz

# set secure sockets layer
ENV	SSL_DIR /etc/nginx/ssl

ENV	KEY server.key
ENV	CSR server.csr
ENV CRT server.crt

RUN	set -eux; \
		mkdir -p "$SSL_DIR"; \
		\
# generate a private key
		openssl genrsa \
			-out "$SSL_DIR/$KEY" 2048; \
		\
# generate a certificate signing request
		openssl req -new \
			-subj "/C=JP/ST=Tokyo/L=Minato-ku/O=42Tokyo/OU=42cursus/CN=localhost" \
			-key "$SSL_DIR/$KEY" \
			-out "$SSL_DIR/$CSR"; \
		\
# generate a self-signed certificate
		openssl x509 -req \
			-days 3650 \
			-signkey "$SSL_DIR/$KEY" \
			-in "$SSL_DIR/$CSR" \
			-out "$SSL_DIR/$CRT"

# set supervisor
COPY ./srcs/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /etc/supervisor/conf.d/supervisord.conf

# set Entrykit
ENV	ENTRYKIT_DOWNLOAD_URL https://github.com/progrium/entrykit/releases/download/v0.4.0/entrykit_0.4.0_Linux_x86_64.tgz

ENV	ENTRYKIT_INSTALL /bin

RUN	set -eux; \
		wget -O entrykit.tgz "$ENTRYKIT_DOWNLOAD_URL"; \
		tar -xzf entrykit.tgz -C "$ENTRYKIT_INSTALL"; \
		rm entrykit.tgz; \
		chmod +x "$ENTRYKIT_INSTALL/entrykit"; \
		entrykit --symlink

COPY ./srcs/default.tmpl /etc/nginx/sites-available/default.tmpl

ENTRYPOINT	["render", "/etc/nginx/sites-available/default", "--", "/usr/bin/supervisord"]

EXPOSE 80 443
