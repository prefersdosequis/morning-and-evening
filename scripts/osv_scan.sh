#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OSV_BIN=""
if [ -x "tools/bin/osv-scanner" ]; then
  OSV_BIN="tools/bin/osv-scanner"
elif command -v osv-scanner >/dev/null 2>&1; then
  OSV_BIN="osv-scanner"
else
  echo "osv-scanner not found. Install it with:" >&2
  echo "  ./scripts/install_osv_scanner.sh" >&2
  exit 1
fi

if [ ! -f pubspec.lock ]; then
  echo "pubspec.lock not found. Run 'flutter pub get' first." >&2
  exit 1
fi

echo "==> OSV scan (pubspec.lock)"
"$OSV_BIN" scan -L pubspec.lock --format table

