#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

MODE="http-only"

if all_group_certs_ready; then
  MODE="https"
else
  MISSING_GROUPS=$(print_missing_group_certs | tr '\n' ' ')
  echo "[nginx-gateway] missing cert groups, fallback to HTTP: $MISSING_GROUPS"
fi

render_template() {
  template_file=$1
  if command -v awk >/dev/null 2>&1; then
    awk '
      {
        line = $0
        while (match(line, /\$\{[A-Za-z_][A-Za-z0-9_]*\}/)) {
          key = substr(line, RSTART + 2, RLENGTH - 3)
          value = key in ENVIRON ? ENVIRON[key] : ""
          line = substr(line, 1, RSTART - 1) value substr(line, RSTART + RLENGTH)
        }
        print line
      }
    ' "$template_file"
    return 0
  fi
  if command -v perl >/dev/null 2>&1; then
    perl -pe 's/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/defined $ENV{$1} ? $ENV{$1} : ""/ge' "$template_file"
    return 0
  fi
  echo "[nginx-gateway] awk or perl is required to render templates" >&2
  exit 1
}

WROTE_TEMPLATE=0

append_template() {
  template_file=$1
  if [ "$WROTE_TEMPLATE" -eq 1 ]; then
    printf '\n'
  fi
  render_template "$template_file"
  WROTE_TEMPLATE=1
}

render_dir() {
  route_dir=$1
  [ -d "$route_dir" ] || return 0
  for template_file in "$route_dir"/*.conf; do
    [ -f "$template_file" ] || continue
    append_template "$template_file"
  done
}

{
  append_template "$ROOT_DIR/nginx/templates/preamble.conf"
  render_dir "$ENV_DIR/routes/$MODE"
} > "$ROOT_DIR/nginx/default.conf"

echo "[nginx-gateway] active environment: $APP_ENV"
echo "[nginx-gateway] active mode: $MODE"
