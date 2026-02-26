#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Dependency vulnerability scan (OSV)"
./scripts/osv_scan.sh

echo ""
echo "==> Pattern-based scan (Semgrep)"
./scripts/semgrep_scan.sh

