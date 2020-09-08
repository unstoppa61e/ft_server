# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: monoue <marvin@student.42.fr>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2020/09/07 10:53:22 by monoue            #+#    #+#              #
#    Updated: 2020/09/08 14:40:08 by monoue           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM debian:buster

# install WordPress dependencies
RUN	set -ex; \
		apt-get update; \
		apt-get install -y --no-install-recommends \
				apt-utils \
				ca-certificates \
				# git \
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
				# procps \
				# unzip \
				supervisor \
				# vim?
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
# ENV	WORDPRESS_INSTALL /var/www/html
# ENV	WORDPRESS_CONTENT $WORDPRESS_INSTALL/wordpress
ENV	WORDPRESS_CONTENT /bar/www/html/wordpress

RUN	set -eux; \
		wget -O wordpress.tar.gz "$WORDPRESS_DOWNLOAD_URL"; \
		# mkdir -p "$WORDPRESS_INSTALL"; \
		mkdir -p "$WORDPRESS_CONTENT"; \
		tar -xzf wordpress.tar.gz -C "$WORDPRESS_CONTENT" --strip-components=1; \
		rm wordpress.tar.gz; \
		chown -R www-data:www-data "$WORDPRESS_CONTENT"
COPY ./srcs/wp-config.php "$WORDPRESS_CONTENT/wp-config.php"

# set phpMyAdmin
ENV PHPMYADMIN_VERSION 5.0.2
ENV	PHPMYADMIN_DOWNLOAD_URL https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VERSION/phpMyAdmin-$PHPMYADMIN_VERSION-all-languages.tar.gz
# ENV	PHPMYADMIN_INSTALL /var/www/html
# ENV	PHPMYADMIN_CONTENT $PHPMYADMIN_INSTALL/phpMyAdmin
ENV	PHPMYADMIN_CONTENT /var/www/html/phpMyAdmin

RUN	set -eux; \
		wget -O phpmyadmin.tar.gz "$PHPMYADMIN_DOWNLOAD_URL"; \
		# mkdir -p "$PHPMYADMIN_INSTALL"; \
		mkdir -p "$PHPMYADMIN_CONTENT"; \
		tar -xzf phpmyadmin.tar.gz -C "$PHPMYADMIN_CONTENT" --strip-components=1; \
		rm phpmyadmin.tar.gz
# これは、どうせ最後に上書きされているから、そもそも不要なのでは
COPY ./srcs/default.conf /etc/nginx/sites-available/default
# COPY ./srcs/wordpress.conf /etc/nginx/sites-available/wordpress.conf

# set SSL
ENV	SSL_DIR /etc/nginx/ssl
ENV	KEY server.key
ENV	CSR server.csr
ENV CRT server.crt

RUN	set -eux; \
		mkdir -p "$SSL_DIR"; \
		\
		openssl genrsa \
			-out "$SSL_DIR/$KEY" 2048; \
		\
		openssl req -new \
			-subj "/C=JP/ST=Tokyo/L=Minato-ku/O=42Tokyo/OU=42cursus/CN=monoue" \
			# -subj "/CN=localhost/DNS=localhost" \
			# -subj "/C=JP/ST=Tokyo/L=Minato-ku/O=42Tokyo/OU=42cursus/CN=localhost" \
			-key "$SSL_DIR/$KEY" \
			-out "$SSL_DIR/$CSR"; \
		\
		openssl x509 -req \
			-days 3650 \
			-signkey "$SSL_DIR/$KEY" \
			-in "$SSL_DIR/$CSR" \
			-out "$SSL_DIR/$CRT"

# set supervisor
# supervisor = プロセス管理ツール。これにより、実行したいプロセスを再起動できる。
# supervisor の設定ファイルのデフォの置き場は、この conf.d
COPY ./srcs/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN  chmod +x /etc/supervisor/conf.d/supervisord.conf
# 元はこう
# RUN  chmod 777 /etc/supervisor/conf.d/supervisord.conf

# set entrykit
ENV	ENTRYKIT_VERSION 0.4.0
ENV	ENTRYKIT_OS Linux
# ENV	ENTRYKIT_DOWNLOAD_URL https://github.com/progrium/entrykit/releases/download/v$ENTRYKIT_VERSION/entrykit_$ENTRYKIT_VERSION_$ENTRYKIT_OS_x86_64.tgz
ENV	ENTRYKIT_DOWNLOAD_URL https://github.com/progrium/entrykit/releases/download/v0.4.0/entrykit_0.4.0_Linux_x86_64.tgz
ENV	ENTRYKIT_INSTALL /bin

RUN	set -eux; \
		wget -O entrykit.tgz "$ENTRYKIT_DOWNLOAD_URL"; \
		# mkdir -p "$ENTRYKIT_INSTALL"; \
		# mkdir -p "$ENTRYKIT_CONTENT"; \
		tar -xzf entrykit.tgz -C "$ENTRYKIT_INSTALL"; \
		rm entrykit.tgz; \
		chmod +x "$ENTRYKIT_INSTALL/entrykit"; \
		# render などのサブコマンドのシンボリックリンクを作成する
		entrykit --symlink
#wordpress のためのバーチャルホスト設定ファイル
COPY ./srcs/wordpress.tmpl /etc/nginx/sites-available/wordpress.tmpl
# 元はこれ
# COPY ./srcs/default.tmpl /etc/nginx/sites-available/default.tmpl

# EXPOSE 80 443

ENTRYPOINT	["render", "/etc/nginx/sites-available/wordpress","--","/usr/bin/supervisord"]
#	元はこう
# ENTRYPOINT	["render", "/etc/nginx/sites-available/default.conf","--","/usr/bin/supervisord"]

#CMD で、デフォの引数として on を渡したい

# csr: Certificate Sigining Request 証明書の申請時に提出するファイル
# crt: CeRTificate いわゆる SSL 証明書。言い換えれば、署名付き公開鍵。


#	変更前。これで動いていた。
# RUN	apt-get update && apt-get install -y \
# 	apt-utils \
# 	ca-certificates \
# 	git \
# 	mariadb-client \
# 	mariadb-server \
# 	nginx \
# 	php-bcmath \
# 	php-cgi \
# 	php-common \
# 	php-fpm \
# 	php-gd \
# 	php-gettext \
# 	php-mbstring \
# 	php-mysql \
# 	php-net-socket \
# 	php-pear \
# 	php-xml-util \
# 	php-zip \
# &&	service mysql start \
# &&	mysql --execute "CREATE DATABASE wpdb;" \
# &&	mysql -e "CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'dbpassword';" \
# &&	mysql -e "GRANT ALL ON wpdb.* TO 'wpuser'@'localhost';" \
# #	このケースでは不要だと思われる
# && mysql -e "FLUSH PRIVILEGES;" \
# &&	cd /var/www/html/ \
# &&	wget https://wordpress.org/latest.tar.gz \
# &&	tar -xvf latest.tar.gz \
# &&	rm latest.tar.gz \
# &&	cd wordpress \
# &&	chown -R www-data:www-data /var/www/html/wordpress
#	多分要らない。もしかすると権限周りで要るのかも…？
# &&	cp wp-config-sample.php wp-config.php \
# COPY ./srcs/wp-config.php /var/www/html/wordpress/wp-config.php