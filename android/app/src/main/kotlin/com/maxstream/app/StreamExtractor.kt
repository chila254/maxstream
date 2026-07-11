package com.maxstream.app

import android.util.Base64
import android.util.Log
import kotlinx.coroutines.*
import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern

/**
 * Native Kotlin stream extractor using OkHttp.
 * Handles Cloudflare challenges better than Flutter's Dio.
 * Extracts streams from PrimeSrc → Voe/Streamtape → direct m3u8/mp4 URLs.
 */
class StreamExtractor {
    private val TAG = "StreamExtractor"
    private val UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    /**
     * Main entry point: resolve a TMDB ID to a playable stream URL.
     * Returns a map with "url", "source", "headers" keys, or null on failure.
     */
    suspend fun resolveStream(
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1
    ): Map<String, String>? = withContext(Dispatchers.IO) {
        try {
            Log.i(TAG, "Resolving stream for TMDB: $tmdbId")

            // Step 1: Get PrimeSrc server list
            val servers = getPrimeSrcServers(tmdbId, isMovie, season, episode)
            if (servers.isEmpty()) {
                Log.w(TAG, "No PrimeSrc servers found")
                return@withContext null
            }
            Log.i(TAG, "Found ${servers.size} servers")

            // Step 2: Try each server
            for ((name, key) in servers) {
                Log.i(TAG, "Trying server: $name (key: $key)")
                try {
                    val link = resolvePrimeSrcLink(key) ?: continue
                    Log.i(TAG, "Got link: $link")

                    val result = extractFromLink(name, link)
                    if (result != null) {
                        Log.i(TAG, "SUCCESS from $name: ${result["url"]}")
                        return@withContext result
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Server $name failed: ${e.message}")
                }
            }

            Log.w(TAG, "All servers failed")
            null
        } catch (e: Exception) {
            Log.e(TAG, "Resolution failed: ${e.message}")
            null
        }
    }

    // ── PrimeSrc ──────────────────────────────────────────────────────────

    private fun getPrimeSrcServers(
        tmdbId: String,
        isMovie: Boolean,
        season: Int,
        episode: Int
    ): List<Pair<String, String>> {
        val url = if (isMovie) {
            "https://primesrc.me/api/v1/s?tmdb=$tmdbId&type=movie"
        } else {
            "https://primesrc.me/api/v1/s?tmdb=$tmdbId&season=$season&episode=$episode&type=tv"
        }

        val request = Request.Builder()
            .url(url)
            .header("User-Agent", UA)
            .header("Referer", "https://primesrc.me/")
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: return emptyList()

        return try {
            val json = JSONObject(body)
            val servers = json.getJSONArray("servers")
            val result = mutableListOf<Pair<String, String>>()
            for (i in 0 until servers.length()) {
                val server = servers.getJSONObject(i)
                val name = server.optString("name", "")
                val key = server.optString("key", "")
                if (key.isNotEmpty()) {
                    result.add(Pair(name, key))
                }
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse servers: ${e.message}")
            emptyList()
        }
    }

    private fun resolvePrimeSrcLink(key: String): String? {
        val request = Request.Builder()
            .url("https://primesrc.me/api/v1/l?key=$key")
            .header("User-Agent", UA)
            .header("Referer", "https://primesrc.me/")
            .header("Accept", "application/json")
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: return null

        return try {
            val json = JSONObject(body)
            json.optString("link", null)
        } catch (e: Exception) {
            // Response might be HTML (Cloudflare challenge)
            Log.e(TAG, "Link response is not JSON: ${body.take(100)}")
            null
        }
    }

    // ── Extractor dispatch ────────────────────────────────────────────────

    private fun extractFromLink(serverName: String, link: String): Map<String, String>? {
        return when {
            serverName.contains("Voe", ignoreCase = true) -> extractVoe(link)
            serverName.contains("Streamtape", ignoreCase = true) ||
            serverName.contains("Streamta", ignoreCase = true) -> extractStreamtape(link)
            else -> extractGeneric(serverName, link)
        }
    }

    // ── Voe Extractor ─────────────────────────────────────────────────────

    private fun extractVoe(link: String): Map<String, String>? {
        Log.i(TAG, "Voe extracting: $link")

        val request = Request.Builder()
            .url(link)
            .header("User-Agent", UA)
            .header("Referer", link)
            .header("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            .build()

        val response = client.newCall(request).execute()
        val html = response.body?.string() ?: return null
        val finalUrl = response.request.url.toString()

        // Find <script type="application/json"> content
        val scriptPattern = Pattern.compile(
            """<script\s+type="application/json">(.*?)</script>""",
            Pattern.DOTALL
        )
        val scriptMatcher = scriptPattern.matcher(html)
        var encodedData = ""
        if (scriptMatcher.find()) {
            encodedData = scriptMatcher.group(1)?.trim() ?: ""
        }

        if (encodedData.isNullOrEmpty()) {
            Log.e(TAG, "Voe: no encoded data found")
            return null
        }

        // Decrypt
        val decrypted = decryptVoe(encodedData)
        if (decrypted.length() == 0) {
            Log.e(TAG, "Voe: decryption failed")
            return null
        }

        val m3u8 = decrypted.optString("source", "")
        if (m3u8.isEmpty()) {
            Log.e(TAG, "Voe: no source in decrypted data")
            return null
        }

        Log.i(TAG, "Voe stream: $m3u8")
        return mapOf(
            "url" to m3u8,
            "source" to "Voe",
            "type" to "direct_m3u8",
            "referer" to finalUrl
        )
    }

    private fun decryptVoe(input: String): JSONObject {
        return try {
            var s = rot13(input)
            // Replace Voe patterns
            s = s.replace("@$", "_")
            s = s.replace("^^", "_")
            s = s.replace("~@", "_")
            s = s.replace("%?", "_")
            s = s.replace("*~", "_")
            s = s.replace("!!", "_")
            s = s.replace("#&", "_")
            s = s.replace("_", "")
            // Base64 decode
            val decoded = Base64.decode(s, Base64.NO_WRAP)
            s = String(decoded, Charsets.UTF_8)
            // Char shift -3
            s = charShift(s, -3)
            // Reverse
            s = s.reversed()
            // Base64 decode again
            val decoded2 = Base64.decode(s, Base64.NO_WRAP)
            s = String(decoded2, Charsets.UTF_8)
            // Parse JSON
            JSONObject(s)
        } catch (e: Exception) {
            Log.e(TAG, "Voe decrypt error: ${e.message}")
            JSONObject()
        }
    }

    private fun rot13(input: String): String {
        return String(CharArray(input.length) { i ->
            val c = input[i]
            when {
                c in 'A'..'Z' -> ((c - 'A' + 13) % 26 + 'A'.code).toChar()
                c in 'a'..'z' -> ((c - 'a' + 13) % 26 + 'a'.code).toChar()
                else -> c
            }
        })
    }

    private fun charShift(input: String, shift: Int): String {
        return String(CharArray(input.length) { i ->
            (input[i].code - shift).toChar()
        })
    }

    // ── Streamtape Extractor ──────────────────────────────────────────────

    private fun extractStreamtape(link: String): Map<String, String>? {
        Log.i(TAG, "Streamtape extracting: $link")

        val request = Request.Builder()
            .url(link)
            .header("User-Agent", UA)
            .build()

        val response = client.newCall(request).execute()
        val html = response.body?.string() ?: return null

        // Parse botlink JS
        val botlinkPattern = Pattern.compile(
            """document\.getElementById\('botlink'\)\.innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)"""
        )
        val matcher = botlinkPattern.matcher(html)
        if (!matcher.find()) {
            Log.e(TAG, "Streamtape: botlink JS not found")
            return null
        }

        val paramString = matcher.group(2) ?: return null
        val substringIndex = (matcher.group(3) ?: "0").toInt()
        val cleanParams = paramString.substring(substringIndex)

        // Extract parameters
        val id = extractParam(cleanParams, "id") ?: return null
        val expires = extractParam(cleanParams, "expires") ?: return null
        val ip = extractParam(cleanParams, "ip") ?: return null
        val token = extractParam(cleanParams, "token") ?: return null

        val videoUrl = "https://streamtape.com/get_video?id=$id&expires=$expires&ip=$ip&token=$token&stream=1"
        Log.i(TAG, "Streamtape video URL: $videoUrl")

        // Follow redirect
        val videoRequest = Request.Builder()
            .url(videoUrl)
            .header("User-Agent", UA)
            .build()

        val videoResponse = client.newCall(videoRequest).execute()
        val finalUrl = videoResponse.request.url.toString()

        // If we got a redirect, the final URL is the stream
        if (finalUrl != videoUrl) {
            Log.i(TAG, "Streamtape stream: $finalUrl")
            return mapOf(
                "url" to finalUrl,
                "source" to "Streamtape",
                "type" to "direct_video",
                "referer" to "https://streamtape.com/"
            )
        }

        // Try to extract from response body
        val body = videoResponse.body?.string() ?: return null
        val streamPattern = Pattern.compile("""(https?://[^"'\s]+\.mp4[^"'\s]*)""")
        val streamMatcher = streamPattern.matcher(body)
        if (streamMatcher.find()) {
            val streamUrl = streamMatcher.group(1) ?: return null
            Log.i(TAG, "Streamtape stream from body: $streamUrl")
            return mapOf(
                "url" to streamUrl,
                "source" to "Streamtape",
                "type" to "direct_video",
                "referer" to "https://streamtape.com/"
            )
        }

        return null
    }

    private fun extractParam(source: String, paramName: String): String? {
        val pattern = Pattern.compile("$paramName=([^&]+)")
        val matcher = pattern.matcher(source)
        return if (matcher.find()) matcher.group(1) else null
    }

    // ── Generic Extractor ─────────────────────────────────────────────────

    private fun extractGeneric(serverName: String, link: String): Map<String, String>? {
        Log.i(TAG, "Generic extracting $serverName: $link")

        val request = Request.Builder()
            .url(link)
            .header("User-Agent", UA)
            .header("Referer", link)
            .build()

        val response = client.newCall(request).execute()
        val html = response.body?.string() ?: return null

        // Search for m3u8 URLs
        val m3u8Pattern = Pattern.compile("""https?://[^\s"'<>]+\.m3u8[^\s"'<>]*""", Pattern.CASE_INSENSITIVE)
        val m3u8Matcher = m3u8Pattern.matcher(html)
        if (m3u8Matcher.find()) {
            val url = m3u8Matcher.group(0) ?: return null
            Log.i(TAG, "Generic found m3u8: $url")
            return mapOf(
                "url" to url,
                "source" to serverName,
                "type" to "direct_m3u8",
                "referer" to link
            )
        }

        // Search for mp4 URLs
        val mp4Pattern = Pattern.compile("""https?://[^\s"'<>]+\.mp4[^\s"'<>]*""", Pattern.CASE_INSENSITIVE)
        val mp4Matcher = mp4Pattern.matcher(html)
        if (mp4Matcher.find()) {
            val url = mp4Matcher.group(0) ?: return null
            Log.i(TAG, "Generic found mp4: $url")
            return mapOf(
                "url" to url,
                "source" to serverName,
                "type" to "direct_video",
                "referer" to link
            )
        }

        return null
    }
}
