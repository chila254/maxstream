package com.maxstream.app

import android.os.Build
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.maxstream.app/webview"
    companion object {
        // Static WebView reference for stream extraction
        var streamWebViewClient: StreamWebViewClient? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Configure WebView for stream extraction
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initWebView" -> {
                        configureWebViewSettings()
                        result.success(true)
                    }
                    "getWebViewClient" -> {
                        if (streamWebViewClient == null) {
                            streamWebViewClient = StreamWebViewClient()
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun configureWebViewSettings() {
        // Enable WebView debugging in debug mode
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(false)
        }

        // Configure data directory for stream extraction
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                WebView.setDataDirectorySuffix("stream_resolver")
            } catch (e: Exception) {
                // Ignore if not supported
            }
        }

        // Set default WebViewClient that bypasses ORB and handles cleartext
        if (streamWebViewClient == null) {
            streamWebViewClient = StreamWebViewClient()
        }
    }
}


