# Installing Android Studio for Flutter Development

## Option 1: Download and Install Manually (Recommended)

1. **Visit the official download page:**
   - Go to: https://developer.android.com/studio
   - Click "Download Android Studio"

2. **Download for Linux:**
   - The website will detect your OS and provide the Linux version
   - Download the `.tar.gz` file (usually around 1GB)

3. **Extract and Install:**
   ```bash
   # Extract to a location (e.g., /opt or your home directory)
   cd ~/Downloads  # or wherever you downloaded it
   tar -xzf android-studio-*.tar.gz
   
   # Move to a permanent location
   sudo mv android-studio /opt/
   
   # Create a symlink or add to PATH
   sudo ln -s /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio
   ```

4. **Run Android Studio:**
   ```bash
   android-studio
   # Or directly:
   /opt/android-studio/bin/studio.sh
   ```

5. **First-time Setup:**
   - The setup wizard will guide you through:
     - Installing Android SDK
     - Setting up Android SDK Command-line Tools
     - Installing Android SDK Platform-Tools
     - Setting up an Android Virtual Device (AVD) - optional

6. **Configure Flutter:**
   After Android Studio is installed and SDK is set up:
   ```bash
   flutter doctor --android-licenses
   # Accept all licenses by typing 'y' when prompted
   
   flutter doctor
   # Should now show Android toolchain as [✓]
   ```

## Option 2: Using Snap (If Available)

```bash
sudo snap install android-studio --classic
```

## Option 3: Using Flatpak (If Available)

```bash
flatpak install flathub com.google.AndroidStudio
```

## After Installation

1. **Open Android Studio**
2. **Go through the Setup Wizard:**
   - Install Android SDK
   - Install SDK Platform
   - Install Android SDK Build-Tools

3. **Set Android SDK Location:**
   - Usually: `~/Android/Sdk` or `/opt/android-sdk`
   - You can check in Android Studio: Tools → SDK Manager

4. **Configure Flutter:**
   ```bash
   # If SDK is in a custom location:
   flutter config --android-sdk ~/Android/Sdk
   
   # Accept licenses:
   flutter doctor --android-licenses
   
   # Verify:
   flutter doctor
   ```

## System Requirements

- **RAM:** At least 8GB (16GB recommended)
- **Disk Space:** ~3GB for Android Studio + ~1GB for Android SDK
- **Java:** Android Studio includes its own JDK

## Troubleshooting

If you encounter issues:

1. **Check Java:**
   ```bash
   java -version
   ```
   Android Studio includes its own JDK, so this shouldn't be an issue.

2. **Check Android SDK:**
   ```bash
   echo $ANDROID_HOME
   # Should point to your SDK location
   ```

3. **Flutter Doctor:**
   ```bash
   flutter doctor -v
   # Shows detailed information about what's missing
   ```

## Next Steps

Once Android Studio and Android SDK are installed:

1. Accept Android licenses: `flutter doctor --android-licenses`
2. Create an Android Virtual Device (AVD) in Android Studio (optional, for emulator)
3. Connect a physical Android device or start an emulator
4. Run: `flutter run -d android`

Your Flutter app will then be able to build and run on Android devices!






