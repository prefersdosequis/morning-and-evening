#!/bin/bash
# Install ADB (Android Debug Bridge) tools
# Run this script with sudo: sudo ./install_adb.sh

set -e

echo "Installing ADB (Android Debug Bridge) tools..."
echo ""

# Check if already installed
if command -v adb &> /dev/null; then
    echo "ADB is already installed:"
    adb --version
    exit 0
fi

# Update package list
echo "Updating package list..."
apt-get update

# Install ADB and fastboot
echo "Installing android-tools-adb and android-tools-fastboot..."
apt-get install -y android-tools-adb android-tools-fastboot

# Verify installation
if command -v adb &> /dev/null; then
    echo ""
    echo "✓ ADB installed successfully!"
    echo ""
    adb --version
    echo ""
    echo "You can now use ADB commands."
    echo "To test, connect your Android device and run: adb devices"
else
    echo "Error: ADB installation failed"
    exit 1
fi




