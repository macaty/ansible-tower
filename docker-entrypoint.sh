#!/bin/bash
# Modified for Ansible Tower 3.x from https://github.com/ybalt/ansible-tower/blob/master/docker-entrypoint.sh

set -e

NGINX_CONF=/etc/nginx/nginx.conf

trap "kill -15 -1 && echo all proc killed" TERM KILL INT

if [ "$1" = "ansible-tower" ]; then
    envsubst < /etc/tower/conf.d/celeryd.py.template > /etc/tower/conf.d/celeryd.py
    envsubst < /etc/tower/conf.d/postgres.py.template > /etc/tower/conf.d/postgres.py
    envsubst < /etc/tower/conf.d/caching.py.template > /etc/tower/conf.d/caching.py
    envsubst < /etc/tower/conf.d/rabbitmq.py.template > /etc/tower/conf.d/rabbitmq.py
    
    if [[ $SERVER_NAME ]]; then
        echo "add $SERVER_NAME to server_name"
        cat $NGINX_CONF | grep -q "server_name _" \
        && sed -i -e "s/server_name\s_/server_name $SERVER_NAME/" $NGINX_CONF
    fi
    
    if [[ -a /certs/tower.cert && -a /certs/tower.key ]]; then
        echo "copy new certs"
        cp -r /certs/tower.cert /etc/tower/tower.cert
        chown awx:awx /etc/tower/tower.cert
        cp -r /certs/tower.key /etc/tower/tower.key
        chown awx:awx /etc/tower/tower.key
    fi
    
    if [[ -a /certs/license ]]; then
        echo "copy new license"
        cp -r /certs/license /etc/tower/license
        chown awx:awx /etc/tower/license
    fi

    sed -i 's/ supervisor//g' /etc/default/ansible-tower

    ansible-tower-service start
    if [[ "$DATABASE_HOST" != "localhost" ]] || [[ "$DATABASE_HOST" != "127.0.0.1" ]]; then
        tower-manage migrate_to_database_settings --skip-errors
        tower-manage migrate --noinput --fake-initial
        tower-manage create_preload_data
        echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'root@localhost', 'password')" | awx-manage shell
    fi
    supervisord -n -c /etc/supervisor/supervisord.conf
else
    exec "$@"
fi
