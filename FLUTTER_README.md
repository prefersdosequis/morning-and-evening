# Morning and Evening - Flutter Mobile App

A beautiful Flutter mobile application for reading Charles H. Spurgeon's "Morning and Evening" devotional. This app displays morning devotions on odd-numbered pages and evening devotions on even-numbered pages, creating a seamless reading experience through the entire year.

## Features

- **Beautiful, Modern UI**: Clean, responsive design with gradient backgrounds
- **Easy Navigation**: Previous/Next buttons with haptic feedback
- **Progress Tracking**: Visual progress bar showing reading progress
- **Persistent State**: Remembers your current page using SharedPreferences
- **Scripture Formatting**: Scripture verses and references are automatically italicized
- **Offline Support**: All content is bundled with the app

## Prerequisites

### Flutter Installation

Flutter has been installed in: `/RAID_Storage/AI Coding/flutter`

To use Flutter in your terminal, add it to your PATH:
```bash
export PATH="$PATH:/RAID_Storage/AI Coding/flutter/bin"
```

Or add this line to your `~/.bashrc` or `~/.zshrc`:
```bash
export PATH="$PATH:/RAID_Storage/AI Coding/flutter/bin"
```

### Required Dependencies

For Android development, you'll need:
- Android Studio (for Android SDK)
- Android SDK tools

For iOS development (macOS only):
- Xcode
- CocoaPods

For Linux desktop:
```bash
sudo apt install clang libgtk-3-dev
```

## Running the App

### Check Flutter Setup
```bash
flutter doctor
```

### Get Dependencies
```bash
flutter pub get
```

### Run on Available Devices

**Web (Chrome):**
```bash
flutter run -d chrome
```

**Android (requires Android SDK):**
```bash
flutter run -d android
```

**iOS (macOS only):**
```bash
flutter run -d ios
```

**Linux Desktop:**
```bash
flutter run -d linux
```

## Project Structure

```
lib/
├── main.dart                 # Main app entry point and UI
├── models/
│   └── devotion.dart        # Devotion data model
├── services/
│   └── devotion_service.dart # Service to load devotions from JSON
└── utils/
    ├── storage_service.dart  # SharedPreferences wrapper for saving state
    └── text_formatter.dart   # Formats content and italicizes scripture
assets/
└── devotions.json            # All 730 devotions (365 days × 2)
```

## Building for Release

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

### iOS (macOS only)
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Code Quality & Security Checks (Open Source)

### Lint + format checks

```bash
./scripts/lint.sh
```

- Fails if formatting changes are needed or if there are analyzer warnings/errors.
- Analyzer "info" suggestions are shown but are **not fatal**.

To apply formatting:

```bash
./scripts/format.sh
```

### Vulnerability + security scanning

Install OSV-Scanner (local binary under `tools/bin/`):

```bash
./scripts/install_osv_scanner.sh
```

Install Semgrep (installed into `tools/venv/` if `pipx` is not available):

```bash
./scripts/install_semgrep.sh
```

Run both scans:

```bash
./scripts/security_scan.sh
```

## Features Implemented

✅ All 730 devotions loaded from JSON
✅ Morning/Evening alternating pages
✅ Navigation with Previous/Next buttons
✅ Progress bar
✅ Persistent page state
✅ Scripture verses italicized
✅ Centered text layout
✅ Beautiful gradient UI
✅ Responsive design

## Next Steps

To build for Android devices, you'll need to:
1. Install Android Studio from https://developer.android.com/studio
2. Install Android SDK through Android Studio
3. Accept Android licenses: `flutter doctor --android-licenses`
4. Connect an Android device or start an emulator
5. Run: `flutter run -d android`

## Notes

- The app uses SharedPreferences to save your current page
- All devotional content is bundled in the app (no internet required)
- The app works offline once installed
- Scripture detection uses pattern matching to identify verses and references






