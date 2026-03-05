import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to get the path to the Play Asset Delivery "audio_assets" pack.
/// Returns the file system path where the pack is installed (e.g. for playing MP3s).
/// Returns null if the pack is not yet available (e.g. still downloading at install).
class AssetDeliveryService {
  static const MethodChannel _channel =
      MethodChannel('com.spurgeon.morning_evening_app/asset_delivery');

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Returns the root path of the [audio_assets] asset pack, or null if unavailable.
  /// Path is e.g. /data/.../asset_packs/audio_assets/.../assets/
  /// Append your relative path to the MP3 (e.g. "morning/001.mp3") to get the full path.
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

  /// Returns the full path to an audio file in the pack.
  /// [relativePath] e.g. "morning/001.mp3" or "evening/042.mp3"
  static Future<String?> getAudioFilePath(String relativePath) async {
    final root = await getAudioAssetsPath();
    if (root == null) return null;
    return root.endsWith('/') ? '$root$relativePath' : '$root/$relativePath';
  }
}
