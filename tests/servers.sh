#!/bin/sh
# Starts (up) or removes (down) the Postgres containers the tests run against:
#   127.0.0.1:5432  SCRAM-SHA-256 authentication
#   127.0.0.1:5433  md5 authentication
#   127.0.0.1:5434  SCRAM-SHA-256 over SSL (self-signed certificate)
#   127.0.0.1:5435  SSL only, SCRAM-SHA-256 plus a client certificate for the user, all
#                   signed by the test CA in tests/certs
# User: test, password: root, database: valk_postgres_tests
set -e
IMAGE=postgres:16-alpine
ENV="-e POSTGRES_USER=test -e POSTGRES_PASSWORD=root -e POSTGRES_DB=valk_postgres_tests"
CERTS="$(cd "$(dirname "$0")" && pwd)/certs"

exists() {
    docker ps -a --format '{{.Names}}' | grep -qx "$1"
}

# A CA, a server certificate for localhost and 127.0.0.1, and a client certificate for the
# user test, with its key also stored encrypted (password: secret)
make_certs() {
    mkdir -p "$CERTS"
    cd "$CERTS"
    openssl req -new -x509 -days 3650 -nodes -subj "/CN=valk-postgres test CA" -keyout ca.key -out ca.crt 2>/dev/null
    openssl req -new -nodes -subj "/CN=localhost" -keyout server.key -out server.csr 2>/dev/null
    echo "subjectAltName=DNS:localhost,IP:127.0.0.1" > server.ext
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 3650 -extfile server.ext -out server.crt 2>/dev/null
    openssl req -new -nodes -subj "/CN=test" -keyout client.key -out client.csr 2>/dev/null
    openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 3650 -out client.crt 2>/dev/null
    openssl pkey -in client.key -aes256 -passout pass:secret -out client-encrypted.key
    rm -f server.csr client.csr server.ext
    cd - >/dev/null
}

case "$1" in
up)
    exists valk-pg-scram || docker run -d --name valk-pg-scram $ENV -p 5432:5432 $IMAGE
    exists valk-pg-md5 || docker run -d --name valk-pg-md5 $ENV -e POSTGRES_HOST_AUTH_METHOD=md5 -e POSTGRES_INITDB_ARGS="--auth-host=md5" -p 5433:5432 $IMAGE
    if ! exists valk-pg-ssl; then
        docker run -d --name valk-pg-ssl $ENV -p 5434:5432 $IMAGE
        SELF_SIGNED=$(mktemp -d)
        openssl req -new -x509 -days 3650 -nodes -subj "/CN=localhost" -keyout "$SELF_SIGNED/server.key" -out "$SELF_SIGNED/server.crt" 2>/dev/null
        until docker exec valk-pg-ssl pg_isready -U test -h 127.0.0.1 >/dev/null 2>&1; do sleep 1; done
        docker cp "$SELF_SIGNED/server.crt" valk-pg-ssl:/var/lib/postgresql/server.crt
        docker cp "$SELF_SIGNED/server.key" valk-pg-ssl:/var/lib/postgresql/server.key
        docker exec valk-pg-ssl chown postgres:postgres /var/lib/postgresql/server.crt /var/lib/postgresql/server.key
        docker exec valk-pg-ssl chmod 600 /var/lib/postgresql/server.key
        docker exec valk-pg-ssl psql -U test -d valk_postgres_tests -q \
            -c "ALTER SYSTEM SET ssl = on" \
            -c "ALTER SYSTEM SET ssl_cert_file = '/var/lib/postgresql/server.crt'" \
            -c "ALTER SYSTEM SET ssl_key_file = '/var/lib/postgresql/server.key'" \
            -c "SELECT pg_reload_conf()" >/dev/null
        rm -rf "$SELF_SIGNED"
    fi
    if ! exists valk-pg-mtls; then
        [ -f "$CERTS/client.crt" ] || make_certs
        docker run -d --name valk-pg-mtls $ENV -p 5435:5432 $IMAGE
        until docker exec valk-pg-mtls pg_isready -U test -h 127.0.0.1 >/dev/null 2>&1; do sleep 1; done
        for file in ca.crt server.crt server.key; do
            docker cp "$CERTS/$file" valk-pg-mtls:/var/lib/postgresql/$file
        done
        docker exec valk-pg-mtls chown postgres:postgres /var/lib/postgresql/ca.crt /var/lib/postgresql/server.crt /var/lib/postgresql/server.key
        docker exec valk-pg-mtls chmod 600 /var/lib/postgresql/server.key
        docker exec valk-pg-mtls sh -c 'printf "local all all trust\nhostssl all all all scram-sha-256 clientcert=verify-full\n" > "$PGDATA/pg_hba.conf"'
        docker exec valk-pg-mtls psql -U test -d valk_postgres_tests -q \
            -c "ALTER SYSTEM SET ssl = on" \
            -c "ALTER SYSTEM SET ssl_cert_file = '/var/lib/postgresql/server.crt'" \
            -c "ALTER SYSTEM SET ssl_key_file = '/var/lib/postgresql/server.key'" \
            -c "ALTER SYSTEM SET ssl_ca_file = '/var/lib/postgresql/ca.crt'" \
            -c "SELECT pg_reload_conf()" >/dev/null
    fi
    for port in 5432 5433 5434 5435; do
        until pg_isready -h 127.0.0.1 -p $port >/dev/null 2>&1; do sleep 1; done
    done
    echo "Postgres test servers are ready"
    ;;
down)
    docker rm -f valk-pg-scram valk-pg-md5 valk-pg-ssl valk-pg-mtls
    rm -rf "$CERTS"
    ;;
*)
    echo "Usage: $0 up|down"
    exit 1
    ;;
esac
