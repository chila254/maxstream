package com.maxstream.app

import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.Dns
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.dnsoverhttps.DnsOverHttps
import org.json.JSONObject
import java.net.URI
import java.net.URLEncoder
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/** Resolves TMDB metadata through server providers and host-specific extractors. */
class StreamExtractor {
    private val tag = "StreamExtractor"
    private val userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    data class MediaRequest(
        val tmdbId: String,
        val isMovie: Boolean,
        val season: Int,
        val episode: Int,
        val title: String,
    )

    data class StreamServer(
        val name: String,
        val url: String,
        val headers: Map<String, String> = emptyMap(),
    )

    data class StreamResult(
        val url: String,
        val source: String,
        val type: String,
        val headers: Map<String, String> = emptyMap(),
    ) {
        fun toMap(): Map<String, Any> = mapOf(
            "url" to url,
            "source" to source,
            "type" to type,
            "headers" to headers,
            "referer" to (headers["Referer"] ?: ""),
        )
    }

    private sealed interface ExtractionResult {
        data class Final(val stream: StreamResult) : ExtractionResult
        data class Redirect(val server: StreamServer) : ExtractionResult
    }

    private interface ServerProvider {
        val name: String
        suspend fun getServers(request: MediaRequest): List<StreamServer>
    }

    private interface HostExtractor {
        val name: String
        fun supports(server: StreamServer): Boolean
        suspend fun extract(server: StreamServer): ExtractionResult
    }

    private class MemoryCookieJar : CookieJar {
        private val cookies = ConcurrentHashMap<String, List<Cookie>>()

        override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
            this.cookies[url.host] = cookies
        }

