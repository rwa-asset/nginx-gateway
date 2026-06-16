#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
DEFAULT_CONF="$ROOT_DIR/nginx/default.conf"
BACKUP_CONF=$(mktemp)
CERT_ROOT="$ROOT_DIR/certbot/conf/live"
CREATED_CERT_DIRS=""
CREATED_FULLCHAINS=""
CREATED_PRIVKEYS=""
CREATED_TMP_FILES=""

cleanup() {
  if [ -f "$BACKUP_CONF" ]; then
    cp "$BACKUP_CONF" "$DEFAULT_CONF"
    rm -f "$BACKUP_CONF"
  fi
  for file in $CREATED_FULLCHAINS; do
    rm -f "$file"
  done
  for file in $CREATED_PRIVKEYS; do
    rm -f "$file"
  done
  for dir in $CREATED_CERT_DIRS; do
    rmdir "$dir" 2>/dev/null || true
  done
  for file in $CREATED_TMP_FILES; do
    rm -f "$file"
  done
  rmdir "$CERT_ROOT" 2>/dev/null || true
}

assert_contains() {
  file=$1
  expected=$2
  if ! grep -Fq "$expected" "$file"; then
    echo "expected $file to contain: $expected" >&2
    exit 1
  fi
}

assert_not_contains() {
  file=$1
  unexpected=$2
  if grep -Fq "$unexpected" "$file"; then
    echo "expected $file to not contain: $unexpected" >&2
    exit 1
  fi
}

cp "$DEFAULT_CONF" "$BACKUP_CONF"
trap cleanup EXIT

create_test_cert() {
  cert_name=$1
  cert_domains=$2
  cert_dir="$CERT_ROOT/$cert_name"
  if [ ! -d "$cert_dir" ]; then
    mkdir -p "$cert_dir"
    CREATED_CERT_DIRS="$cert_dir $CREATED_CERT_DIRS"
  fi

  if [ ! -f "$cert_dir/fullchain.pem" ] || [ ! -f "$cert_dir/privkey.pem" ]; then
    if [ -f "$cert_dir/fullchain.pem" ]; then
      echo "test cert is partially present, refusing to overwrite: $cert_dir/fullchain.pem" >&2
      exit 1
    fi
    if [ -f "$cert_dir/privkey.pem" ]; then
      echo "test cert is partially present, refusing to overwrite: $cert_dir/privkey.pem" >&2
      exit 1
    fi

    san_list=""
    for domain in $cert_domains; do
      if [ -n "$san_list" ]; then
        san_list="$san_list,"
      fi
      san_list="${san_list}DNS:$domain"
    done

    openssl_conf=$(mktemp)
    CREATED_TMP_FILES="$openssl_conf $CREATED_TMP_FILES"
    {
      printf '%s\n' '[req]'
      printf '%s\n' 'distinguished_name=req_distinguished_name'
      printf '%s\n' 'x509_extensions=req_ext'
      printf '%s\n' 'prompt=no'
      printf '%s\n' '[req_distinguished_name]'
      printf 'CN=%s\n' "$cert_name"
      printf '%s\n' '[req_ext]'
      printf 'subjectAltName=%s\n' "$san_list"
    } > "$openssl_conf"

    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout "$cert_dir/privkey.pem" \
      -out "$cert_dir/fullchain.pem" \
      -days 1 \
      -config "$openssl_conf" >/dev/null 2>&1
    CREATED_FULLCHAINS="$cert_dir/fullchain.pem $CREATED_FULLCHAINS"
    CREATED_PRIVKEYS="$cert_dir/privkey.pem $CREATED_PRIVKEYS"
    return 0
  fi

  return 0
}

create_test_cert "rwagate.net" "rwagate.net www.rwagate.net api.rwagate.net admin.rwagate.net"

APP_ENV=prod "$ROOT_DIR/scripts/render-nginx-conf.sh"
assert_contains "$DEFAULT_CONF" "server_name rwagate.net www.rwagate.net api.rwagate.net admin.rwagate.net;"
assert_contains "$DEFAULT_CONF" "server_name rwagate.net www.rwagate.net;"
assert_contains "$DEFAULT_CONF" "server_name api.rwagate.net;"
assert_contains "$DEFAULT_CONF" "server_name admin.rwagate.net;"
assert_contains "$DEFAULT_CONF" "listen 443 ssl http2;"
assert_contains "$DEFAULT_CONF" "ssl_certificate /etc/letsencrypt/live/rwagate.net/fullchain.pem;"
assert_contains "$DEFAULT_CONF" "root /var/www/wittgens/prod;"
assert_contains "$DEFAULT_CONF" "proxy_pass http://rwat-go-server:8000;"
assert_contains "$DEFAULT_CONF" "proxy_pass http://rwat-admin-ui:80;"
assert_contains "$DEFAULT_CONF" 'try_files $uri $uri/ /index.html;'
assert_not_contains "$DEFAULT_CONF" "uniamm.com"
assert_not_contains "$DEFAULT_CONF" "wittgens.cloud"
assert_not_contains "$DEFAULT_CONF" "opencoin"
assert_not_contains "$DEFAULT_CONF" "api.md-zgxt.com"
assert_not_contains "$DEFAULT_CONF" "debug-test.md-zgxt.com"
