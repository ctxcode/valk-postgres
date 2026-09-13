#!/bin/sh
# Starts (up) or removes (down) the Postgres containers the tests run against:
#   127.0.0.1:5432  SCRAM-SHA-256 authentication
#   127.0.0.1:5433  md5 authentication
#   127.0.0.1:5434  SCRAM-SHA-256 over SSL (self-signed certificate)
# User: test, password: root, database: valk_postgres_tests
set -e
IMAGE=postgres:16-alpine
ENV="-e POSTGRES_USER=test -e POSTGRES_PASSWORD=root -e POSTGRES_DB=valk_postgres_tests"

exists() {
    docker ps -a --format '{{.Names}}' | grep -qx "$1"
}

case "$1" in
up)
    exists valk-pg-scram || docker run -d --name valk-pg-scram $ENV -p 5432:5432 $IMAGE
    exists valk-pg-md5 || docker run -d --name valk-pg-md5 $ENV -e POSTGRES_HOST_AUTH_METHOD=md5 -e POSTGRES_INITDB_ARGS="--auth-host=md5" -p 5433:5432 $IMAGE
    if ! exists valk-pg-ssl; then
        docker run -d --name valk-pg-ssl $ENV -p 5434:5432 $IMAGE
        CERTS=$(mktemp -d)
        openssl req -new -x509 -days 3650 -nodes -subj "/CN=localhost" -keyout "$CERTS/server.key" -out "$CERTS/server.crt" 2>/dev/null
        until docker exec valk-pg-ssl pg_isready -U test -h 127.0.0.1 >/dev/null 2>&1; do sleep 1; done
        docker cp "$CERTS/server.crt" valk-pg-ssl:/var/lib/postgresql/server.crt
        docker cp "$CERTS/server.key" valk-pg-ssl:/var/lib/postgresql/server.key
        docker exec valk-pg-ssl chown postgres:postgres /var/lib/postgresql/server.crt /var/lib/postgresql/server.key
        docker exec valk-pg-ssl chmod 600 /var/lib/postgresql/server.key
        docker exec valk-pg-ssl psql -U test -d valk_postgres_tests -q \
            -c "ALTER SYSTEM SET ssl = on" \
            -c "ALTER SYSTEM SET ssl_cert_file = '/var/lib/postgresql/server.crt'" \
            -c "ALTER SYSTEM SET ssl_key_file = '/var/lib/postgresql/server.key'" \
            -c "SELECT pg_reload_conf()" >/dev/null
        rm -rf "$CERTS"
    fi
    for port in 5432 5433 5434; do
        until pg_isready -h 127.0.0.1 -p $port >/dev/null 2>&1; do sleep 1; done
    done
    echo "Postgres test servers are ready"
    ;;
down)
    docker rm -f valk-pg-scram valk-pg-md5 valk-pg-ssl
    ;;
*)
    echo "Usage: $0 up|down"
    exit 1
    ;;
esac
