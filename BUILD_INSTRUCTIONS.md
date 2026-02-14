# Build Instructions

## Overview

This app is a **text-only** devotional reader (Morning and Evening). No audio; no API keys required.

## Prerequisites

1. **Flutter SDK**: Installed and configured
2. **Android build tools**: For building APK/AAB

## Build for testing (debug APK)

```bash
flutter build apk --debug
# Install: adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Build for Google Play Store (release App Bundle)

1. Ensure you have a release keystore and `android/key.properties` (see PLAY_STORE_SECURITY.md).
2. Build the App Bundle with obfuscation:

```bash
flutter build appbundle \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Upload this AAB to Google Play Console.

## Assets

The app only bundles:

- `assets/devotions.json` – devotion content

No audio assets or external API keys are used.
