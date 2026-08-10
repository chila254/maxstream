package com.maxstream.app

import android.content.ComponentCallbacks2
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val EXTRACTOR_CHANNEL = "com.maxstream.app/extractor"
    private val DOWNLOAD_SERVICE_CHANNEL = "com.maxstream.app/download_service"
    private val RESTART_CHANNEL = "com.maxstream.app/restart"
    private val CRASHLOG_CHANNEL = "com.maxstream.app/crashlog"
    private val MEMORY_CHANNEL = "com.maxstream.app/memory"
    private val extractor by lazy { StreamExtractor(this) }
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var memoryChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        installNativeCrashHandler()
        super.onCreate(savedInstanceState)
    }

    /**
     * Dart caches (decoded posters, subtitle buffers) can be released when the
     * system warns about memory pressure, which is the main thing we control to
     * keep the Low Memory Killer from killing the process while a video is
     * buffered 300s ahead. Forward the warning to Dart; JVM-level trim also gets
     * a GC hint because a chunk of the footprint lives in the video decoder.
     */
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        try {
            memoryChannel?.invokeMethod("onTrimMemory", level)
        } catch (_: Throwable) {
            // Best-effort; never let memory handling crash the app.
        }
        if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW) {
            System.gc()
        }
    }

    /**
     * Captures JVM-level crashes (uncaught exceptions thrown off the Flutter
     * thread, e.g. in ExoPlayer/MediaCodec callbacks or our extractors) into a
     * tombstone file. The crash screen has no chance to show for a hard process
     * death, so the report is persisted here and surfaced by Dart on next boot.
     *
     * Note: a Low Memory Killer SIGKILL or a pure native SIGSEGV never runs a
     * JVM handler, so those cannot be recorded this way - but the most common
     * Android crashes are still Java exceptions and will now produce a report.
     */
    private fun installNativeCrashHandler() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val file = File(filesDir, "maxstream_native_crash.txt")
                file.parentFile?.mkdirs()
                val time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
                val entry = buildString {
                    append(time).append('\n')
                    append("[NativeCrash] ")
                    append(throwable.javaClass.name)
                    append(": ")
                    append(throwable.message ?: "")
                    append('\n')
                    append("Thread: ").append(thread.name).append('\n')
                    append("Stack:\n")
                    for (el in throwable.stackTrace) {
                        append("  at ").append(el.toString()).append('\n')
                    }
                    throwable.cause?.let { cause ->
                        append("Caused by: ").append(cause).append('\n')
                    }
                    append('\n')
                }
                file.appendText(entry)
            } catch (_: Throwable) {
                // Crash handling must never crash.
            }
            // Let the default handler do its job (abort the process, logcat).
            previous?.uncaughtException(thread, throwable)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        memoryChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEMORY_CHANNEL)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRASHLOG_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNativeCrashTombstone" -> {
                        // Return (and clear) the tombstone written by
                        // installNativeCrashHandler so Dart can show the crash
                        // screen once for a previous-process death. Deleting on
                        // read means a restart after "Restart app" won't re-show
                        // the same crash.
                        val file = File(filesDir, "maxstream_native_crash.txt")
                        if (file.exists() && file.isFile) {
                            val text = file.readText()
                            file.delete()
                            result.success(text)
                        } else {
                            result.success("")
                        }
                    }
                    else -> result.notImplemented()
                }
            }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RESTART_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "restartApp" -> {
                        // Relaunch the activity as a cold start so the crash
                        // report restart button fully resets the app state.
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        if (intent != null) {
                            intent.addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK,
                            )
                            startActivity(intent)
                            result.success(null)
                        } else {
                            result.error("NO_LAUNCH_INTENT", "No launch intent found", null)
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
