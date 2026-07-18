package com.maxstream.app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val EXTRACTOR_CHANNEL = "com.maxstream.app/extractor"
    private val DOWNLOAD_SERVICE_CHANNEL = "com.maxstream.app/download_service"
    private val extractor by lazy { StreamExtractor(this) }
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXTRACTOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBrightness" -> {
                        val windowBrightness = window.attributes.screenBrightness
                        val brightness = if (windowBrightness >= 0f) {
                            windowBrightness
                        } else {
                            Settings.System.getInt(
                                contentResolver,
                                Settings.System.SCREEN_BRIGHTNESS,
                                128,
                            ) / 255f
                        }
                        result.success(brightness.toDouble())
                    }
                    "setBrightness" -> {
                        val brightness = (call.argument<Double>("value") ?: 0.5)
                            .coerceIn(0.01, 1.0)
                            .toFloat()
                        window.attributes = window.attributes.apply {
                            screenBrightness = brightness
                        }
                        result.success(null)
                    }
                    "resolveStream" -> {
                        val tmdbId = call.argument<String>("tmdbId") ?: ""
                        val isMovie = call.argument<Boolean>("isMovie") ?: true
                        val season = call.argument<Int>("season") ?: 1
                        val episode = call.argument<Int>("episode") ?: 1
                        val title = call.argument<String>("title") ?: ""

                        scope.launch {
                            try {
                                val stream = withContext(Dispatchers.IO) {
                                    extractor.resolveStream(tmdbId, isMovie, season, episode, title)
                                }
                                if (stream != null) {
                                    result.success(stream)
                                } else {
                                    result.error("NO_STREAM", "No stream found", null)
                                }
                            } catch (e: Exception) {
                                result.error("EXTRACT_ERROR", e.message, null)
                            }
                        }
                    }
                    "resolveStreams" -> {
                        val tmdbId = call.argument<String>("tmdbId") ?: ""
                        val isMovie = call.argument<Boolean>("isMovie") ?: true
                        val season = call.argument<Int>("season") ?: 1
                        val episode = call.argument<Int>("episode") ?: 1
                        val title = call.argument<String>("title") ?: ""

                        scope.launch {
                            try {
                                val streams = withContext(Dispatchers.IO) {
                                    extractor.resolveStreams(tmdbId, isMovie, season, episode, title)
                                }
                                result.success(streams)
                            } catch (e: Exception) {
                                result.error("EXTRACT_ERROR", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        val downloadCount = call.argument<Int>("downloadCount") ?: 1
                        val title = call.argument<String>("title") ?: "Downloading media"
                        val intent = Intent(this, DownloadForegroundService::class.java).apply {
                            action = DownloadForegroundService.ACTION_START
                            putExtra("download_count", downloadCount)
                            putExtra("title", title)
                        }
                        startForegroundService(intent)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        val intent = Intent(this, DownloadForegroundService::class.java).apply {
                            action = DownloadForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
