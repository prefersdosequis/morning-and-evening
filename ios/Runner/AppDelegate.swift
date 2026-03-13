import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  // Active ODR requests keyed by ODR tag name. Held strongly so iOS doesn't purge
  // the downloaded resources while we're using them.
  private var activeRequests: [String: NSBundleResourceRequest] = [:]

  // Day-number-to-ODR-tag boundaries. Day 60 = Feb 29 (always in the dataset;
  // the Dart layer skips it at runtime in non-leap years).
  private static let monthBoundaries: [(tag: String, first: Int, last: Int)] = [
    ("audio_jan",   1,  31),
    ("audio_feb",  32,  60),
    ("audio_mar",  61,  91),
    ("audio_apr",  92, 121),
    ("audio_may", 122, 152),
    ("audio_jun", 153, 182),
    ("audio_jul", 183, 213),
    ("audio_aug", 214, 244),
    ("audio_sep", 245, 274),
    ("audio_oct", 275, 305),
    ("audio_nov", 306, 335),
    ("audio_dec", 336, 366),
  ]

  // MARK: - App lifecycle

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Use the engine bridge's own plugin registry to obtain the binary messenger.
    // This avoids relying on window?.rootViewController being set at this point
    // in the implicit-engine lifecycle, which it is not.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AssetDeliveryPlugin") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.spurgeon.morning_evening_app/asset_delivery",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getAudioFilePath":
        guard
          let args = call.arguments as? [String: Any],
          let relativePath = args["path"] as? String
        else {
          result(FlutterError(code: "INVALID_ARGS",
                              message: "Expected {path: String}",
                              details: nil))
          return
        }
        self?.getAudioFilePath(relativePath: relativePath, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Release all ODR access when the app backgrounds so iOS can reclaim storage.
    releaseAllODRAccess()
  }

  // MARK: - ODR

  /// Resolves a relative audio path (e.g. "AudioResources/morning/042.mp3") to a
  /// full filesystem path, downloading the ODR tag for that month if needed.
  private func getAudioFilePath(relativePath: String, result: @escaping FlutterResult) {
    // relativePath: "AudioResources/morning/042.mp3"  (3 components)
    //           or: "morning/042.mp3"                 (2 components — fallback)
    let parts = relativePath.split(separator: "/")
    guard
      parts.count >= 2,
      let filename = parts.last.map(String.init)
    else {
      result(FlutterError(code: "INVALID_ARGS",
                          message: "Cannot parse path: \(relativePath)",
                          details: nil))
      return
    }

    // The type subdirectory is the component just before the filename.
    let typeDir = String(parts[parts.count - 2])   // "morning" or "evening"

    // Parse the zero-padded day number from the filename ("042.mp3" -> 42).
    let nameWithoutExt = (filename as NSString).deletingPathExtension
    let fileExt        = (filename as NSString).pathExtension
    guard let day = Int(nameWithoutExt) else {
      result(FlutterError(code: "INVALID_ARGS",
                          message: "Cannot parse day from filename: \(filename)",
                          details: nil))
      return
    }

    guard let tag = AppDelegate.tagForDay(day) else {
      result(FlutterError(code: "INVALID_ARGS",
                          message: "Day \(day) is out of range (1–366)",
                          details: nil))
      return
    }

    // Reuse an existing request for this tag, or create a new one.
    let request: NSBundleResourceRequest
    if let existing = activeRequests[tag] {
      request = existing
    } else {
      request = NSBundleResourceRequest(tags: [tag])
      activeRequests[tag] = request
    }

    request.beginAccessingResources { [weak self] error in
      DispatchQueue.main.async {
        if let error = error {
          // Remove the failed request so the next call starts fresh.
          self?.activeRequests.removeValue(forKey: tag)
          result(FlutterError(code: "UNAVAILABLE",
                              message: "ODR download failed for \(tag): \(error.localizedDescription)",
                              details: nil))
          return
        }

        // Files are stored flat in the bundle as "morning_042.mp3" / "evening_042.mp3"
        // (prefixed to avoid ODR asset-pack basename collisions).
        let prefixedName = "\(typeDir)_\(nameWithoutExt)"   // e.g. "morning_042"
        let resolvedPath = Bundle.main.path(forResource: prefixedName, ofType: fileExt)

        if let path = resolvedPath {
          result(path)
        } else {
          self?.activeRequests.removeValue(forKey: tag)
          result(FlutterError(code: "UNAVAILABLE",
                              message: "File not found in bundle after ODR access: \(relativePath)",
                              details: nil))
        }
      }
    }
  }

  private func releaseAllODRAccess() {
    for request in activeRequests.values {
      request.endAccessingResources()
    }
    activeRequests.removeAll()
  }

  // MARK: - Day → ODR tag

  private static func tagForDay(_ day: Int) -> String? {
    monthBoundaries.first { day >= $0.first && day <= $0.last }?.tag
  }
}
