#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$ROOT/nakumi-sync/update-server.sh"
exec bash "$ROOT/start.sh"
