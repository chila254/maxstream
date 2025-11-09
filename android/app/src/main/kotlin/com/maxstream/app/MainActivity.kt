package com.maxstream.app

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.maxstream/stream_extractor"
    private val TAG = "StreamExtractor"
    private var webView: WebView? = null
    private var streamExtractor: StreamExtractor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        streamExtractor = StreamExtractor(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractStream" -> {
                        val url = call.argument<String>("url")
                        val timeout = call.argument<Int>("timeout") ?: 30

                        if (url == null) {
                            Log.e(TAG, "extractStream: URL is null")
                            result.error("INVALID_URL", "URL cannot be null", null)
                            return@setMethodCallHandler
                        }

                        Log.d(TAG, "extractStream: Starting extraction for $url with timeout $timeout seconds")

                        // Execute on a background thread
                        Thread {
                            try {
                                val extractResult = streamExtractor?.extractStream(url, timeout)
                                Log.d(TAG, "extractStream: Result - $extractResult")
                                result.success(extractResult)
                            } catch (e: Exception) {
                                Log.e(TAG, "extractStream: Error - ${e.message}", e)
                                result.error(
                                    "EXTRACTION_ERROR",
                                    e.message ?: "Unknown error",
                                    null
                                )
                            }
                        }.start()
                    }

                    "isAvailable" -> {
                        result.success(true)
                    }

                    "clearCache" -> {
                        try {
                            streamExtractor?.clearCache()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CACHE_ERROR", e.message, null)
                        }
                    }

                    "dispose" -> {
                        try {
                            streamExtractor?.dispose()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("DISPOSE_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        streamExtractor?.dispose()
        super.onDestroy()
    }
}

/**
 * Stream extraction using WebView
 * Extracts M3U8 URLs from embed pages by rendering and parsing JavaScript
 */
class StreamExtractor(private val activity: MainActivity) {
    private var webView: WebView? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val TAG = "StreamExtractor"

    /**
     * Extract stream URL from an embed page
     *
     * @param embedUrl The URL of the embed page
     * @param timeoutSeconds Timeout in seconds
     * @return Map with extraction results
     */
    fun extractStream(embedUrl: String, timeoutSeconds: Int): Map<String, Any?> {
        val latch = CountDownLatch(1)
        var result: Map<String, Any?> = mapOf(
            "success" to false,
            "error" to "Extraction timeout"
        )

        mainHandler.post {
            try {
                createWebView()
                val extractCallback: ExtractionCallback = { extractResult ->
                    result = extractResult
                    latch.countDown()
                }

                val webViewClient = ExtractionWebViewClient(extractCallback)
                webView?.webViewClient = webViewClient
                webView?.loadUrl(embedUrl)

            } catch (e: Exception) {
                result = mapOf(
                    "success" to false,
                    "error" to (e.message ?: "Unknown error")
                )
                latch.countDown()
            }
        }

        // Wait for extraction with timeout
        val completed = latch.await(timeoutSeconds.toLong(), TimeUnit.SECONDS)

        if (!completed) {
            result = mapOf(
                "success" to false,
                "error" to "Extraction timeout after $timeoutSeconds seconds"
            )
        }

        return result
    }

    private fun createWebView() {
        if (webView == null) {
            webView = WebView(activity).apply {
                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    databaseEnabled = true
                    mediaPlaybackRequiresUserGesture = false
                    mixedContentMode = 0
                    userAgentString =
                        "Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
                }
            }
        }
    }

    fun clearCache() {
        mainHandler.post {
            webView?.clearCache(true)
        }
    }

    fun dispose() {
        mainHandler.post {
            webView?.apply {
                stopLoading()
                clearHistory()
                clearCache(true)
                destroy()
            }
            webView = null
        }
    }
}

/**
 * Callback for extraction results
 */
typealias ExtractionCallback = (Map<String, Any?>) -> Unit

/**
 * WebViewClient for extraction
 */
class ExtractionWebViewClient(private val callback: ExtractionCallback) : WebViewClient() {
    private var pageLoadAttempts = 0
    private val maxLoadAttempts = 3

