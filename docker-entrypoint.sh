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

    sed -i 's/supervisor//g' /etc/default/ansible-tower
    if [[ ! "$DATABASE_HOST" =~ (127\.0\.0\.1|localhost) ]]; then
        sed -i 's/postgresql//g' /etc/default/ansible-tower
        sed -i "s/pg_host=''/pg_host='$DATABASE_HOST'/g" /opt/ansible-tower-setup-${ANSIBLE_TOWER_VER}/inventory
        sed -i "s/pg_port=''/pg_port='$DATABASE_PORT'/g" /opt/ansible-tower-setup-${ANSIBLE_TOWER_VER}/inventory
    fi
    if [[ ! "$MEMCACHED_HOST" =~ (127\.0\.0\.1|localhost) ]]; then
        sed -i 's/memcached//g' /etc/default/ansible-tower
    fi
    if [[ ! "$RABBITMQ_HOST" =~ (127\.0\.0\.1|localhost) ]]; then
        sed -i 's/rabbitmq-server//g' /etc/default/ansible-tower
    fi

    ansible-tower-service start
    if [[ ! "$DATABASE_HOST" =~ (127\.0\.0\.1|localhost) ]]; then
        echo "Starting database settings migration..."
        tower-manage migrate_to_database_settings --skip-errors
        echo "Starting database migration..."
        tower-manage migrate --noinput --fake-initial
        echo "Starting static collections..."
        tower-manage collectstatic --noinput --clear -v0
        echo "Creating admin user"
        echo "from django.contrib.auth.models import User; User.objects.create_superuser('$TOWER_ADMIN_USER', '$TOWER_ADMIN_EMAIL', '$TOWER_ADMIN_PASSWORD')" | awx-manage shell 2> /dev/null
        #echo "Starting preload data creation..."
        #tower-manage create_preload_data        
    fi
    supervisord -n -c /etc/supervisor/supervisord.conf
else
    exec "$@"
fi
