package com.maxstream.app

import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.util.Log
import java.net.URL
import java.net.HttpURLConnection

/**
 * Custom WebViewClient that bypasses ORB (Opaque Response Blocking)
 * by intercepting requests and handling responses at the native level
 */
class StreamWebViewClient : WebViewClient() {
    companion object {
        private const val TAG = "StreamWebViewClient"
    }

    override fun shouldInterceptRequest(
        view: WebView?,
        request: WebResourceRequest?
    ): WebResourceResponse? {
        if (request == null) return null

        val url = request.url.toString()
        Log.d(TAG, "Intercepting request: $url")

        // For embed URLs, fetch content natively to bypass ORB
        if (isEmbedUrl(url)) {
            return try {
                fetchResourceNatively(url, request)
            } catch (e: Exception) {
                Log.e(TAG, "Error fetching resource natively: ${e.message}")
                null
            }
        }

        return null
    }

    private fun isEmbedUrl(url: String): Boolean {
        return url.contains("vidsrc") ||
                url.contains("embed") ||
                url.contains("moviesapi")
    }

    private fun fetchResourceNatively(
        url: String,
        request: WebResourceRequest
    ): WebResourceResponse? {
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.requestMethod = request.method
            connection.connectTimeout = 10000
            connection.readTimeout = 10000

            // Add headers
            request.requestHeaders.forEach { (key, value) ->
                connection.setRequestProperty(key, value)
            }

            // Add User-Agent
            connection.setRequestProperty(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36"
            )

            val responseCode = connection.responseCode
            val headers = mutableMapOf<String, String>()
            
            // Collect response headers
            connection.headerFields.forEach { (key, values) ->
                if (key != null && values.isNotEmpty()) {
                    headers[key] = values.joinToString("; ")
                }
            }

            // Remove ORB-sensitive headers that might cause issues
            headers.remove("Content-Security-Policy")
            headers.remove("X-Content-Type-Options")

            val mimeType = connection.contentType ?: "text/html"
            val encoding = connection.contentEncoding ?: "utf-8"

            Log.d(TAG, "Fetched $url with status $responseCode")

            val inputStream = if (responseCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }

            WebResourceResponse(
                mimeType,
                encoding,
                inputStream
            ).apply {
                this.responseHeaders = headers
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch $url: ${e.message}")
            null
        }
    }

    override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
        super.onPageStarted(view, url, favicon)
        Log.d(TAG, "Page started: $url")
    }

    override fun onPageFinished(view: WebView?, url: String?) {
        super.onPageFinished(view, url)
        Log.d(TAG, "Page finished: $url")
    }

    override fun onReceivedError(
        view: WebView?,
        request: WebResourceRequest?,
        error: android.webkit.WebResourceError?
    ) {
        super.onReceivedError(view, request, error)
        Log.e(
            TAG,
            "WebView error for ${request?.url}: ${error?.description}"
        )
    }
}
