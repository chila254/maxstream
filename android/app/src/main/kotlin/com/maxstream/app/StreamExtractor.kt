package com.maxstream.app

import android.util.Base64
import android.util.Log
import kotlinx.coroutines.*
import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Native Kotlin stream extractor using OkHttp.
 * Calls providers directly (VixSrc, Vidrock) + PrimeSrc as fallback.
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

    suspend fun resolveStream(
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1
    ): Map<String, String>? = withContext(Dispatchers.IO) {
        // Try each provider in order
        val providers: List<suspend () -> Map<String, String>?> = listOf(
            { extractVixSrc(tmdbId, isMovie, season, episode) },
            { extractVidrock(tmdbId, isMovie, season, episode) },
            { extractPrimeSrc(tmdbId, isMovie, season, episode) },
        )

        for ((i, provider) in providers.withIndex()) {
            try {
                Log.i(TAG, "Trying provider ${i + 1}/${providers.size}")
                val result = provider()
                if (result != null) {
                    Log.i(TAG, "SUCCESS: ${result["source"]}: ${result["url"]}")
                    return@withContext result
                }
            } catch (e: Exception) {
                Log.e(TAG, "Provider ${i + 1} failed: ${e.message}")
            }
        }

        Log.w(TAG, "All providers failed")
        null
    }

    // ── VixSrc Extractor (direct API, no Cloudflare) ──────────────────────

    private fun extractVixSrc(tmdbId: String, isMovie: Boolean, season: Int, episode: Int): Map<String, String>? {
        Log.i(TAG, "VixSrc: resolving TMDB $tmdbId")

        val apiPath = if (isMovie) {
            "api/movie/$tmdbId?lang=en"
        } else {
            "api/tv/$tmdbId/$season/$episode?lang=en"
        }

        // Step 1: Call VixSrc API
        val apiRequest = Request.Builder()
            .url("https://vixsrc.to/$apiPath")
            .header("User-Agent", UA)
            .header("Referer", "https://vixsrc.to")
            .header("X-Requested-With", "XMLHttpRequest")
            .header("Accept", "application/json, text/plain, */*")
            .build()

        val apiResponse = client.newCall(apiRequest).execute()
        val apiBody = apiResponse.body?.string() ?: return null
        Log.i(TAG, "VixSrc API response: ${apiBody.take(200)}")

        val apiJson = try { JSONObject(apiBody) } catch (e: Exception) { return null }
        val embedPath = apiJson.optString("src", "").trimStart('/')
        if (embedPath.isEmpty()) {
            Log.e(TAG, "VixSrc: no src in API response")
            return null
        }
        Log.i(TAG, "VixSrc embed path: $embedPath")

        // Step 2: Fetch embed page
        val embedRequest = Request.Builder()
            .url("https://vixsrc.to/$embedPath")
            .header("User-Agent", UA)
            .header("Referer", "https://vixsrc.to")
            .header("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            .build()

        val embedResponse = client.newCall(embedRequest).execute()
        val html = embedResponse.body?.string() ?: return null

        // Step 3: Parse script for video ID, token, expires
        val videoId = extractBetween(html, "id: '", "'") ?: run {
            Log.e(TAG, "VixSrc: no video ID found"); return null
        }
        val token = extractBetween(html, "'token': '", "'") ?: run {
            Log.e(TAG, "VixSrc: no token found"); return null
        }
        val expires = extractBetween(html, "'expires': '", "'") ?: run {
            Log.e(TAG, "VixSrc: no expires found"); return null
        }
        val hasB = html.contains("b=1")
        val canFHD = html.contains("window.canPlayFHD = true")

        Log.i(TAG, "VixSrc: videoId=$videoId, token=$token, expires=$expires")

        // Step 4: Build m3u8 URL
        val params = mutableListOf("token=$token", "expires=$expires", "lang=en")
        if (hasB) params.add("b=1")
        if (canFHD) params.add("h=1")
        val qs = params.joinToString("&")
        val m3u8Url = "https://vixsrc.to/playlist/$videoId?$qs"

        Log.i(TAG, "VixSrc stream: $m3u8Url")
        return mapOf(
            "url" to m3u8Url,
            "source" to "VixSrc",
            "type" to "direct_m3u8",
            "referer" to "https://vixsrc.to/$embedPath"
        )
    }

    // ── Vidrock Extractor (AES-CBC encrypted API) ────────────────────────

    private val VIDROCK_PASSPHRASE = "x7k9mPqT2rWvY8zA5bC3nF6hJ2lK4mN9"

    private fun extractVidrock(tmdbId: String, isMovie: Boolean, season: Int, episode: Int): Map<String, String>? {
        Log.i(TAG, "Vidrock: resolving TMDB $tmdbId")

        val dataToEncrypt = if (isMovie) tmdbId else "${tmdbId}_${season}_${episode}"
        val encoded = aesEncrypt(dataToEncrypt, VIDROCK_PASSPHRASE)

        val apiPath = if (isMovie) "api/movie/$encoded" else "api/tv/$encoded"

        val request = Request.Builder()
            .url("https://vidrock.net/$apiPath")
            .header("User-Agent", UA)
            .header("Referer", "https://vidrock.net/")
            .header("Origin", "https://vidrock.net")
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: return null
        Log.i(TAG, "Vidrock response: ${body.take(200)}")

        val json = try { JSONObject(body) } catch (e: Exception) { return null }

        // Find first server with a valid m3u8 URL
        val keys = json.keys()
        while (keys.hasNext()) {
            val serverName = keys.next()
            val serverData = json.optJSONObject(serverName) ?: continue
            val url = serverData.optString("url", "")
            if (url.isNotEmpty() && url.contains(".m3u8")) {
                Log.i(TAG, "Vidrock stream from $serverName: $url")
                return mapOf(
                    "url" to url,
                    "source" to "Vidrock",
                    "type" to "direct_m3u8",
                    "referer" to "https://vidrock.net/",
                    "origin" to "https://vidrock.net"
                )
            }
        }

        Log.e(TAG, "Vidrock: no valid stream found")
        return null
    }

    private fun aesEncrypt(data: String, passphrase: String): String {
        val key = passphrase.toByteArray(Charsets.UTF_8)
        val iv = key.copyOfRange(0, 16)
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
        val encrypted = cipher.doFinal(data.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(encrypted, Base64.URL_SAFE or Base64.NO_WRAP)
    }

    // ── PrimeSrc (fallback, may fail due to Cloudflare) ──────────────────

    private fun extractPrimeSrc(tmdbId: String, isMovie: Boolean, season: Int, episode: Int): Map<String, String>? {
        Log.i(TAG, "PrimeSrc: resolving TMDB $tmdbId")

        // Step 1: Get server list
        val serversUrl = if (isMovie) {
            "https://primesrc.me/api/v1/s?tmdb=$tmdbId&type=movie"
        } else {
            "https://primesrc.me/api/v1/s?tmdb=$tmdbId&season=$season&episode=$episode&type=tv"
        }

        val serversRequest = Request.Builder()
            .url(serversUrl)
            .header("User-Agent", UA)
            .header("Referer", "https://primesrc.me/")
            .build()

        val serversResponse = client.newCall(serversRequest).execute()
        val serversBody = serversResponse.body?.string() ?: return null

        val serversJson = try { JSONObject(serversBody) } catch (e: Exception) { return null }
        val servers = serversJson.optJSONArray("servers") ?: return null

        // Step 2: Try each server
        for (i in 0 until servers.length()) {
            val server = servers.optJSONObject(i) ?: continue
            val name = server.optString("name", "")
            val key = server.optString("key", "")
            if (key.isEmpty()) continue

            Log.i(TAG, "PrimeSrc: trying $name (key: $key)")
            try {
                val linkRequest = Request.Builder()
                    .url("https://primesrc.me/api/v1/l?key=$key")
                    .header("User-Agent", UA)
                    .header("Referer", "https://primesrc.me/")
                    .header("Accept", "application/json")
                    .build()

                val linkResponse = client.newCall(linkRequest).execute()
                val linkBody = linkResponse.body?.string() ?: continue

                val linkJson = try { JSONObject(linkBody) } catch (e: Exception) {
                    Log.e(TAG, "PrimeSrc: link response is not JSON")
                    continue
                }
                val link = linkJson.optString("link", "")
                if (link.isEmpty()) continue

                Log.i(TAG, "PrimeSrc: got link: $link")
                return extractFromProviderUrl(name, link)
            } catch (e: Exception) {
                Log.e(TAG, "PrimeSrc: server $name failed: ${e.message}")
            }
        }

        return null
    }

    // ── Generic extractor by provider URL ─────────────────────────────────

    private fun extractFromProviderUrl(serverName: String, link: String): Map<String, String>? {
        return when {
            serverName.contains("Voe", ignoreCase = true) -> extractVoe(link)
            serverName.contains("Streamtape", ignoreCase = true) -> extractStreamtape(link)
            else -> extractGenericPage(serverName, link)
        }
    }

    // ── Voe ───────────────────────────────────────────────────────────────

    private fun extractVoe(link: String): Map<String, String>? {
        Log.i(TAG, "Voe: extracting $link")
        val request = Request.Builder()
            .url(link)
            .header("User-Agent", UA)
            .header("Referer", link)
            .build()

        val response = client.newCall(request).execute()
        val html = response.body?.string() ?: return null
        val finalUrl = response.request.url.toString()

        val scriptPattern = Pattern.compile("""<script\s+type="application/json">(.*?)</script>""", Pattern.DOTALL)
        val matcher = scriptPattern.matcher(html)
        if (!matcher.find()) { Log.e(TAG, "Voe: no script found"); return null }

        val encoded = matcher.group(1)?.trim() ?: return null
        val decrypted = decryptVoe(encoded)
        val m3u8 = decrypted.optString("source", "")
        if (m3u8.isEmpty()) { Log.e(TAG, "Voe: no source"); return null }

        return mapOf("url" to m3u8, "source" to "Voe", "type" to "direct_m3u8", "referer" to finalUrl)
    }

    private fun decryptVoe(input: String): JSONObject {
        try {
            var s = rot13(input)
            s = s.replace("@$", "_").replace("^^", "_").replace("~@", "_")
               .replace("%?", "_").replace("*~", "_").replace("!!", "_").replace("#&", "_")
            s = s.replace("_", "")
            s = String(Base64.decode(s, Base64.NO_WRAP), Charsets.UTF_8)
            s = charShift(s, -3)
            s = s.reversed()
            s = String(Base64.decode(s, Base64.NO_WRAP), Charsets.UTF_8)
            return JSONObject(s)
        } catch (e: Exception) {
            Log.e(TAG, "Voe decrypt error: ${e.message}")
            return JSONObject()
        }
    }

    // ── Streamtape ────────────────────────────────────────────────────────

    private fun extractStreamtape(link: String): Map<String, String>? {
        Log.i(TAG, "Streamtape: extracting $link")
        val request = Request.Builder().url(link).header("User-Agent", UA).build()
        val response = client.newCall(request).execute()
        val html = response.body?.string() ?: return null

        val pattern = Pattern.compile(
            """document\.getElementById\('botlink'\)\.innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)"""
        )
        val matcher = pattern.matcher(html)
        if (!matcher.find()) { Log.e(TAG, "Streamtape: botlink not found"); return null }

        val paramString = matcher.group(2) ?: return null
        val idx = (matcher.group(3) ?: "0").toInt()
        val clean = paramString.substring(idx)

        val id = findParam(clean, "id") ?: return null
        val expires = findParam(clean, "expires") ?: return null
        val ip = findParam(clean, "ip") ?: return null
        val token = findParam(clean, "token") ?: return null

        val videoUrl = "https://streamtape.com/get_video?id=$id&expires=$expires&ip=$ip&token=$token&stream=1"
        val videoRequest = Request.Builder().url(videoUrl).header("User-Agent", UA).build()
        val videoResponse = client.newCall(videoRequest).execute()
        val finalUrl = videoResponse.request.url.toString()

        if (finalUrl != videoUrl) {
            return mapOf("url" to finalUrl, "source" to "Streamtape", "type" to "direct_video", "referer" to "https://streamtape.com/")
        }
        return null
    }

    // ── Generic page scraper ──────────────────────────────────────────────

    private fun extractGenericPage(serverName: String, link: String): Map<String, String>? {
        val request = Request.Builder().url(link).header("User-Agent", UA).header("Referer", link).build()
        val response = client.newCall(request).execute()
        val html = response.body?.string() ?: return null

        val m3u8 = Pattern.compile("https?://[^\\s\"'<>]+\\.m3u8[^\\s\"'<>]*", Pattern.CASE_INSENSITIVE).matcher(html)
        if (m3u8.find()) {
            return mapOf("url" to m3u8.group(0)!!, "source" to serverName, "type" to "direct_m3u8", "referer" to link)
        }
        val mp4 = Pattern.compile("https?://[^\\s\"'<>]+\\.mp4[^\\s\"'<>]*", Pattern.CASE_INSENSITIVE).matcher(html)
        if (mp4.find()) {
            return mapOf("url" to mp4.group(0)!!, "source" to serverName, "type" to "direct_video", "referer" to link)
        }
        return null
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private fun extractBetween(source: String, before: String, after: String): String? {
        val i = source.indexOf(before)
        if (i == -1) return null
        val start = i + before.length
        val j = source.indexOf(after, start)
        if (j == -1) return null
        return source.substring(start, j).trim()
    }

    private fun findParam(source: String, name: String): String? {
        val m = Pattern.compile("$name=([^&]+)").matcher(source)
        return if (m.find()) m.group(1) else null
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
        return String(CharArray(input.length) { i -> (input[i].code - shift).toChar() })
    }
}