        override fun loadForRequest(url: HttpUrl): List<Cookie> {
            return cookies[url.host].orEmpty().filter { it.matches(url) }
        }
    }

    private val bootstrapClient = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build()

    private val dns: Dns by lazy {
        try {
            DnsOverHttps.Builder()
                .client(bootstrapClient)
                .url("https://dns.google/dns-query".toHttpUrl())
                .build()
        } catch (error: Exception) {
            Log.w(tag, "DNS-over-HTTPS unavailable; using system DNS", error)
            Dns.SYSTEM
        }
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(12, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .cookieJar(MemoryCookieJar())
        .dns(dns)
        .build()

    private val noRedirectClient = client.newBuilder()
        .followRedirects(false)
        .followSslRedirects(false)
        .build()

    private val serverProviders: List<ServerProvider> by lazy {
        listOf(
            StaticTmdbProvider(),
            VidrockServerProvider(),
            VidzeeServerProvider(),
            PrimeSrcServerProvider(),
        )
    }

    private val extractorRegistry: List<HostExtractor> by lazy {
        listOf(
            VidflixExtractor(),
            RpmExtractor(),
            VixSrcExtractor(),
            VidrockExtractor(),
            VidzeeExtractor(),
            VideasyExtractor(),
            PrimeSrcExtractor(),
            VoeExtractor(),
            StreamtapeExtractor(),
            TwoEmbedExtractor(),
            GenericMediaExtractor(),
        )
    }

    suspend fun resolveStream(
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1,
        title: String = "",
    ): Map<String, Any>? = withContext(Dispatchers.IO) {
        require(tmdbId.isNotBlank()) { "TMDB ID is required" }

        val media = MediaRequest(tmdbId, isMovie, season, episode, title)
        Log.i(tag, "Resolving TMDB $tmdbId (movie=$isMovie, S$season E$episode)")

        val servers = buildServerList(media)
        Log.i(tag, "Built ${servers.size} servers: ${servers.joinToString { it.name }}")

        for (server in servers) {
            try {
                val stream = extractServer(server)
                if (stream != null && stream.url.isNotBlank()) {
                    Log.i(tag, "Resolved ${server.name} to ${stream.source}")
                    return@withContext stream.toMap()
                }
            } catch (error: Exception) {
                Log.e(tag, "Server ${server.name} failed at ${server.url}", error)
            }
        }

        Log.w(tag, "No playable stream found for TMDB $tmdbId")
        null
    }

    private suspend fun buildServerList(media: MediaRequest): List<StreamServer> = coroutineScope {
        serverProviders.map { provider ->
            async(Dispatchers.IO) {
                try {
                    provider.getServers(media).also {
                        Log.d(tag, "${provider.name} supplied ${it.size} servers")
                    }
                } catch (error: Exception) {
                    Log.e(tag, "Server provider ${provider.name} failed", error)
                    emptyList()
                }
            }
        }.awaitAll().flatten().distinctBy { it.url }
    }

    private suspend fun extractServer(initialServer: StreamServer): StreamResult? {
        var server = initialServer
        val visited = mutableSetOf<String>()

        repeat(5) {
            if (!visited.add(server.url)) {
                throw IllegalStateException("Extractor redirect loop for ${server.url}")
            }

            val extractor = extractorRegistry.firstOrNull { it.supports(server) }
                ?: throw IllegalArgumentException("No extractor for ${server.name}: ${server.url}")
            Log.d(tag, "Dispatching ${server.name} to ${extractor.name}")

            when (val result = extractor.extract(server)) {
                is ExtractionResult.Final -> return result.stream
                is ExtractionResult.Redirect -> server = result.server
            }
        }

        throw IllegalStateException("Too many extractor redirects for ${initialServer.name}")
    }

    private inner class StaticTmdbProvider : ServerProvider {
        override val name = "TMDB"

        override suspend fun getServers(request: MediaRequest): List<StreamServer> {
            val id = request.tmdbId
            val servers = mutableListOf<StreamServer>()

            // This source currently provides a reliable direct host redirect.
            servers += StreamServer(
                "Vidflix",
                if (request.isMovie) {
                    "https://vidflix.club/api/movie/$id"
                } else {
                    "https://vidflix.club/api/tv/$id/${request.season}/${request.episode}"
                },
            )

            servers += StreamServer(
                "VixSrc",
                if (request.isMovie) {
                    "https://vixsrc.to/api/movie/$id?lang=en"
                } else {
                    "https://vixsrc.to/api/tv/$id/${request.season}/${request.episode}?lang=en"
                },
            )

            servers += StreamServer(
                "2Embed",
                if (request.isMovie) {
                    "https://www.2embed.cc/embed/$id"
                } else {
                    "https://www.2embed.cc/embedtv/$id&s=${request.season}&e=${request.episode}"
                },
            )

            val encodedTitle = URLEncoder.encode(request.title, Charsets.UTF_8.name())
            val videasyEndpoints = listOf("mb-flix", "cdn", "downloader2", "1movies", "m4uhd", "hdmovie")
            for (endpoint in videasyEndpoints) {
                val url = if (request.isMovie) {
                    "https://api.videasy.net/$endpoint/sources-with-title?title=$encodedTitle&mediaType=movie&tmdbId=$id"
                } else {
                    "https://api.videasy.net/$endpoint/sources-with-title?title=$encodedTitle&mediaType=tv&tmdbId=$id&episodeId=${request.episode}&seasonId=${request.season}"
                }
                servers += StreamServer("Videasy $endpoint", url)
            }

            return servers
        }
    }

    private inner class VidrockServerProvider : ServerProvider {
        override val name = "Vidrock"
        private val passphrase = "x7k9mPqT2rWvY8zA5bC3nF6hJ2lK4mN9"

        override suspend fun getServers(request: MediaRequest): List<StreamServer> {
            val plain = if (request.isMovie) request.tmdbId
                else "${request.tmdbId}_${request.season}_${request.episode}"
            val encoded = aesCbcEncrypt(plain, passphrase)
            val apiUrl = "https://vidrock.net/api/${if (request.isMovie) "movie" else "tv"}/$encoded"
            val json = getJson(apiUrl, refererHeaders("https://vidrock.net/"))

            return json.keys().asSequence().mapNotNull { serverName ->
                val value = json.optJSONObject(serverName) ?: return@mapNotNull null
                if (value.optString("url").isBlank()) return@mapNotNull null
                StreamServer("$serverName (Vidrock)", "$apiUrl#$serverName")
            }.toList()
        }
    }

    private inner class VidzeeServerProvider : ServerProvider {
        override val name = "Vidzee"

        override suspend fun getServers(request: MediaRequest): List<StreamServer> {
            val names = listOf(
                "Nflix", "Duke", "Glory", "Nazy", "Atlas", "Drag", "Achilles",
                "Viet", "Velocita", "Hindi", "Bengali", "Tamil", "Telugu", "Malayalam",
            )
            return names.mapIndexed { index, serverName ->
                val url = if (request.isMovie) {
                    "https://player.vidzee.wtf/api/server?id=${request.tmdbId}&sr=$index"
                } else {
                    "https://player.vidzee.wtf/api/server?id=${request.tmdbId}&ss=${request.season}&ep=${request.episode}&sr=$index"
                }
                StreamServer("$serverName (Vidzee)", url)
            }
        }
    }

    private inner class PrimeSrcServerProvider : ServerProvider {
        override val name = "PrimeSrc"

        override suspend fun getServers(request: MediaRequest): List<StreamServer> {
            val url = if (request.isMovie) {
                "https://primesrc.me/api/v1/s?tmdb=${request.tmdbId}&type=movie"
            } else {
                "https://primesrc.me/api/v1/s?tmdb=${request.tmdbId}&season=${request.season}&episode=${request.episode}&type=tv"
            }
            val json = getJson(url, refererHeaders("https://primesrc.me/"))
            val servers = json.optJSONArray("servers") ?: return emptyList()

            return (0 until servers.length()).mapNotNull { index ->
                val item = servers.optJSONObject(index) ?: return@mapNotNull null
                val key = item.optString("key")
                if (key.isBlank()) return@mapNotNull null
                val serverName = item.optString("name", "PrimeSrc")
                StreamServer(
                    "$serverName (PrimeSrc)",
                    "https://primesrc.me/api/v1/l?key=$key",
                    refererHeaders("https://primesrc.me/"),
                )
            }
        }
    }

    private inner class VidflixExtractor : HostExtractor {
        override val name = "Vidflix"
        override fun supports(server: StreamServer) = host(server.url).endsWith("vidflix.club")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val referer = server.url.replace("/api/", "/")
            val response = getJson(server.url, refererHeaders(referer))
            val videoUrl = response.optString("video_url")
            require(videoUrl.isNotBlank()) { "Vidflix returned no video_url" }
            return ExtractionResult.Redirect(StreamServer("RPM video", videoUrl))
        }
    }

    private inner class RpmExtractor : HostExtractor {
        override val name = "RPM"
        private val key = "kiemtienmua911ca".toByteArray()
        private val iv = "1234567890oiuytr".toByteArray()

        override fun supports(server: StreamServer): Boolean {
            val domain = host(server.url)
            return server.name.contains("rpm", true) ||
                domain.contains("rpm") ||
                domain in setOf("flixcdn.cyou", "primevid.click", "loadm.cam")
        }

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val uri = URI(server.url)
            val id = uri.rawFragment?.substringBefore('&').orEmpty()
            require(id.isNotBlank()) { "RPM link has no media ID" }
            val origin = "${uri.scheme}://${uri.host}"
            val apiUrl = "$origin/api/v1/video?id=${encode(id)}&w=1920&h=1080&r="
            val encrypted = httpGet(apiUrl, refererHeaders(origin)).trim()
            val json = JSONObject(decryptHexPayload(encrypted, key, iv))

            val hls = json.optString("hls").takeIf { it.isNotBlank() }
            val hlsTiktok = json.optString("hlsVideoTiktok").takeIf { it.isNotBlank() }
            val cloudflare = json.optString("cf").takeIf { it.isNotBlank() }
            val finalUrl = when {
                hls != null -> absoluteMediaUrl(origin, hls)
                hlsTiktok != null -> {
                    val version = runCatching {
                        JSONObject(json.optString("streamingConfig"))
                            .optJSONObject("adjust")
                            ?.optJSONObject("Tiktok")
                            ?.optJSONObject("params")
                            ?.optString("v")
                            .orEmpty()
                    }.getOrDefault("")
                    absoluteMediaUrl(origin, hlsTiktok) +
                        if (version.isBlank()) "" else "?v=${encode(version)}"
                }
                cloudflare != null -> addCloudflareToken(json, cloudflare)
                else -> throw IllegalStateException("RPM response contains no playable source")
            }

            return ExtractionResult.Final(
                StreamResult(finalUrl, name, mediaType(finalUrl), refererHeaders(origin)),
            )
        }
    }

    private inner class VixSrcExtractor : HostExtractor {
        override val name = "VixSrc"
        override fun supports(server: StreamServer) = host(server.url).endsWith("vixsrc.to")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val api = getJson(
                server.url,
                refererHeaders("https://vixsrc.to") + mapOf("X-Requested-With" to "XMLHttpRequest"),
            )
            val embedPath = api.optString("src").trimStart('/')
            require(embedPath.isNotBlank()) { "VixSrc returned no embed path" }
            val embedUrl = "https://vixsrc.to/$embedPath"
            val html = httpGet(embedUrl, refererHeaders("https://vixsrc.to"))

            val videoSection = html.substringAfter("window.video = {", "")
            val playlistSection = html.substringAfter("window.masterPlaylist", "")
            val videoId = between(videoSection, "id: '", "'")
            val token = between(playlistSection, "'token': '", "'")
            val expires = between(playlistSection, "'expires': '", "'")
            require(videoId != null && token != null && expires != null) {
                "VixSrc player parameters were not found"
            }

            val query = mutableListOf("token=${encode(token)}", "expires=${encode(expires)}", "lang=en")
            if (html.contains("b=1")) query += "b=1"
            if (html.contains("window.canPlayFHD = true")) query += "h=1"
            val streamUrl = "https://vixsrc.to/playlist/$videoId?${query.joinToString("&")}"
            return ExtractionResult.Final(
                StreamResult(streamUrl, name, "direct_m3u8", refererHeaders(embedUrl)),
            )
        }
    }

    private inner class VidrockExtractor : HostExtractor {
        override val name = "Vidrock"
        override fun supports(server: StreamServer) = host(server.url).endsWith("vidrock.net")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val apiUrl = server.url.substringBefore('#')
            val selectedName = server.url.substringAfter('#', "")
            val json = getJson(apiUrl, refererHeaders("https://vidrock.net/"))
            val item = json.optJSONObject(selectedName)
                ?: json.keys().asSequence().mapNotNull { json.optJSONObject(it) }
                    .firstOrNull { it.optString("url").isNotBlank() }
                ?: throw IllegalStateException("Vidrock returned no sources")
            var url = item.optString("url")

            if (selectedName.equals("Atlas", true)) {
                val qualities = getJsonArray(url, refererHeaders("https://vidrock.net/"))
                val highest = (0 until qualities.length())
                    .mapNotNull { qualities.optJSONObject(it) }
                    .maxByOrNull { it.optInt("resolution") }
                if (highest != null) url = highest.optString("url", url)
            }

            require(url.isNotBlank()) { "Vidrock source is empty" }
            val headers = refererHeaders("https://vidrock.net/") + mapOf("Origin" to "https://vidrock.net")
            return ExtractionResult.Final(StreamResult(url, "$name $selectedName", mediaType(url), headers))
        }
    }

    private inner class VidzeeExtractor : HostExtractor {
        override val name = "Vidzee"
        private val player = "https://player.vidzee.wtf"
        private val staticPass = "4f2a9c7d1e8b3a6f0d5c2e9a7b1f4d8c"

        override fun supports(server: StreamServer) = host(server.url).endsWith("vidzee.wtf")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val masterKey = getVidzeeMasterKey()
            val response = getJson(
                server.url,
                refererHeaders("$player/") + mapOf("Origin" to player),
            )
            val encrypted = response.optJSONArray("url")?.optJSONObject(0)?.optString("link").orEmpty()
            require(encrypted.isNotBlank()) { "Vidzee returned no encrypted link" }
            val url = decryptVidzeeLink(encrypted, masterKey)
            val headers = refererHeaders(player) + mapOf("Origin" to player)
            return ExtractionResult.Final(StreamResult(url, server.name, mediaType(url), headers))
        }

        private fun getVidzeeMasterKey(): String {
            val encoded = httpGet("https://core.vidzee.wtf/api-key", refererHeaders("$player/"))
            val data = Base64.decode(encoded.trim(), Base64.DEFAULT)
            require(data.size > 28) { "Invalid Vidzee key payload" }
            val iv = data.copyOfRange(0, 12)
            val authTag = data.copyOfRange(12, 28)
            val ciphertext = data.copyOfRange(28, data.size)
            val key = MessageDigest.getInstance("SHA-256").digest(staticPass.toByteArray())
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
            return String(cipher.doFinal(ciphertext + authTag), Charsets.UTF_8)
        }

        private fun decryptVidzeeLink(encoded: String, masterKey: String): String {
            val decoded = String(Base64.decode(encoded, Base64.DEFAULT), Charsets.UTF_8)
            val parts = decoded.split(':', limit = 2)
            require(parts.size == 2) { "Invalid Vidzee link payload" }
            val iv = Base64.decode(parts[0], Base64.DEFAULT)
            val ciphertext = Base64.decode(parts[1], Base64.DEFAULT)
            val sourceKey = masterKey.toByteArray()
            val key = ByteArray(32) { index -> sourceKey.getOrElse(index) { 0 } }
            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
            return String(cipher.doFinal(ciphertext), Charsets.UTF_8)
        }
    }

    private inner class VideasyExtractor : HostExtractor {
        override val name = "Videasy"
        override fun supports(server: StreamServer) = host(server.url).endsWith("videasy.net")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val encrypted = httpGet(server.url)
            val tmdbId = server.url.substringAfter("tmdbId=", "").substringBefore('&')
            val requestJson = JSONObject().put("text", encrypted).put("id", tmdbId)
            val decrypted = postJson("https://enc-dec.app/api/dec-videasy", requestJson.toString())
            val result = JSONObject(decrypted).optString("result")
            val source = JSONObject(result).optJSONArray("sources")?.optJSONObject(0)?.optString("url").orEmpty()
            require(source.isNotBlank()) { "Videasy returned no source" }
            return ExtractionResult.Final(
                StreamResult(source, server.name, mediaType(source), refererHeaders("https://player.videasy.net/")),
            )
        }
    }

    private inner class PrimeSrcExtractor : HostExtractor {
        override val name = "PrimeSrc"
        override fun supports(server: StreamServer) = host(server.url).endsWith("primesrc.me")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val headers = server.headers + mapOf(
                "Accept" to "application/json, text/plain, */*",
                "Origin" to "https://primesrc.me",
                "X-Requested-With" to "XMLHttpRequest",
            )
            val link = getJson(server.url, headers).optString("link")
            require(link.isNotBlank()) { "PrimeSrc returned no host link" }
            return ExtractionResult.Redirect(StreamServer(server.name.substringBefore(" ("), link))
        }
    }

    private inner class VoeExtractor : HostExtractor {
        override val name = "VOE"
        private val aliases = setOf(
            "voe.sx", "jilliandescribecompany.com", "mikaylaarealike.com",
            "christopheruntilpoint.com", "walterprettytheir.com", "crystaltreatmenteast.com",
            "lauradaydo.com", "lancewhosedifficult.com", "dianaavoidthey.com",
            "jefferycontrolmodel.com", "charlestoughrace.com", "richardquestionbuilding.com",
            "jessicayeahcatch.com", "juliewomanwish.com",
        )

        override fun supports(server: StreamServer) = host(server.url) in aliases || server.name.contains("voe", true)

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val html = httpGet(server.url, refererHeaders(server.url))
            val encoded = Pattern.compile(
                """<script\s+type=["']application/json["']>(.*?)</script>""",
                Pattern.DOTALL or Pattern.CASE_INSENSITIVE,
            ).matcher(html).let { if (it.find()) it.group(1)?.trim() else null }
                ?: throw IllegalStateException("VOE payload not found")
            val json = decryptVoe(encoded)
            val url = json.optString("source")
            require(url.isNotBlank()) { "VOE returned no source" }
            return ExtractionResult.Final(StreamResult(url, name, mediaType(url), refererHeaders(server.url)))
        }
    }

    private inner class StreamtapeExtractor : HostExtractor {
        override val name = "Streamtape"
        override fun supports(server: StreamServer): Boolean {
            val domain = host(server.url)
            return domain.endsWith("streamtape.com") || domain.endsWith("streamta.site") ||
                server.name.contains("streamtape", true)
        }

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val html = httpGet(server.url)
            val matcher = Pattern.compile(
                """document\.getElementById\('botlink'\)\.innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)""",
            ).matcher(html)
            require(matcher.find()) { "Streamtape botlink not found" }
            val prefix = matcher.group(1).orEmpty()
            val value = matcher.group(2).orEmpty()
            val start = matcher.group(3).orEmpty().toInt()
            val videoUrl = if (prefix.startsWith("http")) prefix + value.substring(start)
                else "https://streamtape.com${prefix + value.substring(start)}"
            val finalUrl = followRedirect(videoUrl)
            return ExtractionResult.Final(
                StreamResult(finalUrl, name, "direct_video", refererHeaders("https://streamtape.com/")),
            )
        }
    }

    private inner class TwoEmbedExtractor : HostExtractor {
        override val name = "2Embed"
        override fun supports(server: StreamServer) = host(server.url).contains("2embed")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val html = httpGet(server.url)
            val iframe = Regex("""<iframe[^>]+(?:data-src|src)=["']([^"']+)["']""", RegexOption.IGNORE_CASE)
                .find(html)?.groupValues?.get(1)
                ?: throw IllegalStateException("2Embed iframe not found")
            val absolute = resolveUrl(server.url, iframe)
            return ExtractionResult.Redirect(StreamServer("2Embed host", absolute, refererHeaders(server.url)))
        }
    }

    private inner class GenericMediaExtractor : HostExtractor {
        override val name = "Generic media"
        override fun supports(server: StreamServer) = true

        override suspend fun extract(server: StreamServer): ExtractionResult {
            if (isMediaUrl(server.url)) {
                return ExtractionResult.Final(
                    StreamResult(server.url, server.name, mediaType(server.url), server.headers),
                )
            }

            val html = httpGet(server.url, server.headers + refererHeaders(server.url))
            val match = Regex(
                """https?://[^\s"'<>]+\.(?:m3u8|mp4)(?:[^\s"'<>]*)?""",
                RegexOption.IGNORE_CASE,
            ).find(html)?.value ?: throw IllegalStateException("No media URL found in page")
            val url = match.replace("\\/", "/").replace("&amp;", "&")
            return ExtractionResult.Final(
                StreamResult(url, server.name, mediaType(url), server.headers + refererHeaders(server.url)),
            )
        }
    }

    private fun httpGet(url: String, headers: Map<String, String> = emptyMap()): String {
        val request = Request.Builder().url(url).apply {
            header("User-Agent", userAgent)
            header("Accept", "*/*")
            headers.forEach { (name, value) -> header(name, value) }
        }.build()

        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IllegalStateException("HTTP ${response.code} for $url: ${body.take(160)}")
            }
            return body
        }
    }

    private fun postJson(url: String, json: String): String {
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", userAgent)
            .post(json.toRequestBody("application/json".toMediaType()))
            .build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) throw IllegalStateException("HTTP ${response.code} for $url")
            return body
        }
    }

    private fun getJson(url: String, headers: Map<String, String> = emptyMap()) =
        JSONObject(httpGet(url, headers))

    private fun getJsonArray(url: String, headers: Map<String, String> = emptyMap()) =
        org.json.JSONArray(httpGet(url, headers))

    private fun followRedirect(url: String): String {
        val request = Request.Builder().url(url).header("User-Agent", userAgent).build()
        noRedirectClient.newCall(request).execute().use { response ->
            return response.header("Location")?.let { resolveUrl(url, it) }
                ?: response.request.url.toString()
        }
    }

    private fun refererHeaders(referer: String) = mapOf(
        "Referer" to referer,
        "User-Agent" to userAgent,
    )

    private fun host(url: String): String = try {
        URI(url.substringBefore('#')).host?.lowercase().orEmpty()
    } catch (_: Exception) {
        ""
    }

    private fun resolveUrl(base: String, value: String): String = URI(base).resolve(value).toString()
    private fun absoluteMediaUrl(origin: String, value: String) =
        if (value.startsWith("http")) value else "$origin${if (value.startsWith('/')) "" else "/"}$value"

    private fun addCloudflareToken(json: JSONObject, url: String): String {
        val configured = runCatching {
            val cloudflare = JSONObject(json.optString("streamingConfig"))
                .optJSONObject("adjust")
                ?.optJSONObject("Cloudflare")
            if (cloudflare?.optBoolean("disabled", true) != false) return@runCatching null
            val parameters = cloudflare.optJSONObject("params")
            parameters?.optString("t") to parameters?.optString("e")
        }.getOrNull()
        val fallback = json.optString("cfExpire").split("::").let {
            if (it.size >= 2) it[0] to it[1] else null
        }
        val token = configured?.takeIf { !it.first.isNullOrBlank() && !it.second.isNullOrBlank() }
            ?: fallback
        return if (token == null) url else {
            val separator = if (url.contains('?')) '&' else '?'
            "$url${separator}t=${encode(token.first.orEmpty())}&e=${encode(token.second.orEmpty())}"
        }
    }

    private fun encode(value: String) = URLEncoder.encode(value, Charsets.UTF_8.name())
    private fun isMediaUrl(url: String) = url.contains(".m3u8", true) || url.contains(".mp4", true)
    private fun mediaType(url: String) = if (url.contains(".m3u8", true)) "direct_m3u8" else "direct_video"

    private fun aesCbcEncrypt(value: String, passphrase: String): String {
        val key = passphrase.toByteArray()
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(key.copyOfRange(0, 16)))
        return Base64.encodeToString(
            cipher.doFinal(value.toByteArray()),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
    }

    private fun decryptHexPayload(value: String, key: ByteArray, iv: ByteArray): String {
        val cleaned = value.lowercase().replace(Regex("[^0-9a-f]"), "")
        require(cleaned.length % 2 == 0) { "Encrypted hex payload has odd length" }
        val bytes = ByteArray(cleaned.length / 2) { index ->
            cleaned.substring(index * 2, index * 2 + 2).toInt(16).toByte()
        }
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
        return String(cipher.doFinal(bytes), Charsets.UTF_8)
    }

    private fun between(value: String, before: String, after: String): String? {
        val start = value.indexOf(before)
        if (start < 0) return null
        val contentStart = start + before.length
        val end = value.indexOf(after, contentStart)
        return if (end < 0) null else value.substring(contentStart, end).trim()
    }

    private fun decryptVoe(value: String): JSONObject {
        var data = rot13(value)
        listOf("@$", "^^", "~@", "%?", "*~", "!!", "#&").forEach { data = data.replace(it, "_") }
        data = String(Base64.decode(data.replace("_", ""), Base64.NO_WRAP), Charsets.UTF_8)
        data = data.map { (it.code + 3).toChar() }.joinToString("").reversed()
        data = String(Base64.decode(data, Base64.NO_WRAP), Charsets.UTF_8)
        return JSONObject(data)
    }

    private fun rot13(value: String) = value.map { character ->
        when (character) {
            in 'A'..'Z' -> ((character - 'A' + 13) % 26 + 'A'.code).toChar()
            in 'a'..'z' -> ((character - 'a' + 13) % 26 + 'a'.code).toChar()
            else -> character
        }
    }.joinToString("")
}
