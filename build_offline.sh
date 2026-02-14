#!/bin/bash
# Build script for offline APK (with audio assets bundled)
# This creates an Android App Bundle (AAB) that includes all audio files

set -e

echo "Building Offline APK (with audio assets)..."

# Check if audio files exist
if [ ! -d "assets/audio" ] || [ -z "$(ls -A assets/audio/morning 2>/dev/null)" ]; then
    echo "Error: Audio files not found in assets/audio/"
    echo "Please run generate_audio.py first to generate all audio files."
    exit 1
fi

# Set Flutter path
export PATH="$PATH:/RAID_Storage/AI Coding/flutter/bin"

# Build Android App Bundle (AAB) for offline version
echo "Building Android App Bundle..."
flutter build appbundle --release

echo ""
echo "✓ Offline AAB built successfully!"
echo "  Location: build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "Note: Due to the large size (~1.6 GB), you'll need to:"
echo "  1. Upload the AAB to Google Play Console"
echo "  2. Google Play will automatically create expansion files (OBB) for downloads"
echo "  3. Users will download the base app + expansion file automatically"




