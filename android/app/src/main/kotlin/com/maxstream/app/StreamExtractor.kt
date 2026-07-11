package com.maxstream.app

import android.util.Base64
import android.util.Log
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.dnsoverhttps.DnsOverHttps
import org.json.JSONObject
import java.net.InetAddress
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Complete stream extractor ported from streamflix.
 * Providers: VixSrc, Vidrock, Vidzee, Videasy, VidsrcNet, StreamWish/TwoEmbed,
 * Voe, Streamtape, PrimeSrc + DNS-over-HTTPS.
 */
class StreamExtractor {
    private val TAG = "StreamExtractor"
    private val UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    // DNS-over-HTTPS resolver
    private val dohClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    private val dns: Dns by lazy {
        try {
            DnsOverHttps.Builder()
                .client(dohClient)
                .url("https://dns.google/dns-query".toHttpUrl())
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "DoH failed, using system DNS: ${e.message}")
            Dns.SYSTEM
        }
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .dns(dns)
        .build()

    private val clientNoRedirect = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .followRedirects(false)
        .followSslRedirects(false)
        .dns(dns)
        .build()

    suspend fun resolveStream(
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1,
        title: String = ""
    ): Map<String, String>? = withContext(Dispatchers.IO) {
        Log.i(TAG, "=== Resolving TMDB $tmdbId (movie=$isMovie) ===")

        // Build server list like TmdbProvider.getServers() for English
        val extractors: List<suspend () -> Map<String, String>?> = listOf(
            { extractVixSrc(tmdbId, isMovie, season, episode) },
            { extractVidrock(tmdbId, isMovie, season, episode) },
            { extractVidzee(tmdbId, isMovie, season, episode) },
            { extractVideasy(tmdbId, isMovie, season, episode, title) },
            { extractPrimeSrc(tmdbId, isMovie, season, episode) },
        )

        for ((i, extractor) in extractors.withIndex()) {
            try {
                Log.i(TAG, "Trying provider ${i + 1}/${extractors.size}")
                val result = extractor()
                if (result != null && result["url"]?.isNotEmpty() == true) {
                    Log.i(TAG, "=== SUCCESS: ${result["source"]}: ${result["url"]} ===")
                    return@withContext result
                }
            } catch (e: Exception) {
                Log.e(TAG, "Provider ${i + 1} failed: ${e.message}")
            }
        }

        Log.w(TAG, "=== All providers failed ===")
        null
    }

    // ══════════════════════════════════════════════════════════════════════
    // VixSrc
    // ══════════════════════════════════════════════════════════════════════

    private fun extractVixSrc(tmdbId: String, isMovie: Boolean, season: Int, episode: Int): Map<String, String>? {
        val apiPath = if (isMovie) "api/movie/$tmdbId?lang=en" else "api/tv/$tmdbId/$season/$episode?lang=en"
        val apiBody = httpGet("https://vixsrc.to/$apiPath", mapOf("Referer" to "https://vixsrc.to", "X-Requested-With" to "XMLHttpRequest")) ?: return null
        val apiJson = try { JSONObject(apiBody) } catch (e: Exception) { return null }
        val embedPath = apiJson.optString("src", "").trimStart('/')
        if (embedPath.isEmpty()) return null

        val html = httpGet("https://vixsrc.to/$embedPath", mapOf("Referer" to "https://vixsrc.to")) ?: return null

        val videoId = extractBetween(html, "id: '", "'") ?: return null
        val token = extractBetween(html, "'token': '", "'") ?: return null
        val expires = extractBetween(html, "'expires': '", "'") ?: return null
        val hasB = html.contains("b=1")
        val canFHD = html.contains("window.canPlayFHD = true")

        val params = mutableListOf("token=$token", "expires=$expires", "lang=en")
        if (hasB) params.add("b=1")
        if (canFHD) params.add("h=1")

        val m3u8Url = "https://vixsrc.to/playlist/$videoId?${params.joinToString("&")}"
        Log.i(TAG, "VixSrc: $m3u8Url")
        return mapOf("url" to m3u8Url, "source" to "VixSrc", "type" to "direct_m3u8", "referer" to "https://vixsrc.to/$embedPath")
    }

    // ══════════════════════════════════════════════════════════════════════
    // Vidrock (AES-CBC encrypted API)
    // ══════════════════════════════════════════════════════════════════════

    private val VIDROCK_KEY = "x7k9mPqT2rWvY8zA5bC3nF6hJ2lK4mN9"

