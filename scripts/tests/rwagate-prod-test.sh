#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
DEFAULT_CONF="$ROOT_DIR/nginx/default.conf"
BACKUP_CONF=$(mktemp)
CERT_ROOT="$ROOT_DIR/certbot/conf/live"
CERT_DIR="$CERT_ROOT/rwagate.net"
OPENSSL_CONF=$(mktemp)

cleanup() {
  if [ -f "$BACKUP_CONF" ]; then
    cp "$BACKUP_CONF" "$DEFAULT_CONF"
    rm -f "$BACKUP_CONF"
  fi
  rm -f "$OPENSSL_CONF"
  rm -f "$CERT_DIR/fullchain.pem" "$CERT_DIR/privkey.pem"
  rmdir "$CERT_DIR" "$CERT_ROOT" "$ROOT_DIR/certbot/conf" "$ROOT_DIR/certbot/www" 2>/dev/null || true
}

trap cleanup EXIT

assert_contains() {
  file=$1
  expected=$2
  if ! grep -Fq "$expected" "$file"; then
    echo "expected '$file' to contain: $expected" >&2
    exit 1
  fi
}

assert_not_contains() {
  file=$1
  unexpected=$2
  if grep -Fq "$unexpected" "$file"; then
    echo "expected '$file' to not contain: $unexpected" >&2
    exit 1
  fi
}

cp "$DEFAULT_CONF" "$BACKUP_CONF"
mkdir -p "$CERT_DIR"
{
  printf '%s\n' '[req]'
  printf '%s\n' 'distinguished_name=req_distinguished_name'
  printf '%s\n' 'x509_extensions=req_ext'
  printf '%s\n' 'prompt=no'
  printf '%s\n' '[req_distinguished_name]'
  printf '%s\n' 'CN=rwagate.net'
  printf '%s\n' '[req_ext]'
  printf '%s\n' 'subjectAltName=DNS:rwagate.net,DNS:www.rwagate.net,DNS:api.rwagate.net,DNS:admin.rwagate.net'
} > "$OPENSSL_CONF"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/privkey.pem" \
  -out "$CERT_DIR/fullchain.pem" \
  -days 1 \
  -config "$OPENSSL_CONF" >/dev/null 2>&1

APP_ENV=prod "$ROOT_DIR/scripts/render-nginx-conf.sh"

assert_contains "$DEFAULT_CONF" "server_name rwagate.net www.rwagate.net api.rwagate.net admin.rwagate.net;"
assert_contains "$DEFAULT_CONF" "server_name rwagate.net www.rwagate.net;"
assert_contains "$DEFAULT_CONF" "server_name api.rwagate.net;"
assert_contains "$DEFAULT_CONF" "server_name admin.rwagate.net;"
assert_contains "$DEFAULT_CONF" "root /var/www/wittgens/prod;"
assert_contains "$DEFAULT_CONF" "proxy_pass http://rwat-go-server:8000;"
assert_contains "$DEFAULT_CONF" "proxy_pass http://rwat-admin-ui:80;"
assert_contains "$DEFAULT_CONF" "ssl_certificate /etc/letsencrypt/live/rwagate.net/fullchain.pem;"
assert_not_contains "$DEFAULT_CONF" "uniamm.com"
assert_not_contains "$DEFAULT_CONF" "wittgens.cloud"
assert_not_contains "$DEFAULT_CONF" "opencoin"

echo "rwagate prod render assertions passed"
