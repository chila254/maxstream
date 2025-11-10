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
         var extractionStarted = false

    mainHandler.post {
    try {
    createWebView()
    extractionStarted = true
    Log.d(TAG, "extractStream: WebView created, loading URL: $embedUrl")
    
                 val extractCallback: ExtractionCallback = { extractResult ->
        result = extractResult
        latch.countDown()
    }

        val webViewClient = ExtractionWebViewClient(extractCallback)
    webView?.webViewClient = webViewClient
    webView?.loadUrl(embedUrl)

    } catch (e: Exception) {
    Log.e(TAG, "extractStream: Exception during initialization: ${e.message}", e)
        result = mapOf(
                "success" to false,
                     "error" to (e.message ?: "Unknown error during initialization")
            )
            latch.countDown()
             }
    }

    // Wait for extraction with timeout - add buffer for JavaScript execution
    val effectiveTimeout = timeoutSeconds + 10L
    val completed = latch.await(effectiveTimeout, TimeUnit.SECONDS)

         if (!completed) {
        Log.w(TAG, "extractStream: Extraction timeout after $timeoutSeconds seconds")
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
                    // Mixed content mode: allow both HTTP and HTTPS (0 = NEVER, 1 = COMPATIBILITY, 2 = ALWAYS)
                    mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                    userAgentString =
                        "Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36"
                    // Allow for better network connectivity
                    blockNetworkLoads = false
                    blockNetworkImage = false
                    // Improve TLS/SSL compatibility
                    cacheMode = android.webkit.WebSettings.LOAD_NO_CACHE
                    // Additional settings for better network recovery
                    saveFormData = false
                    allowFileAccess = true
                    // Enable local storage for better compatibility
                    databasePath = activity.getDir("databases", 0).path
                    offscreenPreRaster = true
                    // Enhanced CORS and network settings
                    allowUniversalAccessFromFileURLs = true
                    allowFileAccessFromFileURLs = true
                    loadsImagesAutomatically = true
                    setSupportZoom(false)
                    builtInZoomControls = false
                    displayZoomControls = false
                    // Better SSL/TLS handling
                    useWideViewPort = true
                    loadWithOverviewMode = true
                }
                
                // Enable debug logging for WebView
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
                    WebView.setWebContentsDebuggingEnabled(true)
                }
                
                Log.d(TAG, "WebView created with optimized settings for stream extraction")
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
private val TAG = "ExtractionWebViewClient"
     private var callbackCalled = false
     private val callbackLock = Any()

    override fun onPageFinished(view: WebView?, url: String?) {
    super.onPageFinished(view, url)
    Log.d(TAG, "onPageFinished: Page loading completed for $url")

    view?.let {
    // Progressive extraction attempts with increasing delays
    // First attempt immediately to catch fast-loading streams
    extractStreams(it)
    
    // Second attempt after 1.5 seconds for JavaScript-loaded content
             it.postDelayed({
        extractStreams(it)
    }, 1500)

    // Third attempt after 4 seconds for slower dynamic loading
             it.postDelayed({
        extractStreams(it)
    }, 4000)

    // Final attempt after 8 seconds for very slow pages
        it.postDelayed({
                extractStreams(it)
             }, 8000)
         }
     }

    override fun onReceivedError(
        view: WebView?,
        request: android.webkit.WebResourceRequest?,
        error: android.webkit.WebResourceError?
    ) {
        super.onReceivedError(view, request, error)
        
        val errorCode = error?.errorCode ?: -1
        val errorDesc = error?.description ?: "Unknown error"
        
        Log.e(TAG, "onReceivedError: Code=$errorCode, Desc=$errorDesc, URL=${request?.url}, IsMainFrame=${request?.isForMainFrame}")

        // Always continue if it's not the main frame
        if (request?.isForMainFrame != true) {
            Log.w(TAG, "Sub-resource error (not main frame): $errorDesc - allowing page to continue loading")
            return
        }

        // Enhanced error handling with more retryable conditions
        val isRetryableError = errorCode in arrayOf(
            android.webkit.WebViewClient.ERROR_HOST_LOOKUP,      // -2
            android.webkit.WebViewClient.ERROR_CONNECT,          // -6
            android.webkit.WebViewClient.ERROR_TIMEOUT,          // -7
            android.webkit.WebViewClient.ERROR_UNKNOWN,          // -1
            android.webkit.WebViewClient.ERROR_BAD_URL,         // -12
            android.webkit.WebViewClient.ERROR_FAILED_SSL_HANDSHAKE, // -11
            android.webkit.WebViewClient.ERROR_UNSUPPORTED_SCHEME,   // -10
        ) || errorDesc.contains("ERR_NAME_NOT_RESOLVED") ||
           errorDesc.contains("ERR_CONNECTION_REFUSED") ||
           errorDesc.contains("ERR_NETWORK_CHANGED") ||
           errorDesc.contains("ERR_INTERNET_DISCONNECTED")

        // For ORB, CORS, SSL, and empty response errors, try extraction anyway
        val isOrbOrCorsOrSslError = errorCode == -220 ||
                                    errorCode == 100 ||
                                    errorDesc.contains("ERR_EMPTY_RESPONSE") ||
                                    errorDesc.contains("ORB") ||
                                    errorDesc.contains("CORS") ||
                                    errorDesc.contains("SSL") ||
                                    errorDesc.contains("handshake") ||
                                    errorDesc.contains("ERR_BLOCKED")

        when {
            isRetryableError && pageLoadAttempts < maxLoadAttempts -> {
                pageLoadAttempts++
                Log.d(TAG, "Retryable error detected (code=$errorCode), retrying... (attempt $pageLoadAttempts/$maxLoadAttempts)")
                // Wait before retry to allow network to recover
                view?.postDelayed({
                    view.reload()
                }, 2000)
            }
            isOrbOrCorsOrSslError -> {
                // For ORB/CORS/SSL errors, attempt extraction anyway
                // The page may still have loaded partially or JavaScript may still work
                Log.w(TAG, "ORB/CORS/SSL error ($errorCode), attempting extraction anyway...")
                view?.let {
                    it.postDelayed({
                        extractStreams(it)
                    }, 1500)
                }
            }
            else -> {
            Log.e(TAG, "Non-retryable error, aborting extraction: code=$errorCode, desc=$errorDesc")
            safeCallback(
            mapOf(
            "success" to false,
            "error" to "Failed to load embed page: $errorDesc (code: $errorCode)"
            )
            )
            }
        }
    }

    private fun safeCallback(result: Map<String, Any?>) {
    synchronized(callbackLock) {
             if (!callbackCalled) {
                 callbackCalled = true
                 callback(result)
             }
         }
     }

     private fun extractStreams(webView: WebView) {
         val extractionScript = """
            (function() {
                let streams = [];

                // Method 1: Look for M3U8 URLs in scripts (enhanced)
                const scripts = document.querySelectorAll('script');
                for (const script of scripts) {
                    const content = script.textContent || script.src || '';
                    const matches = content.match(/https?:\/\/[^\s"'<>]*\.m3u8[^\s"'<>]*/g);
                    if (matches) {
                        streams.push(...matches);
                    }
                    // Also check for base64 encoded streams
                    const b64Matches = content.match(/["']([A-Za-z0-9+/=]{20,})["']/g);
                    if (b64Matches) {
                        for (const match of b64Matches) {
                            try {
                                const decoded = atob(match.slice(1, -1));
                                if (decoded.includes('.m3u8')) {
                                    streams.push(decoded);
                                }
                            } catch(e) {}
                        }
                    }
                }

                // Method 2: Look for video/source tags (enhanced)
                const videos = document.querySelectorAll('video, source, audio');
                for (const video of videos) {
                    const src = video.getAttribute('src') || video.getAttribute('data-src');
                    if (src && (src.includes('.m3u8') || src.includes('stream') || src.includes('hls'))) {
                        streams.push(src);
                    }
                }

                // Method 3: Look in iframes (enhanced)
                const iframes = document.querySelectorAll('iframe');
                for (const iframe of iframes) {
                    const src = iframe.getAttribute('src');
                    if (src && !src.startsWith('javascript:') && (src.includes('player') || src.includes('stream') || src.includes('vidsrc') || src.includes('embed'))) {
                        streams.push(src);
                    }
                }

                // Method 4: Look for common player patterns (enhanced)
                const html = document.documentElement.outerHTML;
                const patterns = [
                    /file["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /src["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /stream["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /manifest["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /url["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /hls["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /playlist["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                    /source["\s]*:[\s]*["']([^"']*\.m3u8[^"']*)["']/g,
                ];

                for (const pattern of patterns) {
                    let match;
                    while ((match = pattern.exec(html)) !== null) {
                        if (match[1]) {
                            streams.push(match[1]);
                        }
                    }
                }

                // Method 5: Look for data attributes (enhanced)
                const allElements = document.querySelectorAll('[data-url], [data-src], [data-stream], [data-m3u8], [data-hls], [data-playlist]');
                for (const el of allElements) {
                    const attrs = ['data-url', 'data-src', 'data-stream', 'data-m3u8', 'data-hls', 'data-playlist'];
                    for (const attr of attrs) {
                        const value = el.getAttribute(attr);
                        if (value && (value.includes('.m3u8') || value.includes('stream') || value.includes('hls'))) {
                            streams.push(value);
                        }
                    }
                }

                // Method 6: Check localStorage and sessionStorage for stream URLs
                try {
                    for (let key in localStorage) {
                        const value = localStorage.getItem(key);
                        if (value && (value.includes('.m3u8') || value.includes('stream'))) {
                            const matches = value.match(/https?:\/\/[^\s"'<>]*\.m3u8[^\s"'<>]*/g);
                            if (matches) streams.push(...matches);
                        }
                    }
                    for (let key in sessionStorage) {
                        const value = sessionStorage.getItem(key);
                        if (value && (value.includes('.m3u8') || value.includes('stream'))) {
                            const matches = value.match(/https?:\/\/[^\s"'<>]*\.m3u8[^\s"'<>]*/g);
                            if (matches) streams.push(...matches);
                        }
                    }
                } catch(e) {}

                // Method 7: Check for dynamic content loaded via fetch/XHR
                if (window.performance && window.performance.getEntries) {
                    const entries = window.performance.getEntries();
                    for (const entry of entries) {
                        if (entry.name && entry.name.includes('.m3u8')) {
                            streams.push(entry.name);
                        }
                    }
                }

                // Method 8: Look for JW Player configurations
                try {
                    if (window.jwplayer) {
                        const players = window.jwplayer();
                        if (players && players.getPlaylist) {
                            const playlist = players.getPlaylist();
                            if (playlist && playlist.length > 0) {
                                for (const item of playlist) {
                                    if (item.sources) {
                                        for (const source of item.sources) {
                                            if (source.file && source.file.includes('.m3u8')) {
                                                streams.push(source.file);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch(e) {}

                // Remove duplicates
                streams = [...new Set(streams)];

                // Filter valid URLs and prioritize working ones
                const validStreams = streams.filter(s => {
                    try {
                        new URL(s);
                        return s.includes('http') && (s.includes('.m3u8') || s.includes('stream'));
                    } catch {
                        return false;
                    }
                });

                // Sort by preference (prioritize known good domains)
                validStreams.sort((a, b) => {
                    const priorityDomains = ['vidsrc', 'stream', 'cdn', 'media'];
                    const aScore = priorityDomains.some(d => a.includes(d)) ? 1 : 0;
                    const bScore = priorityDomains.some(d => b.includes(d)) ? 1 : 0;
                    return bScore - aScore;
                });

                // Return result
                if (validStreams.length > 0) {
                    return {
                        success: true,
                        streamUrl: validStreams[0],
                        source: 'native_android_webview',
                        count: validStreams.length,
                        allStreams: validStreams.slice(0, 5) // Include top 5 for debugging
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
            Log.d(TAG, "extractStreams: JavaScript result: $value")
            
            // Handle null or empty response
            if (value == null || value.isEmpty() || value == "null") {
            safeCallback(
            mapOf(
            "success" to false,
            "error" to "No extraction result from JavaScript"
            )
            )
            return@evaluateJavascript
            }
            
            // Parse JSON result from JavaScript
            val jsonResult = org.json.JSONObject(value)

            val success = jsonResult.optBoolean("success", false)
            val streamUrl = jsonResult.optString("streamUrl", null)
            val error = jsonResult.optString("error", null)
            val source = jsonResult.optString("source", "native_android_webview")

            if (success && streamUrl != null && streamUrl.isNotEmpty()) {
            Log.d(TAG, "extractStreams: Successfully extracted stream URL")
            safeCallback(
            mapOf(
            "success" to true,
            "streamUrl" to streamUrl,
            "source" to source,
            "message" to "Stream extracted successfully"
            )
            )
            } else {
            Log.w(TAG, "extractStreams: No stream URL found - $error")
            safeCallback(
            mapOf(
            "success" to false,
            "error" to (error ?: "Failed to extract stream")
            )
            )
            }
            } catch (e: Exception) {
            Log.e(TAG, "extractStreams: Failed to parse extraction result: ${e.message}", e)
            safeCallback(
            mapOf(
            "success" to false,
            "error" to "Failed to parse extraction result: ${e.message}"
            )
            )
            }
        }
    }
}
