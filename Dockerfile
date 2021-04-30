FROM php:8.0.3-fpm-alpine

ENV TERM='xterm-256color'
ENV TZ='Australia/Melbourne'
ENV PATH="$PATH:/var/www/vendor/bin"
ENV COMPOSER_HOME /tmp
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_VERSION 2.0.12
ENV NGINX_VERSION 1.15.9

#
#--------------------------------------------------------------------------
# Install nginx
#--------------------------------------------------------------------------
#

RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
    && CONFIG="\
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --with-http_slice_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-compat \
    --with-file-aio \
    --with-http_v2_module \
    " \
    && addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && apk add --no-cache --virtual .build-deps \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    linux-headers \
    curl \
    gnupg1 \
    libxslt-dev \
    gd-dev \
    geoip-dev \
    && curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
    # && curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
    # && export GNUPGHOME="$(mktemp -d)" \
    # && found=''; \
    # for server in \
    # ha.pool.sks-keyservers.net \
    # hkp://keyserver.ubuntu.com:80 \
    # hkp://p80.pool.sks-keyservers.net:80 \
    # pgp.mit.edu \
    # ; do \
    # echo "Fetching GPG key $GPG_KEYS from $server"; \
    # gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
    # done; \
    # test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
    # gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
    # && rm -rf "$GNUPGHOME" nginx.tar.gz.asc \
    && mkdir -p /usr/src \
    && tar -zxC /usr/src -f nginx.tar.gz \
    && rm nginx.tar.gz \
    && cd /usr/src/nginx-$NGINX_VERSION \
    && ./configure $CONFIG --with-debug \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && mv objs/nginx objs/nginx-debug \
    && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
    && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
    && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
    && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
    && ./configure $CONFIG \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && rm -rf /etc/nginx/html/ \
    && mkdir /etc/nginx/conf.d/ \
    && mkdir -p /usr/share/nginx/html/ \
    && install -m644 html/index.html /usr/share/nginx/html/ \
    && install -m644 html/50x.html /usr/share/nginx/html/ \
    && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
    && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
    && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
    && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
    && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
    && apk add nginx-mod-http-headers-more \
    && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
    && strip /usr/sbin/nginx* \
    && strip /usr/lib/nginx/modules/*.so \
    && rm -rf /usr/src/nginx-$NGINX_VERSION \
    \
    # Bring in gettext so we can get `envsubst`, then throw
    # the rest away. To do this, we need to install `gettext`
    # then move `envsubst` out of the way so `gettext` can
    # be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
    && apk add --no-cache --virtual .nginx-rundeps $runDeps \
    && apk del .build-deps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
    \
    # Bring in tzdata so users could set the timezones through the environment
    # variables
    && apk add --no-cache tzdata \
    \
    # forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log    

#
#--------------------------------------------------------------------------
# Install PHP dependencies and extensions
#--------------------------------------------------------------------------
#

RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
    && apk add --no-cache \
        supervisor \
        bash \
        # Yes, weare aware that we install curl twice.
        curl \ 
        freetype \
        zip \
        unzip \
        libzip-dev \
        libpng \
        libjpeg-turbo \
        freetype-dev \
        libpng-dev \
        libjpeg-turbo-dev \  
        mariadb-client \ 
    # Redis extension
    && pecl install -o -f redis \
    && docker-php-ext-enable redis \        
    && rm -rf /tmp/pear \
    # lib zip
    && docker-php-ext-configure zip \
    # Misic extensions
    && docker-php-ext-install \
        zip \
        pdo \
        pdo_mysql \
        mysqli \
        opcache \
        pcntl \
        bcmath \
        fileinfo \
        exif \        
    # GD image extensions
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
    && docker-php-ext-install -j${NPROC} gd \
    # remove caches
    && apk del -f .build-deps  

#
#--------------------------------------------------------------------------
# Composer
#--------------------------------------------------------------------------
#

RUN set -eux; \
  curl --silent --fail --location --retry 3 --output /tmp/installer.php --url https://raw.githubusercontent.com/composer/getcomposer.org/cb19f2aa3aeaa2006c0cd69a7ef011eb31463067/web/installer; \
  php -r " \
    \$signature = '48e3236262b34d30969dca3c37281b3b4bbe3221bda826ac6a9a62d6444cdb0dcd0615698a5cbe587c3f0fe57a54d8f5'; \
    \$hash = hash('sha384', file_get_contents('/tmp/installer.php')); \
    if (!hash_equals(\$signature, \$hash)) { \
      unlink('/tmp/installer.php'); \
      echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
      exit(1); \
    }"; \
  php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION}; \
  composer --ansi --version --no-interaction; \
  rm -f /tmp/installer.php; \
  find /tmp -type d -exec chmod -v 1777 {} +    

#
#--------------------------------------------------------------------------
# Folders and permissions
#--------------------------------------------------------------------------
#

RUN mkdir -p /var/www \
    && mkdir -p /var/entrypoints \
    && mkdir -p /var/log/cron \
    && touch /var/log/crond.log

WORKDIR /var/www

#
#--------------------------------------------------------------------------
# Configuration
#--------------------------------------------------------------------------
#

COPY ./laravel.ini /usr/local/etc/php/conf.d/laravel.ini

COPY php-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf

COPY ./crontab /etc/crontabs/root

COPY ./supervisor.conf /etc/supervisord/

COPY ./entrypoints /var/entrypoints

COPY ./nginx /etc/nginx

EXPOSE 80 443

ENTRYPOINT ["/var/entrypoints/php-fpm"]

CMD /usr/bin/supervisord -n -c /etc/supervisord/supervisor.conf
