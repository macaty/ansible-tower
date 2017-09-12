# Ansible Tower Dockerfie
FROM ubuntu:xenial

LABEL maintainer thibaud.lepretre@gmail.com, mittell@gmail.com, reuben.stump@gmail.com, ybaltouski@gmail.com

ENV ANSIBLE_TOWER_VER 3.1.4

ENV PG_DATA /var/lib/postgresql/9.4/main

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

ADD http://releases.ansible.com/awx/setup/ansible-tower-setup-${ANSIBLE_TOWER_VER}.tar.gz /opt/ansible-tower-setup-${ANSIBLE_TOWER_VER}.tar.gz

RUN apt-get update \
    && apt-get install -y locales \
    && locale-gen "en_US.UTF-8" \
    && dpkg-reconfigure -f noninteractive locales \
    && apt-get install -y software-properties-common sudo gettext-base \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/log/tower \
    && tar xvf /opt/ansible-tower-setup-${ANSIBLE_TOWER_VER}.tar.gz -C /opt \
    && rm -f /opt/ansible-tower-setup-${ANSIBLE_TOWER_VER}.tar.gz

WORKDIR /opt/ansible-tower-setup-${ANSIBLE_TOWER_VER}
COPY inventory inventory

# Tower setup
RUN ./setup.sh -e "ansible_all_ipv6_addresses=[]" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY conf/postgres.py.template /etc/tower/conf.d/postgres.py.template
COPY conf/celeryd.py.template /etc/tower/conf.d/celeryd.py.template
COPY conf/caching.py.template /etc/tower/conf.d/caching.py.template
COPY conf/rabbitmq.py.template /etc/tower/conf.d/rabbitmq.py.template

ENV DATABASE_NAME awx
ENV DATABASE_USER awx
ENV DATABASE_PASSWORD password
ENV DATABASE_PORT 5432
ENV DATABASE_HOST 127.0.0.1
ENV RABBITMQ_USER tower
ENV RABBITMQ_PASSWORD password
ENV RABBITMQ_HOST localhost
ENV RABBITMQ_PORT 5672
ENV RABBITMQ_VHOST tower
ENV RABBITMQ_CLUSTER_HOST_ID localhost
ENV MEMCACHED_HOST localhost
ENV MEMCACHED_PORT 11211

# Docker entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# volumes and ports
VOLUME ["${PG_DATA}", "/certs"]
EXPOSE 443

CMD ["/docker-entrypoint.sh", "ansible-tower"]
