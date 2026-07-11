package com.maxstream.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val EXTRACTOR_CHANNEL = "com.maxstream.app/extractor"
    private val extractor = StreamExtractor()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXTRACTOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
