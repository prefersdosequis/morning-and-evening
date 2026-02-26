#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SEMGREP_BIN=""
if command -v semgrep >/dev/null 2>&1; then
  SEMGREP_BIN="semgrep"
elif [ -x "tools/venv/bin/semgrep" ]; then
  SEMGREP_BIN="tools/venv/bin/semgrep"
else
  echo "semgrep not found. Install it with:" >&2
  echo "  ./scripts/install_semgrep.sh" >&2
  exit 1
fi

echo "==> Semgrep scan (local rules)"
"$SEMGREP_BIN" scan \
  --config semgrep/rules \
  --metrics=off

