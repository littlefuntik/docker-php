FROM alpine

ENV PHP_VERSION php-7.1.9
ENV COMPOSER_VERSION 1.5.2
ENV APP_USER www-data
ENV APP_GROUP www-data
ENV TZ Europe/Kiev

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY app /app

RUN addgroup -g 82 -S ${APP_GROUP} && adduser -u 82 -D -S -s /sbin/nologin -G ${APP_GROUP} ${APP_USER}

RUN \
apk update && \
\
apk add freetds-dev && \
\
apk add tzdata && \
cp /usr/share/zoneinfo/$TZ /etc/localtime && \
echo "$TZ" > /etc/timezone && \
apk del tzdata && \
\
apk add ca-certificates && \
update-ca-certificates && \
\
apk add autoconf file g++ gcc libc-dev make pkgconf re2c openssl openssl-dev curl-dev libmcrypt-dev libxml2-dev libpng-dev libjpeg-turbo-dev && \
\
export PHP_INI_DIR="/usr/local/etc/php" && \
mkdir -p $PHP_INI_DIR/conf.d \
cd ~ && \
wget -O ${PHP_VERSION}.tar.gz http://ua2.php.net/get/${PHP_VERSION}.tar.gz/from/this/mirror && \
tar -zxvf ${PHP_VERSION}.tar.gz && \
cd ${PHP_VERSION} && \
export CFLAGS="-fstack-protector-strong -fpic -fpie -O2" && \
export CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2" && \
export LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" && \
./configure \
    --prefix=/usr/local \
    --with-config-file-path="$PHP_INI_DIR" \
    --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
    --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data \
    --enable-debug \
    --disable-short-tags \
    --disable-ipv6 \
    --disable-all \
    --enable-libxml --enable-xml --enable-soap \
    --with-curl \
    --with-openssl \
    --enable-mbstring \
    --with-mcrypt \
    --with-pdo-dblib \
    --enable-hash \
    --enable-pcntl \
    --enable-zip \
    --enable-mysqlnd --enable-pdo --with-pdo-mysql=mysqlnd --with-mysqli=mysqlnd \
    --enable-json \
    --enable-ctype \
    --enable-session \
    --with-gd \
    --with-pear \
    --enable-phar \
    --enable-filter\
    --enable-dom \
    --enable-tokenizer \
    --enable-xmlwriter \
    --enable-simplexml \
    --enable-fileinfo && \
make -j "$(getconf _NPROCESSORS_ONLN)" && \
make install && \
make clean && \
cp php.ini-development $PHP_INI_DIR/php.ini && \
cd .. && rm -rf ${PHP_VERSION} ${PHP_VERSION}.tar.gz && \
pear config-set php_ini $PHP_INI_DIR/php.ini && \
pecl config-set php_ini $PHP_INI_DIR/php.ini && \
apk add geoip-dev && pecl install geoip-1.1.1 xdebug && \
[ -d /usr/local/etc/php-fpm.d ] || mkdir /usr/local/etc/php-fpm.d && \
{ \
    echo '[global]'; \
    echo 'pid = /run/php-fpm.pid'; \
    echo 'error_log = /var/log/fpm-error.log'; \
    echo 'daemonize = no'; \
    echo 'include=/usr/local/etc/php-fpm.d/*.conf'; \
} | tee /usr/local/etc/php-fpm.conf && \
{ \
    echo '[www]'; \
    echo '; if we send this to /proc/self/fd/1, it never appears'; \
    echo 'listen = 9000'; \
    echo 'user = ${APP_USER}'; \
    echo 'group = ${APP_GROUP}'; \
    echo 'chdir = /app'; \
    echo 'pm = dynamic'; \
    echo 'pm.max_children = 9'; \
    echo 'pm.start_servers = 3'; \
    echo 'pm.max_spare_servers = 4'; \
    echo 'pm.min_spare_servers = 2'; \
    echo 'pm.max_requests = 20'; \
    echo 'request_terminate_timeout = 0'; \
    echo 'request_slowlog_timeout = 1s'; \
    echo 'slowlog = /proc/self/fd/2'; \
    echo 'catch_workers_output = yes'; \
    echo 'access.log = /var/log/fpm-access.log'; \
    echo 'clear_env = no'; \
    echo 'php_flag[display_errors] = on'; \
    echo 'php_admin_value[memory_limit] = 32M'; \
} | tee /usr/local/etc/php-fpm.d/docker.conf && \
sed -i \
    -e "s|upload_max_filesize\s*=.*|upload_max_filesize = 100M|" \
    -e "s|max_file_uploads\s*=.*|max_file_uploads = 50|" \
    -e "s|post_max_size\s*=.*|post_max_size = 100M|" \
    -e "s|;cgi.fix_pathinfo\s*=.*|cgi.fix_pathinfo = 1|" \
    -e "s|;date.timezone\s*=.*|date.timezone = Europe/Kiev|" \
    /usr/local/etc/php/php.ini && \
rm -rf ~/${PHP_VERSION} && \
rm -rf /var/cache/apk/* && \
php -m && \
php -v

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/fpm-access.log && \
	ln -sf /dev/stderr /var/log/fpm-error.log

RUN \
  wget -O /tmp/composer-setup.php https://getcomposer.org/installer \
  && wget -O /tmp/composer-setup.sig https://composer.github.io/installer.sig \
  && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
  && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
  && rm -rf /tmp/composer-setup.php \
  && rm -rf /tmp/composer-setup.sig

RUN composer global require "fxp/composer-asset-plugin:1.3.1"

RUN chmod +x /docker-entrypoint.sh

WORKDIR /app

EXPOSE 9000

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["php-fpm"]
