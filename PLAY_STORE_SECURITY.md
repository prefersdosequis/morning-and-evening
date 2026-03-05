# Play Store Security Checklist

Use this checklist before uploading the app to the Google Play Store.

## Pre-submission security review (done)

- **Debug logging**: All `print()` and `debugPrint()` in `lib/` are wrapped in `if (kDebugMode)` so they do not run in release builds. No devotion content or internal paths are logged in production.
- **Audio delivery model**: Audio is delivered through Android Play Asset Delivery. No API keys are shipped in the app.

## Pre-upload checklist

- [ ] **Signing**: Create a release keystore and `android/key.properties` (never commit this file; it is in `.gitignore`).
- [ ] **Obfuscation**: Use the recommended build command below so Dart and native code are obfuscated.
- [ ] **Test release build**: Install the release APK or App Bundle locally and verify the app works.

## Recommended build command (release)

Build an **App Bundle** (required for Play Store) with obfuscation and split debug info:

```bash
# From project root
flutter build appbundle \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols
```

- `--obfuscate`: Obfuscates Dart code so it is harder to reverse-engineer.
- `--split-debug-info=...`: Saves symbol files for crash reports; keep these private and use them only for symbolication.

Output: `build/app/outputs/bundle/release/app-release.aab`

## Security features already in the app

| Feature | Location |
|--------|----------|
| **No cleartext traffic** | `AndroidManifest.xml`: `usesCleartextTraffic="false"` and `networkSecurityConfig` |
| **HTTPS-only network config** | `res/xml/network_security_config.xml` (trusts system CAs only) |
| **Backup disabled** | `allowBackup="false"` and `fullBackupContent` / `data_extraction_rules` exclude app data |
| **Release signing guardrail** | `android/app/build.gradle`: release build fails if `android/key.properties` is missing (no debug-sign fallback) |
| **Code obfuscation option** | Build with `--obfuscate --split-debug-info=...` for Dart symbol obfuscation in release |
| **ProGuard rules** | `android/app/proguard-rules.pro` (keeps Flutter and app entry points) |
| **Secrets not in repo** | `key.properties` in `.gitignore` (keystore only; no API keys in this app) |
| **Release logging** | All `print`/`debugPrint` in `lib/` guarded with `kDebugMode` (no-op in release) |

## What to never commit

- `android/key.properties` (keystore passwords and path)
- `build/app/outputs/symbols/` (debug symbols; keep for your crash reporting only)

## Optional: extra hardening

- **Certificate pinning**: If the app later adds a remote API, you can add pinning in `network_security_config.xml` (see Android docs).
- **Root detection**: Not required by Play Store; add only if you have a specific need to limit functionality on rooted devices.
