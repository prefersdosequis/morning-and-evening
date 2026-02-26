#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH_RAW" >&2; exit 1 ;;
esac
export OS ARCH

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to install osv-scanner (used for GitHub API JSON parsing)." >&2
  exit 1
fi

mkdir -p tools/bin

echo "==> Resolving latest osv-scanner release asset for ${OS}_${ARCH}"
ASSET_URL="$(
python3 - <<'PY'
import json, os, re, sys, urllib.request

os_name = os.environ["OS"]
arch = os.environ["ARCH"]

api = "https://api.github.com/repos/google/osv-scanner/releases/latest"
req = urllib.request.Request(api, headers={"Accept": "application/vnd.github+json", "User-Agent": "repo-installer"})
with urllib.request.urlopen(req, timeout=30) as r:
    data = json.load(r)

assets = data.get("assets", [])
pattern = re.compile(rf"^osv-scanner(?:_.*)?_{re.escape(os_name)}_{re.escape(arch)}(?:\\.exe)?$")

for a in assets:
    name = a.get("name", "")
    if pattern.match(name):
        print(a.get("browser_download_url", ""))
        sys.exit(0)

print("", end="")
sys.exit(0)
PY
)"

if [ -z "$ASSET_URL" ]; then
  echo "Could not find a matching osv-scanner release asset for ${OS}_${ARCH}." >&2
  echo "Visit the releases page and download manually:" >&2
  echo "  https://github.com/google/osv-scanner/releases" >&2
  exit 1
fi

echo "==> Downloading osv-scanner"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
curl -fsSL "$ASSET_URL" -o "$TMP"

install -m 0755 "$TMP" tools/bin/osv-scanner

echo "==> Installed: tools/bin/osv-scanner"
tools/bin/osv-scanner --version || true

