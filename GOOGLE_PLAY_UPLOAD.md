# Google Play Console Upload Instructions

## Overview
Your app uses Google Play expansion files (OBB) to handle the large audio assets (~1.6 GB). Google Play will automatically create and manage these expansion files when you upload your AAB.

## Step 1: Prepare Your AAB

The AAB file is located at:
```
build/app/outputs/bundle/release/app-release.aab
```

**Current Size**: ~24 MB (base app)
**Audio Assets**: 1.6 GB (will be packaged as expansion file by Google Play)

## Step 2: Upload to Google Play Console

1. **Log into Google Play Console**
   - Go to https://play.google.com/console
   - Select your app (or create a new app)

2. **Navigate to Release Management**
   - Go to **Production** → **Create new release**
   - Or **Internal testing** / **Closed testing** / **Open testing** (for testing first)

3. **Upload the AAB**
   - Click **Upload** or **Browse files**
   - Select: `build/app/outputs/bundle/release/app-release.aab`
   - Wait for upload to complete

4. **Google Play Processing**
   - Google Play will automatically:
     - Analyze your AAB
     - Extract large assets (>100 MB) into expansion files (OBB)
     - Create the base APK (~24 MB)
     - Create expansion file (~1.6 GB)

## Step 3: Review Expansion Files

After upload, Google Play will show:
- **Base APK**: ~24 MB (app code + small assets)
- **Expansion File (OBB)**: ~1.6 GB (audio files)

You can verify this in:
- **Release** → **App bundles and APKs** → Select your release
- Look for "Expansion files" section

## Step 4: Test the Release

### Internal Testing (Recommended First)
1. Create an internal testing track
2. Add testers (your email or test accounts)
3. Download and test the app
4. Verify audio playback works offline

### Production Release
Once testing is successful:
1. Promote to Production
2. Fill in release notes
3. Submit for review

## Important Notes

### Expansion File Handling
- **Automatic**: Google Play automatically creates and serves expansion files
- **User Experience**: Users download base app first (~24 MB), then expansion file (~1.6 GB) automatically
- **Storage**: Expansion files are stored on device and managed by Google Play

### App Size Display
- **Base App Size**: ~24 MB (shown in Play Store)
- **Total Download**: ~1.6 GB (includes expansion file)
- Users see: "App size: 24 MB" + "Additional download: 1.6 GB"

### Requirements
- **Minimum Android Version**: Check your `minSdkVersion` in `android/app/build.gradle`
- **Target Android Version**: Check your `targetSdkVersion`
- **Permissions**: Ensure INTERNET permission is declared (for initial expansion file download)

## Troubleshooting

### If Expansion Files Don't Appear
1. Check AAB size - if it's very small, assets might not be included
2. Verify `pubspec.yaml` includes `assets/audio/`
3. Rebuild: `flutter build appbundle --release`
4. Check Google Play Console for any errors

### If Audio Doesn't Play Offline
1. Verify expansion file downloaded successfully
2. Check app logs for asset loading errors
3. Test with: `adb logcat | grep -i audio`

### Testing Expansion Files Locally
To test expansion files before uploading:
1. Use `bundletool` to generate APKs from AAB
2. Create OBB files manually (advanced)
3. Or test directly on Google Play internal testing track

## Next Steps

1. ✅ AAB is built and ready
2. ⏳ Upload to Google Play Console
3. ⏳ Test on internal testing track
4. ⏳ Verify audio playback works offline
5. ⏳ Release to production

## Additional Resources

- [Google Play App Bundle Guide](https://developer.android.com/guide/playcore/asset-delivery)
- [Expansion Files Documentation](https://developer.android.com/google/play/expansion-files)
- [Flutter App Bundle Guide](https://docs.flutter.dev/deployment/android#building-an-app-bundle)




