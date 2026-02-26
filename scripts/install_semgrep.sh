#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if command -v semgrep >/dev/null 2>&1; then
  echo "==> semgrep already installed"
  semgrep --version
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to install semgrep." >&2
  exit 1
fi

echo "==> Installing semgrep (user install)"
if command -v pipx >/dev/null 2>&1; then
  pipx install semgrep
else
  echo "pipx not found (and system python is externally-managed). Installing into tools/venv instead."
  python3 -m venv tools/venv
  tools/venv/bin/python -m pip install --upgrade pip
  tools/venv/bin/python -m pip install semgrep
fi

echo "==> semgrep installed"
if command -v semgrep >/dev/null 2>&1; then
  semgrep --version
else
  tools/venv/bin/semgrep --version
fi

