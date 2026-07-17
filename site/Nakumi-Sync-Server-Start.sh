#!/usr/bin/env bash
set -euo pipefail

CHANNEL="https://bayusegara27.github.io/nakumi-sync"
ROOT="${NAKUMI_SERVER_ROOT:-$PWD}"
SYNC="$ROOT/nakumi-sync"
mkdir -p "$SYNC"

if [[ ! -f "$ROOT/start.sh" ]]; then
  echo "Jalankan command ini dari root server yang berisi start.sh" >&2
  exit 2
fi

curl -fsSL "$CHANNEL/bootstrap/server/start-with-sync.sh" -o "$ROOT/start-with-sync.sh"
curl -fsSL "$CHANNEL/bootstrap/server/nakumi-sync/update-server.sh" -o "$SYNC/update-server.sh"
curl -fsSL "$CHANNEL/bootstrap/server/nakumi-sync/packwiz-installer-bootstrap.jar" -o "$SYNC/packwiz-installer-bootstrap.jar"
printf '%s\n' "$CHANNEL" > "$SYNC/channel-url.txt"
chmod +x "$ROOT/start-with-sync.sh" "$SYNC/update-server.sh"
exec bash "$ROOT/start-with-sync.sh"

