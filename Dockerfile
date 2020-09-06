# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: monoue <marvin@student.42.fr>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2020/09/02 09:46:11 by monoue            #+#    #+#              #
#    Updated: 2020/09/07 08:08:58 by monoue           ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM debian:buster
# ENV DEBIAN_FRONTEND noninteractive

# set	-e: エラー時（= exit 0 以外を返す時）に打ち止め
#		-u: 未定義の変数を使おうとした場合に打ち止め
#		-x: 実行コマンドとその引数をトレースとして出力

# install WordPress dependencies
RUN	set -eux; \
		apt-get update; \
		apt-get install -y --no-install-recommends \
				# apt-utils \
				ca-certificates \
				# git \
				mariadb-client \
				mariadb-server \
				nginx \
				# php7.3?
				# php-bcmath \
				# php-cgi \
				# php-cli?
				# php-common \
				php-fpm \
				# php-gd \
				# php-gettext \
				php-mbstring \
				php-mysql \
				# php-net-socket \
				# php-pear \
				# php-xml-util \
				# php-zip \
				# procps \
				# unzip \
				supervisor \
				# vim?
				wget \
		; \
		rm -rf /var/lib/apt/lists/*; \
		\
# set MySQL
		service mysql start; \
		mysql --execute "CREATE DATABASE wpdb;"; \
		mysql -e "CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'dbpassword';"; \
		mysql -e "GRANT ALL ON wpdb.* TO 'wpuser'@'localhost';"

# set WordPress
WORKDIR	/var/www/html
RUN	set -eux; \
		wget https://wordpress.org/latest.tar.gz; \
		tar -xvf latest.tar.gz; \
		rm latest.tar.gz; \
		chown -R www-data:www-data wordpress
COPY ./srcs/wp-config.php /var/www/html/wordpress/wp-config.php

# set phpMyAdmin
RUN	set -eux; \
		wget https://files.phpmyadmin.net/phpMyAdmin/5.0.2/phpMyAdmin-5.0.2-all-languages.tar.gz ;\
		tar -xvf phpMyAdmin-5.0.2-all-languages.tar.gz; \
		rm phpMyAdmin-5.0.2-all-languages.tar.gz; \
		mv phpMyAdmin-5.0.2-all-languages phpMyAdmin

# set SSL
WORKDIR	/etc/nginx/ssl
RUN	set -eux; \
		# 秘密鍵の作成
		openssl genrsa \
			-out server.key 2048; \
		\
		# CSR 関連 -> openssl req コマンド
		# -new オプション -> 作成
		openssl req -new \
			-subj "/C=JP/ST=Tokyo/L=Minato-ku/O=42Tokyo/OU=42cursus/CN=monoue" \
			# 作成に使用する秘密鍵を指定
			# これが、CSR に含まれる公開鍵と対になる
			-key server.key \
			-out server.csr; \
		\
		# こちらは localhost としてあるので、上ので動かなければこちらを使う。
		# openssl req -new -key server.key -out server.csr -subj "/C=JP/ST=Tokyo/L=Minato-ku/O=42 Tokyo/OU=42 cursus/CN=localhost"; \
		# openssl X509 コマンド
		# -req オプションによって、入力に CSR を使用するようになる
		openssl x509 -req \
			-days 3650 \
			# 自己署名を行う秘密鍵を指定
			-signkey server.key \
			# CSR を指定
			-in server.csr \
			# 作成する SSL サーバー証明書のファイル名を指定
			-out server.crt \

COPY ./srcs/wordpress.conf /etc/nginx/sites-available/wordpress.conf





# EXPOSE 80 443

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