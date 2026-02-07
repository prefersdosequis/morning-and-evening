# Android Studio Installation Complete

Android Studio has been downloaded and extracted to: `~/android-studio`

## To Start Android Studio

```bash
# Option 1: Direct path
~/android-studio/bin/studio.sh

# Option 2: After reloading shell (source ~/.bashrc)
android-studio
```

## First-Time Setup

When you first run Android Studio:

1. **Setup Wizard will appear:**
   - Choose "Standard" installation
   - It will download and install:
     - Android SDK
     - Android SDK Platform
     - Android SDK Build-Tools
     - Android Emulator (optional but recommended)

2. **Wait for downloads to complete** (this may take 10-20 minutes)

3. **After setup completes:**
   - Android SDK will be installed to: `~/Android/Sdk` (default location)

## Configure Flutter

After Android Studio setup is complete:

```bash
# Reload shell configuration
source ~/.bashrc

# Accept Android licenses
flutter doctor --android-licenses
# Type 'y' and press Enter for each license

# Verify setup
flutter doctor
```

The Android toolchain should now show as `[✓]` instead of `[✗]`.

## Create Desktop Shortcut (Optional)

Create a `.desktop` file for easy access:

```bash
cat > ~/.local/share/applications/android-studio.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Exec=/home/$USER/android-studio/bin/studio.sh
Icon=/home/$USER/android-studio/bin/studio.png
Terminal=false
Categories=Development;IDE;
EOF
```

Replace `$USER` with your actual username, or use:
```bash
sed "s/\$USER/$USER/g" > ~/.local/share/applications/android-studio.desktop
```

## Run Your Flutter App on Android

Once everything is set up:

```bash
cd "/RAID_Storage/AI Coding/Morning-and-Evening"

# Check available devices
flutter devices

# Run on Android device/emulator
flutter run -d android
```

## Troubleshooting

If you encounter issues:

1. **Check Android SDK location:**
   ```bash
   echo $ANDROID_HOME
   # Should show: /home/YOUR_USERNAME/Android/Sdk
   ```

2. **Set Android SDK manually (if needed):**
   ```bash
   flutter config --android-sdk ~/Android/Sdk
   ```

3. **Check Flutter doctor:**
   ```bash
   flutter doctor -v
   # Shows detailed information
   ```

## Next Steps

1. Start Android Studio: `~/android-studio/bin/studio.sh`
2. Complete the setup wizard
3. Accept Android licenses: `flutter doctor --android-licenses`
4. Run your app: `flutter run -d android`

Enjoy developing your Flutter mobile app!






