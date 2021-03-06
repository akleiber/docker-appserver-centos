FROM centos:7

MAINTAINER Andreas Kleiber <ak@9dot.de>

# set some variables to easily update appserver.io version
ENV APPSERVER_VERSION 1.1.0
ENV APPSERVER_RUNTIME_BUILD_VERSION 1.1.0-26
ENV APPSERVER_RUNTIME_FILE_PATH /tmp/appserver-runtime.rpm
ENV APPSERVER_SOURCE_VERSION 1.1.0

# add repos for appserver.io dependencies
RUN yum install -y epel-release wget

RUN wget -O /tmp/remi.rpm \
		http://rpms.famillecollet.com/enterprise/remi-release-7.rpm

RUN rpm -i /tmp/remi.rpm

# install appserver.io runtime and dependencies
RUN wget -O ${APPSERVER_RUNTIME_FILE_PATH} \
		https://github.com/appserver-io/appserver/releases/download/${APPSERVER_VERSION}/appserver-runtime-${APPSERVER_RUNTIME_BUILD_VERSION}.el7.centos.x86_64.rpm

RUN yum --nogpgcheck localinstall -y ${APPSERVER_RUNTIME_FILE_PATH}
RUN rm -f ${APPSERVER_RUNTIME_FILE_PATH}

# make appserver.io php always available
RUN ln -s /opt/appserver/bin/php /usr/local/bin/php

# install composer
RUN php -r "readfile('https://getcomposer.org/installer');" \
		| php -- --install-dir=/usr/local/bin --filename=composer

# install appserver.io dist
# download appserver source in specific version
RUN cd /root && wget https://github.com/appserver-io/appserver/archive/${APPSERVER_SOURCE_VERSION}.tar.gz && \

    # extract appserversource
    tar -xzf ${APPSERVER_SOURCE_VERSION}.tar.gz && cd appserver-${APPSERVER_SOURCE_VERSION} && \

    # install dependencies using composer, use --prefer-source to avoid github rate limit
    composer install --no-dev --no-interaction --prefer-source && \

    # modify user-rights in configuration
    sed -i "s/www-data/root/g" etc/appserver/appserver.xml && \

    # copy appserver source using ant integration
    cp -r * /opt/appserver/ && \

		# remove appserver source download
		rm -f /root/${APPSERVER_SOURCE_VERSION}.tar.gz

# install supervisor, the system that makes sure appserver processes are running
RUN yum install -y supervisor
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/

# forward request and error logs to docker log collector
RUN ln -sf /dev/stderr /opt/appserver/var/log/php_errors.log

# expose ports
EXPOSE 9080 9443

# run supervisord
CMD ["/usr/bin/supervisord"]
