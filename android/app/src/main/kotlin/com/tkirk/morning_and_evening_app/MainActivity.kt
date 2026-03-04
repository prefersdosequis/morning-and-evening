package com.tkirk.morning_and_evening_app

import android.os.Bundle
import android.util.Log
import com.google.android.play.core.assetpacks.AssetPackLocation
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipFile

class MainActivity : FlutterActivity() {

    private val channelName = "com.spurgeon.morning_evening_app/asset_delivery"
    private val assetPackName = "audio_assets"
    private val logTag = "MEAudio"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val mgr = AssetPackManagerFactory.getInstance(this)
            val loc = mgr.getPackLocation(assetPackName) ?: mgr.getPackLocations()?.get(assetPackName)
            if (loc == null) {
                Log.w(logTag, "onCreate: Play Core pack location is null; trying split extraction fallback")
                val extracted = extractAssetPackFromSplits()
                if (extracted != null) {
                    val assetsDir = File(extracted)
                    val morning = File(assetsDir, "morning")
                    val evening = File(assetsDir, "evening")
                    Log.d(
                        logTag,
                        "onCreate: extracted=$extracted morningDir=${morning.isDirectory} eveningDir=${evening.isDirectory}"
                    )
                } else {
                    Log.w(logTag, "onCreate: split extraction fallback also failed")
                }
                return
            }
            Log.d(logTag, "onCreate: assetsPath=${loc.assetsPath()} path=${loc.path()}")

            val rawAssetsPath = loc.assetsPath()
            val rawPackPath = loc.path()
            if (rawAssetsPath.isNullOrEmpty() && rawPackPath.isNullOrEmpty()) {
                Log.w(logTag, "onCreate: pack location returned but no usable paths; trying split extraction fallback")
                val extracted = extractAssetPackFromSplits()
                if (extracted != null) {
                    val assetsDir = File(extracted)
                    val morning = File(assetsDir, "morning")
                    val evening = File(assetsDir, "evening")
                    Log.d(
                        logTag,
                        "onCreate: extracted=$extracted morningDir=${morning.isDirectory} eveningDir=${evening.isDirectory}"
                    )
                } else {
                    Log.w(logTag, "onCreate: split extraction fallback failed")
                }
                return
            }

            val assetsDir = when {
                !loc.assetsPath().isNullOrEmpty() -> File(loc.assetsPath()!!)
                !loc.path().isNullOrEmpty() && File(loc.path()!!, "assets").isDirectory -> File(loc.path()!!, "assets")
                !loc.path().isNullOrEmpty() -> File(loc.path()!!)
                else -> null
            }

