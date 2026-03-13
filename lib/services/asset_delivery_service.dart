import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resolves file-system paths to devotion MP3s from the platform's native asset delivery system.
///
/// Android: Play Asset Delivery (install-time pack). The native handler in
///   MainActivity.kt returns the root directory path; we append the relative path.
///
/// iOS: On-Demand Resources (ODR). The native handler in AppDelegate.swift
///   downloads the resource tag for the requested file if needed and returns
///   the full resolved path directly.
class AssetDeliveryService {
  static const MethodChannel _channel =
      MethodChannel('com.spurgeon.morning_evening_app/asset_delivery');

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Returns the root path of the [audio_assets] asset pack, or null if unavailable.
  /// Android only. Path is e.g. /data/.../asset_packs/audio_assets/.../assets/
  static Future<String?> getAudioAssetsPath() async {
    try {
      _log('MEAudio: invoking getAudioAssetsPath()');
      final String? path =
          await _channel.invokeMethod<String>('getAudioAssetsPath');
      _log('MEAudio: getAudioAssetsPath() -> $path');
      return path;
    } on PlatformException catch (e) {
      _log(
          'MEAudio: getAudioAssetsPath() PlatformException code=${e.code} message=${e.message}');
      if (e.code == 'UNAVAILABLE') return null;
      rethrow;
    }
  }

  /// Returns the full file-system path to the given audio file, or null if unavailable.
  /// [relativePath] must be in "type/NNN.mp3" form, e.g. "morning/001.mp3" or "evening/042.mp3".
  /// On Android this is appended to the Play Asset Delivery pack root.
  /// On iOS the Swift handler parses the type and day from this path to resolve the ODR resource.
  ///
  /// On iOS the native layer handles ODR tag fetching and returns the resolved path directly.
  /// On Android the native layer returns the pack root and we append the relative path.
  static Future<String?> getAudioFilePath(String relativePath) async {
    if (Platform.isIOS) {
      try {
        _log('MEAudio: iOS invoking getAudioFilePath($relativePath)');
        final String? path = await _channel.invokeMethod<String>(
          'getAudioFilePath',
          {'path': relativePath},
        );
        _log('MEAudio: iOS getAudioFilePath -> $path');
        return path;
      } on PlatformException catch (e) {
        _log(
            'MEAudio: iOS getAudioFilePath() PlatformException code=${e.code} message=${e.message}');
        if (e.code == 'UNAVAILABLE') return null;
        rethrow;
      }
    }

    // Android: build full path from pack root + relative path.
    final root = await getAudioAssetsPath();
    if (root == null) return null;
    return root.endsWith('/') ? '$root$relativePath' : '$root/$relativePath';
  }
}
