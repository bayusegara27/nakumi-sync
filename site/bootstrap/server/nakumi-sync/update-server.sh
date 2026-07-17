#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="$ROOT/nakumi-sync"
URL_FILE="$SYNC/channel-url.txt"
BOOTSTRAP="$SYNC/packwiz-installer-bootstrap.jar"
STATE="$SYNC/state"
LOGS="$SYNC/logs"
mkdir -p "$STATE" "$LOGS"

if [[ ! -f "$URL_FILE" || ! -f "$BOOTSTRAP" ]]; then
  echo "Nakumi Sync belum dikonfigurasi. Jalankan bash INSTALL-NAKUMI-SYNC-SERVER.sh" >&2
  exit 2
fi
BASE_URL="$(tr -d '\r\n' < "$URL_FILE")"
BASE_URL="${BASE_URL%/}"
if [[ ! "$BASE_URL" =~ ^https?:// ]]; then
  echo "channel-url.txt harus berisi URL HTTP/HTTPS" >&2
  exit 2
fi

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then wget -qO- "$1"
  else echo "curl atau wget diperlukan" >&2; return 127
  fi
}

REMOTE_VERSION="$(fetch "$BASE_URL/server/channel-version.txt" | tr -d '\r\n')"
PATHS_FILE="$(mktemp)"
trap 'rm -f "$PATHS_FILE"' EXIT
fetch "$BASE_URL/server/backup-paths.txt" > "$PATHS_FILE"
LAST_VERSION=""
[[ -f "$STATE/last-version.txt" ]] && LAST_VERSION="$(tr -d '\r\n' < "$STATE/last-version.txt")"

if [[ "$REMOTE_VERSION" != "$LAST_VERSION" ]]; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP="$ROOT/backups/nakumi-sync/$STAMP-$REMOTE_VERSION"
  while IFS= read -r REL || [[ -n "$REL" ]]; do
    REL="${REL%$'\r'}"
    [[ -z "$REL" ]] && continue
    case "/$REL/" in *"/../"*|*"/./"*) echo "Path backup tidak aman: $REL" >&2; exit 3;; esac
    [[ "$REL" = /* ]] && { echo "Path absolut ditolak: $REL" >&2; exit 3; }
    if [[ -f "$ROOT/$REL" ]]; then
      mkdir -p "$BACKUP/$(dirname "$REL")"
      cp -a "$ROOT/$REL" "$BACKUP/$REL"
    fi
  done < "$PATHS_FILE"
  mkdir -p "$BACKUP"
  printf '%s\n' "$LAST_VERSION" > "$BACKUP/from-version.txt"
fi

LOG="$LOGS/update-$(date +%Y%m%d-%H%M%S).log"
cd "$ROOT"
set +e
java -jar "$BOOTSTRAP" -g -s server "$BASE_URL/server/pack.toml" 2>&1 | tee "$LOG"
CODE=${PIPESTATUS[0]}
set -e
if [[ $CODE -ne 0 ]]; then
  echo "Nakumi Sync gagal (exit $CODE). Server dibatalkan agar tidak menjalankan versi setengah terpasang." >&2
  exit "$CODE"
fi
printf '%s\n' "$REMOTE_VERSION" > "$STATE/last-version.txt"
echo "Nakumi Sync server sudah versi $REMOTE_VERSION"