            if (assetsDir != null) {
                val morning = File(assetsDir, "morning")
                val evening = File(assetsDir, "evening")
                Log.d(
                    logTag,
                    "onCreate: assetsDir=${assetsDir.absolutePath} morningDir=${morning.isDirectory} eveningDir=${evening.isDirectory}"
                )
            }
        } catch (e: Exception) {
            Log.e(logTag, "onCreate: error checking pack location", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAudioAssetsPath" -> {
                    Log.d(logTag, "getAudioAssetsPath() called")
                    getAudioAssetsPath(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Returns the root path for the audio_assets pack (with trailing slash).
     * 1) Uses Play Core getPackLocation/getPackLocations when available (Play Store installs).
     * 2) Fallback: when installed via bundletool, getPackLocation() often returns null;
     *    try the app data path where install-time pack may be extracted.
     */
    private fun getAudioAssetsPath(result: MethodChannel.Result) {
        val assetPackManager = AssetPackManagerFactory.getInstance(this)
        var location: AssetPackLocation? = assetPackManager.getPackLocation(assetPackName)
        if (location == null) {
            location = assetPackManager.getPackLocations()?.get(assetPackName)
        }
        if (location != null) {
            val assetsPath = location.assetsPath()
            val packPath = location.path()
            Log.d(logTag, "Play Core pack location found. assetsPath=$assetsPath path=$packPath")

            // We must return the directory that actually contains morning/ and evening/:
            // i.e. the extracted "assets/" folder.
            if (!assetsPath.isNullOrEmpty()) {
                result.success(ensureTrailingSlash(assetsPath))
                return
            }

            if (!packPath.isNullOrEmpty()) {
                val packAssetsDir = File(packPath, "assets")
                if (packAssetsDir.isDirectory) {
                    result.success(ensureTrailingSlash(packAssetsDir.absolutePath))
                    return
                }
                // Some devices/installs might already point to a directory containing the content.
                val maybeMorning = File(packPath, "morning")
                val maybeEvening = File(packPath, "evening")
                if (maybeMorning.isDirectory || maybeEvening.isDirectory) {
                    result.success(ensureTrailingSlash(packPath))
                    return
                }
            }

            // Some installs return a non-null location but without usable paths.
            Log.w(logTag, "Pack location present but unusable; continuing to fallback extraction.")
        }

        // Fallback for bundletool / sideload: getPackLocation() often returns null;
        // try app data paths where install-time pack may be extracted.
        val fallbackPaths = listOf(
            File(filesDir, "asset_packs/$assetPackName/assets"),
            File(filesDir.parent, "asset_packs/$assetPackName/assets"),
            File(applicationContext.dataDir, "asset_packs/$assetPackName/assets"),
            File(filesDir, "asset_packs/$assetPackName"),
            File(filesDir.parent, "asset_packs/$assetPackName"),
            File(applicationContext.dataDir, "asset_packs/$assetPackName")
        )
        for (dir in fallbackPaths) {
            if (dir.isDirectory) {
                val morning = File(dir, "morning")
                val evening = File(dir, "evening")
                if (morning.isDirectory || evening.isDirectory) {
                    Log.d(logTag, "Found extracted pack via fallback path: ${dir.absolutePath}")
                    result.success(ensureTrailingSlash(dir.absolutePath))
                    return
                }
            }
        }

        // Fallback: asset pack may be installed as a split APK (e.g. bundletool).
        // Extract the pack's assets/ from the split APK to cache and return that path.
        val extracted = extractAssetPackFromSplits()
        if (extracted != null) {
            Log.d(logTag, "Extracted pack assets from split APK to: $extracted")
            result.success(ensureTrailingSlash(extracted))
            return
        }

        Log.w(logTag, "Audio asset pack unavailable (no location, no fallback dir, no extractable split).")
        result.error("UNAVAILABLE", "Audio asset pack not yet available", null)
    }

    /**
     * If the app was installed with split APKs (e.g. via bundletool), the asset pack
     * may be one of the splits. Extract its assets/ to cache and return the path.
     */
    private fun extractAssetPackFromSplits(): String? {
        val appInfo = applicationContext.applicationInfo
        val splitDirs = appInfo.splitSourceDirs ?: return null
        val splitNames = appInfo.splitNames ?: return null
        val packApk = splitDirs.zip(splitNames).firstOrNull { (_, name) ->
            name.contains("audio", ignoreCase = true) || name.contains("asset", ignoreCase = true)
        }?.first ?: return null

        val cacheDir = File(filesDir, "cache/audio_assets")
        val assetsDir = File(cacheDir, "assets")
        val morning = File(assetsDir, "morning")
        if (morning.isDirectory) return assetsDir.absolutePath

        try {
            Log.d(logTag, "Attempting to extract assets/ from split APK: $packApk")
            ZipFile(packApk).use { zip ->
                val entries = zip.entries()
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    if (entry.isDirectory) continue
                    val name = entry.name
                    if (!name.startsWith("assets/")) continue
                    val outFile = File(cacheDir, name)
                    outFile.parentFile?.mkdirs()
                    zip.getInputStream(entry).use { input ->
                        FileOutputStream(outFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                }
            }
            return if (morning.exists()) assetsDir.absolutePath else null
        } catch (e: Exception) {
            Log.e(logTag, "Failed extracting pack from split APK", e)
            return null
        }
    }

    private fun ensureTrailingSlash(path: String): String {
        return if (path.endsWith("/")) path else "$path/"
    }
}

