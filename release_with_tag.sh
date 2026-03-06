#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <tag-name>"
  echo "Example: $0 v2.0.0-audio"
  exit 1
fi

TAG_NAME="$1"
PUSH_TAG="${PUSH_TAG:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
KEY_PROPERTIES="android/key.properties"
ASSET_PACK_GRADLE="android/asset-packs/audio_assets/build.gradle"

echo "==> Starting tagged release in: $ROOT_DIR"
echo "==> Requested tag: $TAG_NAME"

for cmd in flutter git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: $cmd not found in PATH."
    exit 1
  fi
done

echo "==> Checking git status..."
GIT_STATUS="$(git status --porcelain)"
if [[ -n "$GIT_STATUS" && "${SKIP_GIT_CLEAN_CHECK:-0}" != "1" ]]; then
  echo "ERROR: Working tree is not clean."
  git status --short
  echo "Commit/stash first, or rerun with SKIP_GIT_CLEAN_CHECK=1."
  exit 1
fi

BRANCH="$(git branch --show-current)"
COMMIT_SHA="$(git rev-parse --short HEAD)"

echo "==> Git context:"
echo "    Branch: $BRANCH"
echo "    Commit: $COMMIT_SHA"

if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
  echo "ERROR: Tag already exists: $TAG_NAME"
  exit 1
fi

echo "==> flutter pub get"
flutter pub get

if [[ "${SKIP_ANALYZE:-0}" != "1" ]]; then
  echo "==> flutter analyze"
  flutter analyze
else
  echo "==> Skipping analyze"
fi

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  echo "==> flutter test"
  flutter test
else
  echo "==> Skipping tests"
fi

echo "==> Checking signing prerequisites..."
if [[ ! -f "$KEY_PROPERTIES" ]]; then
  echo "ERROR: Missing $KEY_PROPERTIES"
  exit 1
fi

STORE_FILE="$(grep -E '^storeFile=' "$KEY_PROPERTIES" | head -n1 | cut -d'=' -f2- || true)"
if [[ -z "$STORE_FILE" ]]; then
  echo "ERROR: storeFile missing in $KEY_PROPERTIES"
  exit 1
fi
if [[ ! -f "$STORE_FILE" ]]; then
  echo "ERROR: Keystore file not found: $STORE_FILE"
  exit 1
fi

echo "==> Checking asset pack config..."
if [[ ! -f "$ASSET_PACK_GRADLE" ]]; then
  echo "ERROR: Missing asset pack config: $ASSET_PACK_GRADLE"
  exit 1
fi

echo "==> Building signed release AAB..."
flutter build appbundle --release

if [[ ! -f "$AAB_PATH" ]]; then
  echo "ERROR: AAB not found: $AAB_PATH"
  exit 1
fi

echo "==> Built AAB:"
ls -lh "$AAB_PATH"

echo "==> Verifying AAB contains audio_assets..."
if command -v zipinfo >/dev/null 2>&1; then
  AUDIO_MATCH_COUNT="$(zipinfo -1 "$AAB_PATH" | grep -c 'audio_assets' || true)"
elif command -v unzip >/dev/null 2>&1; then
  AUDIO_MATCH_COUNT="$(unzip -l "$AAB_PATH" | grep -c 'audio_assets' || true)"
else
  AUDIO_MATCH_COUNT=""
  echo "WARNING: zipinfo/unzip not available; skipping AAB asset check."
fi

if [[ -n "${AUDIO_MATCH_COUNT}" ]]; then
  if [[ "$AUDIO_MATCH_COUNT" -le 0 ]]; then
    echo "ERROR: No audio_assets entries found in AAB."
    exit 1
  fi
  echo "✓ audio_assets entries found: $AUDIO_MATCH_COUNT"
fi

echo "==> Creating tag: $TAG_NAME"
git tag -a "$TAG_NAME" -m "Release $TAG_NAME (audio-enabled)"

if [[ "$PUSH_TAG" == "1" ]]; then
  echo "==> Pushing tag to origin..."
  git push origin "$TAG_NAME"
else
  echo "==> PUSH_TAG=0, keeping tag local only."
fi

NEW_SHA="$(git rev-parse --short HEAD)"
DATE_UTC="$(date -u +"%Y-%m-%d %H:%M UTC")"

cat <<EOF

============================================================
RELEASE COMPLETE
============================================================
Tag:        $TAG_NAME
Branch:     $BRANCH
Commit:     $NEW_SHA
Built at:   $DATE_UTC
AAB:        $AAB_PATH

Play Console Release Notes Template
-----------------------------------
Title:
$TAG_NAME - Audio Enabled Release

What's new:
- Added full devotional audio playback support with install-time asset delivery.
- Fixed devotional text formatting so opening scripture verse/reference is consistently separated from body text.
- Fixed split asset cache invalidation to ensure refreshed audio is picked up after updates.
- Improved reliability for devotional entries that previously had incomplete playback.

Internal QA checklist:
- [ ] Verify March 5 Morning full audio
- [ ] Verify March 18 Morning full audio
- [ ] Verify March 21 Morning verse/reference formatting
- [ ] Verify March 31 Evening verse/reference formatting
- [ ] Verify fresh install downloads audio assets correctly from Play

============================================================
Next:
1) Upload AAB to Play Console (Internal/Closed/Production).
2) Confirm version code accepted.
3) Paste release notes (edit as needed).
============================================================

EOF
