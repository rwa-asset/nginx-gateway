#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
FAKE_BIN=$(mktemp -d)

cleanup() {
  rm -rf "$FAKE_BIN"
}

trap cleanup EXIT

cat > "$FAKE_BIN/docker" <<'SCRIPT'
#!/usr/bin/env sh
printf 'pwd=%s\n' "$PWD"
printf 'args='
for arg in "$@"; do
  printf '[%s]' "$arg"
done
printf '\n'
SCRIPT
chmod +x "$FAKE_BIN/docker"

output=$(PATH="$FAKE_BIN:$PATH" APP_ENV=prod "$ROOT_DIR/scripts/compose.sh" config)

if ! printf '%s\n' "$output" | grep -Fq "[-f][$ROOT_DIR/docker-compose.yml]"; then
  echo "expected docker compose to use absolute compose file path" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

if printf '%s\n' "$output" | grep -Fq '[-f][docker-compose.yml]'; then
  echo "docker compose should not depend on the current working directory" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi
