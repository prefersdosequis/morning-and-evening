#!/bin/bash
# Wait for all audio files to be generated, then build the offline APK

cd "/RAID_Storage/AI Coding/Morning-and-Evening"

TOTAL=732
CHECK_INTERVAL=60  # Check every 60 seconds

echo "Waiting for all audio files to be generated..."
echo "Target: $TOTAL files"
echo "Checking every $CHECK_INTERVAL seconds..."
echo ""

while true; do
    GENERATED=$(find assets/audio -name "*.mp3" 2>/dev/null | wc -l)
    PERCENTAGE=$((GENERATED * 100 / TOTAL))
    
    echo "$(date '+%H:%M:%S') - Progress: $GENERATED / $TOTAL files ($PERCENTAGE%)"
    
    if [ $GENERATED -ge $TOTAL ]; then
        echo ""
        echo "✓ All audio files generated!"
        echo "Starting offline APK build..."
        echo ""
        
        # Build the offline APK
        export PATH="$PATH:/RAID_Storage/AI Coding/flutter/bin"
        flutter build apk --release
        
        echo ""
        echo "✓ Offline APK built successfully!"
        echo "Location: build/app/outputs/flutter-apk/app-release.apk"
        exit 0
    fi
    
    sleep $CHECK_INTERVAL
done




