[![](https://images.microbadger.com/badges/image/kakawait/ansible-tower.svg)](https://microbadger.com/images/kakawait/ansible-tower "Get your own image badge on microbadger.com")

# ansible-tower

Dockerfile for [Ansible Tower](https://www.ansible.com/tower) 3.x+

# Build

```
docker build --no-cache -t ansible-tower:${TOWER_VERSION} .
```

# Run 

## Standalone mode

Standalone mode means everything is running on single container.

Run Ansible Tower with a random port:

```
docker run -d -P --name tower kakawait/ansible-tower
```

or map to exposed port 443:

```
docker run -d -p 443:443 --name tower kakawait/ansible-tower
```

To include certificate and license on container creation:

```
docker run -t -d -v ~/certs:/certs -p 443:443 -e SERVER_NAME=localhost  ansible-tower
```

To persist Ansible Tower database, create a data container:

```
docker create -v /var/lib/postgresql/9.4/main --name tower-data kakawait/ansible-tower /bin/true
docker run -d -p 444:443 --name tower --volumes-from tower-data kakawait/ansible-tower
```

## Compose mode

Compose mode means _Postgresql_, _Memcached_ and _RabbitMQ_ are running on separate containers.

Run using `docker-compose`

```
docker-compose up -d
```

By default `docker-compose.yml` exposes port 443 on random port. Please edit `docker-compose.yml` if you need other behavior.

### Restore in compose mode

```
docker-compose stop app
docker run -it --rm --network ansibletower_default --volumes-from ansibletower_app_1 -v $(pwd)/backup:/backup kakawait/ansible-tower ./setup.sh -e 'restore_backup_file=/backup/tower-restore.tar.gz' -r
docker-compose start app
```

# Administrator user

Container will create a administration user with following information:

- username: `admin`
- password: `password`
- email: `root@localhost`

(Never tested) You can change it by using environment variables: `TOWER_ADMIN_USER`, `TOWER_ADMIN_PASSWORD` and `TOWER_ADMIN_EMAIL`.

**ATTENTION** if you're changing those variables in existing env, that will create another admin user and previous one will still exists.

# Certificates and License

The ansible-tower Docker image uses a generic certificate generated for www.ansible.com by the Ansible Tower setup
program. If you generate your own certificate, it will be copied into /etc/tower by the entrypoint script if a volume
is mapped to /certs in the container, e.g:

* /certs/tower.cert -> /etc/tower/tower.cert
* /certs/tower.key  -> /etc/tower/tower.key

The environment variable SERVER_NAME should match the common name of the generated certificate and will be used to update
the nginx configuration file.

A license file can also be included similar to the certificates by renaming your Ansible Tower license file to **license** and
placing it in your local, mapped volume. The entrypoint script checks for the license file seperately and does not depend
on the certificates.

* /certs/license -> /etc/tower/license

The license file can also be uploaded on first login to the Ansible Tower web interface.

# Login

* URL: **https://localhost**
* Username: **admin**
* Password: **password**
