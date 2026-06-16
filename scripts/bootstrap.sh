#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

ensure_runtime_dirs
ensure_edge_network

"$SCRIPT_DIR/render-nginx-conf.sh"
docker_compose up -d nginx

if ! all_group_certs_ready; then
  if [ -n "$LETSENCRYPT_EMAIL" ]; then
    "$SCRIPT_DIR/request-cert.sh"
  else
    MISSING_GROUPS=$(print_missing_group_certs | tr '\n' ' ')
    echo "[nginx-gateway] missing cert groups: $MISSING_GROUPS"
    echo "[nginx-gateway] running in HTTP mode"
  fi
fi