    private fun extractVidrock(tmdbId: String, isMovie: Boolean, season: Int, episode: Int): Map<String, String>? {
        val data = if (isMovie) tmdbId else "${tmdbId}_${season}_${episode}"
        val encoded = aesCbcEncrypt(data, VIDROCK_KEY)
        val path = if (isMovie) "api/movie/$encoded" else "api/tv/$encoded"
        val body = httpGet("https://vidrock.net/$path", mapOf("Referer" to "https://vidrock.net/", "Origin" to "https://vidrock.net")) ?: return null
        val json = try { JSONObject(body) } catch (e: Exception) { return null }

        val keys = json.keys()
        while (keys.hasNext()) {
            val name = keys.next()
            val sd = json.optJSONObject(name) ?: continue
            val url = sd.optString("url", "")
            if (url.isNotEmpty() && url.contains(".m3u8")) {
                Log.i(TAG, "Vidrock: $name -> $url")
                return mapOf("url" to url, "source" to "Vidrock ($name)", "type" to "direct_m3u8", "referer" to "https://vidrock.net/")
            }
        }
        return null
    }

    // ══════════════════════════════════════════════════════════════════════
    // Vidzee (AES-GCM key + AES-CBC link decryption)
    // ══════════════════════════════════════════════════════════════════════

    private val VIDZEE_PASS = "4f2a9c7d1e8b3a6f0d5c2e9a7b1f4d8c"
    private val VIDZEE_PLAYER = "https://player.vidzee.wtf"
    private val VIDZEE_CORE = "https://core.vidzee.wtf"
    private val VIDZEE_SERVERS = listOf("Nflix" to 0, "Duke" to 1, "Glory" to 2, "Nazy" to 3, "Atlas" to 4, "Drag" to 5, "Achilles" to 6, "Viet" to 7, "Velocità" to 8, "Hindi" to 9, "Bengali" to 10, "Tamil" to 11, "Telugu" to 12, "Malayalam" to 13)

    private fun extractVidzee(tmdbId: String, isMovie: Boolean, season: Int, episode: Int): Map<String, String>? {
        val masterKey = getVidzeeMasterKey() ?: return null

        for ((name, idx) in VIDZEE_SERVERS) {
            try {
                val baseUrl = if (isMovie) "$VIDZEE_PLAYER/api/server?id=$tmdbId&sr=$idx"
                    else "$VIDZEE_PLAYER/api/server?id=$tmdbId&ss=$season&ep=$episode&sr=$idx"
                val body = httpGet(baseUrl, mapOf("Referer" to "$VIDZEE_PLAYER/", "Origin" to VIDZEE_PLAYER)) ?: continue
                val json = try { JSONObject(body) } catch (e: Exception) { continue }
                val urlArr = json.optJSONArray("url") ?: continue
                if (urlArr.length() == 0) continue

                val link = urlArr.getJSONObject(0).optString("link", "")
                if (link.isEmpty()) continue

                val decrypted = decryptVidzeeLink(link, masterKey) ?: continue
                Log.i(TAG, "Vidzee ($name): $decrypted")
                val mime = if (idx == 1) "direct_video" else "direct_m3u8"
                return mapOf("url" to decrypted, "source" to "Vidzee ($name)", "type" to mime, "referer" to VIDZEE_PLAYER)
            } catch (e: Exception) {
                Log.e(TAG, "Vidzee $name failed: ${e.message}")
            }
        }
        return null
    }

    private fun getVidzeeMasterKey(): String? {
        return try {
            val body = httpGet("$VIDZEE_CORE/api-key", mapOf("Referer" to "$VIDZEE_PLAYER/")) ?: return null
            val data = Base64.decode(body.trim(), Base64.DEFAULT)
            val iv = data.copyOfRange(0, 12)
            val tag = data.copyOfRange(12, 28)
            val ciphertext = data.copyOfRange(28, data.size)
            val key = MessageDigest.getInstance("SHA-256").digest(VIDZEE_PASS.toByteArray())
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
            String(cipher.doFinal(ciphertext + tag), Charsets.UTF_8)
        } catch (e: Exception) { null }
    }

