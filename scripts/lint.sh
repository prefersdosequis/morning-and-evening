#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Dart format (check)"
dart format --output=none --set-exit-if-changed lib test

echo "==> Flutter analyze"
flutter analyze --no-fatal-infos

