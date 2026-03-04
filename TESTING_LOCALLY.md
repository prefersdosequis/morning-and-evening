# Testing APK and OBB Locally

## Quick Method (Automated Script)

Run the installation script:
```bash
./install_for_testing.sh
```

This script will:
1. Check if your device is connected via USB
2. Build APK if needed
3. Create OBB file if needed
4. Install APK on your device
5. Copy OBB file to the correct location
6. Set proper permissions

## Manual Method

### Prerequisites
1. **Enable USB Debugging** on your Android device:
   - Go to Settings → About phone
   - Tap "Build number" 7 times to enable Developer options
   - Go back to Settings → Developer options
   - Enable "USB debugging"
   - Connect phone via USB and accept the prompt

2. **Install ADB** (Android Debug Bridge):
   - Usually comes with Android Studio
   - Or download from: https://developer.android.com/studio/releases/platform-tools

### Step 1: Verify Device Connection
```bash
adb devices
```
You should see your device listed.

### Step 2: Build APK (if not already built)
```bash
export PATH="$PATH:/RAID_Storage/AI Coding/flutter/bin"
flutter build apk --release
```

### Step 3: Create OBB File (if not already created)
```bash
./create_obb_files.sh
```

### Step 4: Install APK
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Step 5: Copy OBB File to Device
```bash
# Create OBB directory
adb shell mkdir -p /sdcard/Android/obb/com.spurgeon.morning_evening_app

# Copy OBB file (this takes a few minutes for 1.6 GB)
adb push build/obb/main.*.com.spurgeon.morning_evening_app.obb \
  /sdcard/Android/obb/com.spurgeon.morning_evening_app/

# Set permissions
adb shell chmod 644 /sdcard/Android/obb/com.spurgeon.morning_evening_app/main.*.obb
```

### Step 6: Verify Installation
```bash
# Check OBB file is in place
adb shell ls -lh /sdcard/Android/obb/com.spurgeon.morning_evening_app/

# Launch the app
adb shell am start -n com.spurgeon.morning_evening_app/.MainActivity
```

## OBB File Location

Android expects OBB files at:
```
/sdcard/Android/obb/<package_name>/main.<version_code>.<package_name>.obb
```

For this app:
```
/sdcard/Android/obb/com.spurgeon.morning_evening_app/main.1.com.spurgeon.morning_evening_app.obb
```

## Testing Checklist

After installation, verify:
- [ ] App launches successfully
- [ ] Devotional content displays correctly
- [ ] Play button appears (top-left corner)
- [ ] Audio plays when tapping play button
- [ ] Audio works offline (turn off WiFi/mobile data)
- [ ] All 732 devotions are accessible
- [ ] Audio files load correctly (check a few different days)

## Troubleshooting

### Device Not Detected
- Check USB cable connection
- Enable USB debugging
- Accept the "Allow USB debugging" prompt on device
- Try different USB port

### OBB File Not Found
- Verify OBB file exists: `ls -lh build/obb/*.obb`
- Check file was copied: `adb shell ls -lh /sdcard/Android/obb/com.spurgeon.morning_evening_app/`
- Ensure correct package name matches

### Audio Not Playing
- Check app logs: `adb logcat | grep -i audio`
- Verify OBB file size: Should be ~1.6 GB
- Check app has storage permissions
- Try uninstalling and reinstalling

### OBB File Too Large
- If copying fails, try using `adb push` with compression disabled
- Or copy via file manager app on device
- Or use wireless ADB if USB is slow

## Uninstalling

To remove the app and OBB files:
```bash
# Uninstall app
adb uninstall com.spurgeon.morning_evening_app

# Remove OBB files
adb shell rm -rf /sdcard/Android/obb/com.spurgeon.morning_evening_app
```

## Alternative: Manual File Transfer

If ADB push is too slow, you can:
1. Copy OBB file to phone via USB file transfer
2. Use a file manager app to move it to: `/Android/obb/com.spurgeon.morning_evening_app/`
3. Ensure file permissions are correct (readable)

## Notes

- OBB files are ZIP archives - Android extracts them automatically
- The app checks for audio files in assets first, then OBB location
- First launch may take longer as Android processes the OBB file
- Ensure device has enough storage space (~2 GB free)




