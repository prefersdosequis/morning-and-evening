#!/bin/bash
# Install APK and OBB file on connected Android device for testing
# Requires: ADB (Android Debug Bridge) and USB debugging enabled on device

set -e

cd "/RAID_Storage/AI Coding/Morning-and-Evening"

PACKAGE_NAME="com.spurgeon.morning_evening_app"
VERSION_CODE="1"  # Default, update if needed
OBB_DIR="/sdcard/Android/obb/$PACKAGE_NAME"

echo "Installing APK and OBB for testing..."
echo ""

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "Error: No Android device connected or USB debugging not enabled"
    echo ""
    echo "To enable USB debugging:"
    echo "1. Go to Settings → About phone"
    echo "2. Tap 'Build number' 7 times"
    echo "3. Go back to Settings → Developer options"
    echo "4. Enable 'USB debugging'"
    echo "5. Connect phone via USB and accept the prompt"
    exit 1
fi

echo "✓ Device connected"
echo ""

# Check if we have an APK (if not, extract from AAB or build one)
APK_FILE="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_FILE" ]; then
    echo "APK not found. Building APK..."
    export PATH="$PATH:/RAID_Storage/AI Coding/flutter/bin"
    flutter build apk --release
fi

if [ ! -f "$APK_FILE" ]; then
    echo "Error: Could not find or build APK file"
    exit 1
fi

# Find OBB file
OBB_FILE=$(find build/obb -name "*.obb" 2>/dev/null | head -1)
if [ -z "$OBB_FILE" ]; then
    echo "OBB file not found. Creating it..."
    ./create_obb_files.sh
    OBB_FILE=$(find build/obb -name "*.obb" 2>/dev/null | head -1)
fi

if [ -z "$OBB_FILE" ]; then
    echo "Error: Could not find or create OBB file"
    exit 1
fi

echo "Files found:"
echo "  APK: $APK_FILE ($(du -h "$APK_FILE" | cut -f1))"
echo "  OBB: $OBB_FILE ($(du -h "$OBB_FILE" | cut -f1))"
echo ""

# Get OBB filename
OBB_FILENAME=$(basename "$OBB_FILE")

# Install APK
echo "Installing APK..."
adb install -r "$APK_FILE"
echo "✓ APK installed"
echo ""

# Create OBB directory on device
echo "Creating OBB directory on device..."
adb shell mkdir -p "$OBB_DIR"
echo "✓ Directory created: $OBB_DIR"
echo ""

# Copy OBB file to device
echo "Copying OBB file to device..."
echo "This may take a few minutes (1.6 GB)..."
adb push "$OBB_FILE" "$OBB_DIR/$OBB_FILENAME"
echo "✓ OBB file copied"
echo ""

# Set correct permissions
echo "Setting permissions..."
adb shell chmod 644 "$OBB_DIR/$OBB_FILENAME"
# Also set permissions on extracted audio files if they exist
adb shell "chmod -R 644 $OBB_DIR/audio/*/*.mp3 2>/dev/null || true"
echo "✓ Permissions set"
echo ""

echo "=========================================="
echo "Installation complete!"
echo "=========================================="
echo ""
echo "The app should now be installed on your device."
echo "You can launch it and test audio playback."
echo ""
echo "To verify OBB file is in place:"
echo "  adb shell ls -lh $OBB_DIR/"
echo ""
echo "To uninstall (if needed):"
echo "  adb uninstall $PACKAGE_NAME"
echo "  adb shell rm -rf $OBB_DIR"

