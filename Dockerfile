FROM centos:7

ENV php_conf /etc/php.ini
ENV fpm_conf /etc/php-fpm.conf
ENV www_conf /etc/php-fpm.d/www.conf
ENV PS1A="\[\e[33m\]\u\[\e[m\]\[\e[37m\]@\[\e[m\]\[\e[34m\]\h\[\e[m\]:\[\033[01;31m\]\W\[\e[m\]$ "

##### PS1 쉘 프롬프트 변경
RUN echo 'PS1=$PS1A' >> ~/.bashrc

##### 시스템 운영에 필요한 패키지 설치
RUN yum install -q -y epel-release yum-utils
RUN yum install -q -y curl gcc gcc-c++ make glibc-common \
    automake autoconf wget unzip
# RUN yum install -y tar vim telnet net-tools openssl

##### Apache 설치
RUN yum install -q -y nginx
RUN yum install -q -y nginx-all-modules

##### PHP 설치
RUN yum install -q -y http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
RUN yum-config-manager --enable remi-php74
RUN yum install -q -y php php-cli php-common php-devel php-fpm php-pear php-pdo
RUN yum install -q -y php-bcmath php-opcache php-mbstring php-gd php-json \
    php-xml php-mcrypt php-mysqlnd php-pecl-mcrypt php-pecl-mysql
RUN yes '' | pecl install -f igbinary redis \
  && echo "extension=redis.so" > /etc/php.d/ext-redis.ini \
  && yum install -q -y ImageMagick ImageMagick-devel \
  && yes '' | pecl install -f imagick \
  && echo "extension=imagick.so" > /etc/php.d/ext-imagick.ini

#####supervisor 
RUN yum install -q -y supervisor
COPY ./supervisord.conf /etc/supervisord.conf

##### PHP 설정(php.ini), PHP 버전 숨기기
RUN sed -i 's/expose_php = On/expose_php = Off/g' ${php_conf} \
  && sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} \
  && sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 256M/g" ${php_conf} \
  && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${php_conf} \
  && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${php_conf} \
  && sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf}

##### PHP-FPM 설정(www.conf)
# RUN sed -i -e 's/user = apache */user = nginx/' ${www_conf} \
#   && sed -i -e 's/group = apache */group = nginx/' ${www_conf} \
#   && sed -i -e 's/;listen.owner = nobody */listen.owner = nginx/' ${www_conf} \
#   && sed -i -e 's/;listen.group = nobody */listen.group = nginx/' ${www_conf} \
#   && sed -i -e 's/listen = 127.0.0.1:9000 */listen = \/var\/run\/php-fpm\/php-fpm.sock/' ${www_conf} \
#   && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" ${www_conf} \
#   && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${www_conf} \
#   && sed -i -e "s/pm.max_children = 50/pm.max_children = 50/g" ${www_conf} \
#   && sed -i -e "s/pm.start_servers = 5/pm.start_servers = 5/g" ${www_conf} \
#   && sed -i -e "s/pm.min_spare_servers = 5/pm.min_spare_servers = 5/g" ${www_conf} \
#   && sed -i -e "s/pm.max_spare_servers = 35/pm.max_spare_servers = 35/g" ${www_conf} \
#   && sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${www_conf} \
#   && sed -i -e "s/www-data/nginx/g" ${www_conf} \
#   && sed -i -e "s/^;clear_env = no$/clear_env = no/" ${www_conf}

##### composer
RUN curl -Ssf https://getcomposer.org/installer -o /tmp/composer-setup.php \
  && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --snapshot \
  #&& php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer \
  && rm -f /tmp/composer-setup.php \
  && cd /usr/share/nginx/html \
  && composer require nesbot/carbon

##### 운영체제 업데이트 및 yum cache 삭제
RUN yum update -y  \
  && yum clean all \
  && rm -rf /var/cache/yum \
  && rm -rf /var/tmp/* \
  && rm -rf /tmp/*

##### Nginx
COPY confdir/nginx/nginx.conf /etc/nginx/nginx.conf
ADD confdir/nginx/default.conf /etc/nginx/conf.d/default.conf
ADD confdir/nginx/laravel.php /usr/share/nginx/html/laravel.php

##### PHP-FPM(PHP)
# COPY confdir/php/php.ini /etc/php.ini
COPY confdir/php/php-fpm.conf /etc/php-fpm.conf
COPY confdir/php/www.conf /etc/php-fpm.d/www.conf

RUN rm -f /usr/share/nginx/html/index.html \
  && curl -s ifconfig.io > /usr/share/nginx/html/index.html \
  && echo "<?php phpinfo(); ?>" > /usr/share/nginx/html/phpinfo.php

ADD entry-point.sh /entry-point.sh
RUN chmod -x /entry-point.sh

WORKDIR /usr/share/nginx/html

EXPOSE 80

ENTRYPOINT ["/bin/bash", "/entry-point.sh"]
