#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

assert_contains() {
  text=$1
  expected=$2
  if ! printf '%s\n' "$text" | grep -Fq "$expected"; then
    echo "expected compose config to contain: $expected" >&2
    exit 1
  fi
}

assert_not_contains() {
  text=$1
  unexpected=$2
  if printf '%s\n' "$text" | grep -Fq "$unexpected"; then
    echo "expected compose config to not contain: $unexpected" >&2
    exit 1
  fi
}

prod_config=$(APP_ENV=prod "$ROOT_DIR/scripts/compose.sh" config)
assert_contains "$prod_config" "container_name: rwagate-nginx"
assert_contains "$prod_config" "name: rwat-edge"
assert_contains "$prod_config" "source: /var/www/wittgens"
assert_contains "$prod_config" "target: /var/www/wittgens"
assert_not_contains "$prod_config" "opencoin"
assert_not_contains "$prod_config" "source: /var/www/wittgens/prod"
