# Installing ADB Tools

## Quick Install (Recommended)

Run this command in your terminal:
```bash
sudo apt-get update && sudo apt-get install -y android-tools-adb android-tools-fastboot
```

Or use the provided script:
```bash
sudo ./install_adb.sh
```

## Alternative: Download Platform Tools Directly

If the package manager method doesn't work, download directly from Google:

1. **Download Android Platform Tools**:
   ```bash
   cd ~/Downloads
   wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
   unzip platform-tools-latest-linux.zip
   ```

2. **Add to PATH**:
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   echo 'export PATH="$HOME/Downloads/platform-tools:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **Verify Installation**:
   ```bash
   adb --version
   ```

## Verify Installation

After installing, verify ADB works:
```bash
adb --version
```

You should see output like:
```
Android Debug Bridge version 1.0.41
Version 34.0.5-10900879
```

## Next Steps

Once ADB is installed:
1. Enable USB debugging on your Android device
2. Connect device via USB
3. Run: `adb devices` to verify connection
4. Use: `./install_for_testing.sh` to install APK and OBB

## Troubleshooting

### Permission Denied
If you get "permission denied" errors:
```bash
# Add your user to plugdev group
sudo usermod -aG plugdev $USER
# Log out and back in, or run:
newgrp plugdev
```

### Device Not Detected
- Check USB cable (use a data cable, not charge-only)
- Enable USB debugging on device
- Accept the "Allow USB debugging" prompt
- Try different USB port

### ADB Not Found After Installation
- Check PATH: `echo $PATH`
- Restart terminal
- Or use full path: `/usr/bin/adb`




