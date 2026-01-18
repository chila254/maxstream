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
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            // Allow HTTP redirects (including HTTP to HTTPS)
            connection.instanceFollowRedirects = true

            // Add headers
            request.requestHeaders.forEach { (key, value) ->
                connection.setRequestProperty(key, value)
            }

            // Add User-Agent to match browser requests
            connection.setRequestProperty(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
            )
            
            // Additional headers to avoid blocking
            connection.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            connection.setRequestProperty("Accept-Language", "en-US,en;q=0.9")
            connection.setRequestProperty("Accept-Encoding", "gzip, deflate")

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
            headers.remove("X-Frame-Options")

            val mimeType = connection.contentType ?: "text/html"
            val encoding = connection.contentEncoding ?: "utf-8"

            Log.d(TAG, "Fetched $url with status $responseCode (encoding: $encoding)")

            val inputStream = if (responseCode in 200..299) {
                connection.inputStream
            } else {
                Log.w(TAG, "Non-2xx response for $url: $responseCode")
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
            Log.e(TAG, "Failed to fetch $url: ${e.message}", e)
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