    override fun onPageFinished(view: WebView?, url: String?) {
        super.onPageFinished(view, url)

        view?.let {
            // Wait a bit for JavaScript to execute
            it.postDelayed({
                extractStreams(it)
            }, 2000)
        }
    }

    override fun onReceivedError(
        view: WebView?,
        request: android.webkit.WebResourceRequest?,
        error: android.webkit.WebResourceError?
    ) {
        super.onReceivedError(view, request, error)

        if (pageLoadAttempts < maxLoadAttempts && request?.isForMainFrame == true) {
            pageLoadAttempts++
            view?.reload()
        } else {
            callback(
                mapOf(
                    "success" to false,
                    "error" to "Failed to load embed page: ${error?.description}"
                )
            )
        }
    }

    private fun extractStreams(webView: WebView) {
        val extractionScript = """
            (function() {
                let streams = [];
                
                // Method 1: Look for M3U8 URLs in scripts
                const scripts = document.querySelectorAll('script');
                for (const script of scripts) {
                    const content = script.textContent || '';
                    const matches = content.match(/https?:\/\/[^\s"'<>]*\.m3u8[^\s"'<>]*/g);
                    if (matches) {
                        streams.push(...matches);
                    }
                }
                
                // Method 2: Look for video/source tags
                const videos = document.querySelectorAll('video, source');
                for (const video of videos) {
                    const src = video.getAttribute('src');
                    if (src && (src.includes('.m3u8') || src.includes('stream'))) {
                        streams.push(src);
                    }
                }
                
                // Method 3: Look in iframes
                const iframes = document.querySelectorAll('iframe');
                for (const iframe of iframes) {
                    const src = iframe.getAttribute('src');
                    if (src && !src.startsWith('javascript:') && (src.includes('player') || src.includes('stream'))) {
                        streams.push(src);
                    }
                    
                    // Also check iframe src directly as source
                    try {
                        const iframeContent = iframe.contentDocument?.documentElement?.outerHTML;
                        if (iframeContent) {
                            const iframeMatches = iframeContent.match(/https?:\/\/[^\s"'<>]*\.m3u8[^\s"'<>]*/g);
                            if (iframeMatches) streams.push(...iframeMatches);
                        }
                    } catch (e) {
                        // Cross-origin iframe, skip
                    }
                }
                
                // Method 4: Look for common player patterns
                const html = document.documentElement.outerHTML;
                const patterns = [
                    /file["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /src["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /stream["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /manifest["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                ];
                
                for (const pattern of patterns) {
                    let match;
                    while ((match = pattern.exec(html)) !== null) {
                        if (match[1]) {
                            streams.push(match[1]);
                        }
                    }
                }
                
                // Remove duplicates
                streams = [...new Set(streams)];
                
                // Filter valid URLs
                const validStreams = streams.filter(s => {
                    try {
                        new URL(s);
                        return true;
                    } catch {
                        return false;
                    }
                });
                
                // Return result
                if (validStreams.length > 0) {
                    return {
                        success: true,
                        streamUrl: validStreams[0],
                        source: 'native_android_webview',
                        count: validStreams.length
                    };
                } else {
                    return {
                        success: false,
                        error: 'No M3U8 streams found in page'
                    };
                }
            })();
        """.trimIndent()

        webView.evaluateJavascript(extractionScript) { value ->
            try {
                // Parse JSON result from JavaScript
                val jsonResult = org.json.JSONObject(value)

                val success = jsonResult.optBoolean("success", false)
                val streamUrl = jsonResult.optString("streamUrl", null)
                val error = jsonResult.optString("error", null)
                val source = jsonResult.optString("source", "native_android_webview")

                if (success && streamUrl != null) {
                    callback(
                        mapOf(
                            "success" to true,
                            "streamUrl" to streamUrl,
                            "source" to source,
                            "message" to "Stream extracted successfully"
                        )
                    )
                } else {
                    callback(
                        mapOf(
                            "success" to false,
                            "error" to (error ?: "Failed to extract stream")
                        )
                    )
                }
            } catch (e: Exception) {
                callback(
                    mapOf(
                        "success" to false,
                        "error" to "Failed to parse extraction result: ${e.message}"
                    )
                )
            }
        }
    }
}