    private fun decryptVidzeeLink(encLink: String, masterKey: String): String? {
        return try {
            val decoded = String(Base64.decode(encLink, Base64.DEFAULT), Charsets.UTF_8)
            val parts = decoded.split(":")
            val iv = Base64.decode(parts[0], Base64.DEFAULT)
            val ct = Base64.decode(parts[1], Base64.DEFAULT)
            val keyBytes = masterKey.toByteArray()
            val paddedKey = ByteArray(32) { i -> if (i < keyBytes.size) keyBytes[i] else 0 }
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(paddedKey, "AES"), IvParameterSpec(iv))
            String(cipher.doFinal(ct), Charsets.UTF_8)
        } catch (e: Exception) { null }
    }

    // ══════════════════════════════════════════════════════════════════════
    // Videasy (encrypted API + external decryption)
    // ══════════════════════════════════════════════════════════════════════

    private val VIDEASY_SERVERS = listOf("mb-flix" to "Neon", "cdn" to "Yoru", "downloader2" to "Cypher", "1movies" to "Sage", "m4uhd" to "Breach", "hdmovie" to "Vyse")

    private fun extractVideasy(tmdbId: String, isMovie: Boolean, season: Int, episode: Int, title: String): Map<String, String>? {
        for ((endpoint, name) in VIDEASY_SERVERS) {
            try {
                val url = if (isMovie) "https://api.videasy.net/$endpoint/sources-with-title?title=${java.net.URLEncoder.encode(title, "UTF-8")}&mediaType=movie&tmdbId=$tmdbId"
                    else "https://api.videasy.net/$endpoint/sources-with-title?title=${java.net.URLEncoder.encode(title, "UTF-8")}&mediaType=tv&tmdbId=$tmdbId&episodeId=$episode&seasonId=$season"
                val encData = httpGet(url, emptyMap()) ?: continue

                // Decrypt via external API
                val json = JSONObject().apply { put("text", encData); put("id", tmdbId) }
                val decBody = httpPost("https://enc-dec.app/api/dec-videasy", json.toString()) ?: continue
                val decJson = JSONObject(decBody)
                val result = decJson.optString("result", "")
                if (result.isEmpty()) continue
                val resultJson = JSONObject(result)
                val sources = resultJson.optJSONArray("sources") ?: continue
                if (sources.length() == 0) continue

                val streamUrl = sources.getJSONObject(0).optString("url", "")
                if (streamUrl.isNotEmpty()) {
                    Log.i(TAG, "Videasy ($name): $streamUrl")
                    return mapOf("url" to streamUrl, "source" to "Videasy ($name)", "type" to "direct_m3u8", "referer" to "https://player.videasy.net/")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Videasy $name failed: ${e.message}")
            }
        }
        return null
    }

    // ══════════════════════════════════════════════════════════════════════
    // PrimeSrc (fallback)
    // ══════════════════════════════════════════════════════════════════════

    private fun extractPrimeSrc(tmdbId: String, isMovie: Boolean, season: Int, episode: Int): Map<String, String>? {
        val serversUrl = if (isMovie) "https://primesrc.me/api/v1/s?tmdb=$tmdbId&type=movie"
            else "https://primesrc.me/api/v1/s?tmdb=$tmdbId&season=$season&episode=$episode&type=tv"
        val body = httpGet(serversUrl, mapOf("Referer" to "https://primesrc.me/")) ?: return null
        val json = try { JSONObject(body) } catch (e: Exception) { return null }
        val servers = json.optJSONArray("servers") ?: return null

        for (i in 0 until servers.length()) {
            val s = servers.optJSONObject(i) ?: continue
            val name = s.optString("name", "")
            val key = s.optString("key", "")
            if (key.isEmpty()) continue

            try {
                val linkBody = httpGet("https://primesrc.me/api/v1/l?key=$key", mapOf("Referer" to "https://primesrc.me/", "Accept" to "application/json")) ?: continue
                val linkJson = try { JSONObject(linkBody) } catch (e: Exception) { continue }
                val link = linkJson.optString("link", "")
                if (link.isEmpty()) continue

                return when {
                    name.contains("Voe", true) -> extractVoe(link)
                    name.contains("Streamtape", true) -> extractStreamtape(link)
                    else -> extractGenericPage(name, link)
                }
            } catch (e: Exception) {
                Log.e(TAG, "PrimeSrc $name failed: ${e.message}")
            }
        }
        return null
    }

    // ══════════════════════════════════════════════════════════════════════
    // Voe (ROT13 + Base64 decryption)
    // ══════════════════════════════════════════════════════════════════════

    private fun extractVoe(link: String): Map<String, String>? {
        val html = httpGet(link, mapOf("Referer" to link)) ?: return null
        val finalUrl = getLastUrl(link)

        val pattern = Pattern.compile("""<script\s+type="application/json">(.*?)</script>""", Pattern.DOTALL)
        val matcher = pattern.matcher(html)
        if (!matcher.find()) return null

        val encoded = matcher.group(1)?.trim() ?: return null
        val decrypted = decryptVoe(encoded)
        val m3u8 = decrypted.optString("source", "")
        if (m3u8.isEmpty()) return null

        Log.i(TAG, "Voe: $m3u8")
        return mapOf("url" to m3u8, "source" to "Voe", "type" to "direct_m3u8", "referer" to finalUrl)
    }

    private fun decryptVoe(input: String): JSONObject {
        return try {
            var s = rot13(input)
            s = s.replace("@$", "_").replace("^^", "_").replace("~@", "_")
               .replace("%?", "_").replace("*~", "_").replace("!!", "_").replace("#&", "_")
            s = s.replace("_", "")
            s = String(Base64.decode(s, Base64.NO_WRAP), Charsets.UTF_8)
            s = charShift(s, -3).reversed()
            s = String(Base64.decode(s, Base64.NO_WRAP), Charsets.UTF_8)
            JSONObject(s)
        } catch (e: Exception) { JSONObject() }
    }

    // ══════════════════════════════════════════════════════════════════════
    // Streamtape (botlink JS parsing)
    // ══════════════════════════════════════════════════════════════════════

    private fun extractStreamtape(link: String): Map<String, String>? {
        val html = httpGet(link, emptyMap()) ?: return null

        val pattern = Pattern.compile(
            """document\.getElementById\('botlink'\)\.innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)"""
        )
        val matcher = pattern.matcher(html)
        if (!matcher.find()) return null

        val paramString = matcher.group(2) ?: return null
        val idx = (matcher.group(3) ?: "0").toInt()
        val clean = paramString.substring(idx)

        val id = findParam(clean, "id") ?: return null
        val expires = findParam(clean, "expires") ?: return null
        val ip = findParam(clean, "ip") ?: return null
        val token = findParam(clean, "token") ?: return null

        val videoUrl = "https://streamtape.com/get_video?id=$id&expires=$expires&ip=$ip&token=$token&stream=1"
        val finalUrl = followRedirect(videoUrl) ?: return null

        Log.i(TAG, "Streamtape: $finalUrl")
        return mapOf("url" to finalUrl, "source" to "Streamtape", "type" to "direct_video", "referer" to "https://streamtape.com/")
    }

    // ══════════════════════════════════════════════════════════════════════
    // Generic m3u8/mp4 page scraper
    // ══════════════════════════════════════════════════════════════════════

    private fun extractGenericPage(name: String, link: String): Map<String, String>? {
        val html = httpGet(link, mapOf("Referer" to link)) ?: return null

        val m3u8 = Pattern.compile("https?://[^\\s\"'<>]+\\.m3u8[^\\s\"'<>]*", Pattern.CASE_INSENSITIVE).matcher(html)
        if (m3u8.find()) {
            return mapOf("url" to m3u8.group(0)!!, "source" to name, "type" to "direct_m3u8", "referer" to link)
        }
        val mp4 = Pattern.compile("https?://[^\\s\"'<>]+\\.mp4[^\\s\"'<>]*", Pattern.CASE_INSENSITIVE).matcher(html)
        if (mp4.find()) {
            return mapOf("url" to mp4.group(0)!!, "source" to name, "type" to "direct_video", "referer" to link)
        }
        return null
    }

    // ══════════════════════════════════════════════════════════════════════
    // HTTP Helpers
    // ══════════════════════════════════════════════════════════════════════

    private fun httpGet(url: String, headers: Map<String, String>): String? {
        val builder = Request.Builder().url(url).header("User-Agent", UA)
        headers.forEach { (k, v) -> builder.header(k, v) }
        val response = client.newCall(builder.build()).execute()
        return response.body?.string()
    }

    private fun httpPost(url: String, body: String): String? {
        val reqBody = body.toRequestBody("application/json".toMediaType())
        val request = Request.Builder().url(url).post(reqBody).header("User-Agent", UA).build()
        val response = client.newCall(request).execute()
        return response.body?.string()
    }

    private fun followRedirect(url: String): String? {
        val request = Request.Builder().url(url).header("User-Agent", UA).build()
        val response = clientNoRedirect.newCall(request).execute()
        return response.header("Location") ?: response.request.url.toString()
    }

    private fun getLastUrl(url: String): String = url

    // ══════════════════════════════════════════════════════════════════════
    // Crypto Helpers
    // ══════════════════════════════════════════════════════════════════════

    private fun aesCbcEncrypt(data: String, passphrase: String): String {
        val key = passphrase.toByteArray()
        val iv = key.copyOfRange(0, 16)
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
        return Base64.encodeToString(cipher.doFinal(data.toByteArray()), Base64.URL_SAFE or Base64.NO_WRAP)
    }

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

    private fun rot13(input: String): String = String(CharArray(input.length) { i ->
        val c = input[i]
        when { c in 'A'..'Z' -> ((c - 'A' + 13) % 26 + 'A'.code).toChar(); c in 'a'..'z' -> ((c - 'a' + 13) % 26 + 'a'.code).toChar(); else -> c }
    })

    private fun charShift(input: String, shift: Int): String = String(CharArray(input.length) { i -> (input[i].code - shift).toChar() })
}
