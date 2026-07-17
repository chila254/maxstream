package com.maxstream.app

import android.annotation.SuppressLint
import android.content.Context
import android.text.Html
import android.util.Base64
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
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
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Resolves TMDB metadata through server providers and host-specific extractors. */
class StreamExtractor(private val context: Context) {
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
        val subtitles: List<SubtitleOption> = emptyList(),
    )

    data class StreamResult(
        val url: String,
        val source: String,
        val type: String,
        val headers: Map<String, String> = emptyMap(),
        val qualities: List<QualityOption> = emptyList(),
        val subtitles: List<SubtitleOption> = emptyList(),
    ) {
        fun toMap(): Map<String, Any> = mapOf(
            "url" to url,
            "source" to source,
            "type" to type,
            "headers" to headers,
            "referer" to (headers["Referer"] ?: ""),
            "qualities" to qualities.map(QualityOption::toMap),
            "subtitles" to subtitles.map(SubtitleOption::toMap),
        )
    }

    data class SubtitleOption(
        val label: String,
        val url: String,
        val isDefault: Boolean = false,
        val source: String = "",
    ) {
        fun toMap(): Map<String, Any> = mapOf(
            "label" to label,
            "url" to url,
            "default" to isDefault,
            "source" to source,
        )
    }

    data class QualityOption(
        val label: String,
        val url: String,
        val height: Int,
    ) {
        fun toMap(): Map<String, Any> = mapOf(
            "label" to label,
            "url" to url,
            "height" to height,
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
            CommunityServerProvider(),
            VidrockServerProvider(),
            VidzeeServerProvider(),
            PrimeSrcServerProvider(),
            FrembedServerProvider(),
        )
    }

    private val extractorRegistry: List<HostExtractor> by lazy {
        listOf(
            VidflixExtractor(),
            VidLinkExtractor(),
            MaxstreamVideoExtractor(),
            RpmExtractor(),
            VixSrcExtractor(),
            CommunityExtractor(),
            VixcloudExtractor(),
            VidsrcNetExtractor(),
            VidsrcRuExtractor(),
            VidsrcToExtractor(),
            VidrockExtractor(),
            VidzeeExtractor(),
            VideasyExtractor(),
            PrimeSrcExtractor(),
            FrembedExtractor(),
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

    suspend fun resolveStreams(
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1,
        title: String = "",
    ): List<Map<String, Any>> = withContext(Dispatchers.IO) {
        require(tmdbId.isNotBlank()) { "TMDB ID is required" }
        val media = MediaRequest(tmdbId, isMovie, season, episode, title)
        val servers = buildServerList(media)
        val extractionSlots = Semaphore(4)
        coroutineScope {
            servers.map { server ->
                async(Dispatchers.IO) {
                    extractionSlots.withPermit {
                        try {
                            extractServer(server)
                        } catch (error: Exception) {
                            Log.w(tag, "Alternative server ${server.name} failed: ${error.message}")
                            null
                        }
                    }
                }
            }.awaitAll()
                .filterNotNull()
                .distinctBy { it.url }
                .map(StreamResult::toMap)
        }
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
                Log.w(tag, "Extractor redirect loop for ${server.url}")
                return null
            }

            val extractor = extractorRegistry.firstOrNull { it.supports(server) }
            if (extractor == null) {
                Log.w(tag, "No extractor for ${server.name}: ${server.url}")
                return null
            }
            Log.d(tag, "Dispatching ${server.name} to ${extractor.name}")

            val result = try {
                extractor.extract(server)
            } catch (error: Exception) {
                Log.e(tag, "Extractor ${extractor.name} failed: ${error.message}")
                return null
            }

            when (result) {
                is ExtractionResult.Final -> {
                    return validateStream(result.stream)
                }
                is ExtractionResult.Redirect -> server = result.server
            }
        }

        Log.w(tag, "Too many extractor redirects for ${initialServer.name}")
        return null
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
                "Vidsrc",
                if (request.isMovie) {
                    "https://vidsrc-embed.ru/embed/movie?tmdb=$id"
                } else {
                    "https://vidsrc-embed.ru/embed/tv?tmdb=$id&season=${request.season}&episode=${request.episode}"
                },
            )

            servers += StreamServer(
                "VidLink",
                if (request.isMovie) {
                    "https://vidlink.pro/movie/$id"
                } else {
                    "https://vidlink.pro/tv/$id/${request.season}/${request.episode}"
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

            servers += StreamServer(
                "VidsrcRu",
                if (request.isMovie) {
                    "https://vidsrc.ru/movie/$id"
                } else {
                    "https://vidsrc.ru/tv/$id/${request.season}/${request.episode}"
                },
            )

            servers += StreamServer(
                "VidsrcTo",
                if (request.isMovie) {
                    "https://vidsrc.to/embed/movie/$id"
                } else {
                    "https://vidsrc.to/embed/tv/$id/${request.season}/${request.episode}"
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

            servers += StreamServer(
                "MaxstreamVideo",
                if (request.isMovie) {
                    "https://maxstream.video/movie/$id"
                } else {
                    "https://maxstream.video/tv/$id/${request.season}/${request.episode}"
                },
            )

            return servers
        }
    }

    private inner class CommunityServerProvider : ServerProvider {
        override val name = "Community"
        private val baseUrl = "https://streamingunity.dog"

        override suspend fun getServers(request: MediaRequest): List<StreamServer> {
            if (request.title.isBlank()) return emptyList()
            val headers = communityHeaders("$baseUrl/")
            val searchUrl = "$baseUrl/en/search?q=${encode(request.title)}&page=1&lang=en"
            val results = getJson(searchUrl, headers).optJSONArray("data") ?: return emptyList()
            val wantedType = if (request.isMovie) "movie" else "tv"
            val title = (0 until results.length()).mapNotNull { results.optJSONObject(it) }
                .firstOrNull {
                    it.optString("type").equals(wantedType, true) &&
                        normalizeTitle(it.optString("name")) == normalizeTitle(request.title)
                } ?: return emptyList()

            val titleId = title.optString("id")
            if (titleId.isBlank()) return emptyList()
            var iframeUrl = "$baseUrl/en/iframe/$titleId?language=en"
            if (!request.isMovie) {
                val slug = title.optString("slug")
                val seasonPage = httpGet(
                    "$baseUrl/en/titles/$titleId-$slug/season-${request.season}",
                    headers,
                )
                val encodedPage = Regex("""data-page=["'](.*?)["']""", RegexOption.DOT_MATCHES_ALL)
                    .find(seasonPage)?.groupValues?.get(1)
                    ?: throw IllegalStateException("Community season metadata was not found")
                val page = JSONObject(
                    Html.fromHtml(encodedPage, Html.FROM_HTML_MODE_LEGACY).toString(),
                )
                val episodes = page.optJSONObject("props")
                    ?.optJSONObject("loadedSeason")
                    ?.optJSONArray("episodes")
                    ?: return emptyList()
                val episode = (0 until episodes.length()).mapNotNull { episodes.optJSONObject(it) }
                    .firstOrNull { it.optInt("number") == request.episode }
                    ?: return emptyList()
                iframeUrl += "&episode_id=${encode(episode.optString("id"))}&next_episode=1"
            }
            return listOf(StreamServer(name, iframeUrl, headers))
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

    private inner class FrembedServerProvider : ServerProvider {
        override val name = "Frembed"
        private val baseUrl = "https://frembed.click"

        override suspend fun getServers(request: MediaRequest): List<StreamServer> {
            val url = if (request.isMovie) {
                "$baseUrl/api/films?id=${request.tmdbId}&idType=tmdb"
            } else {
                "$baseUrl/api/series?id=${request.tmdbId}&sa=${request.season}&epi=${request.episode}&idType=tmdb"
            }
            return try {
                val json = getJson(url, refererHeaders("$baseUrl/"))
                val linkFields = listOf(
                    "link1", "link2", "link3", "link4", "link5", "link6", "link7",
                    "link1vostfr", "link2vostfr", "link3vostfr", "link4vostfr",
                    "link5vostfr", "link6vostfr", "link7vostfr",
                )
                linkFields.mapNotNull { field ->
                    val path = json.optString(field).ifBlank { return@mapNotNull null }
                    val fullUrl = if (path.startsWith("/")) "$baseUrl$path" else path
                    val lang = when {
                        field.contains("vostfr") -> "VOSTFR"
                        else -> "Default"
                    }
                    StreamServer(
                        "Frembed $lang",
                        fullUrl,
                        refererHeaders("$baseUrl/"),
                    )
                }
            } catch (e: Exception) {
                Log.w(tag, "Frembed provider failed: ${e.message}")
                emptyList()
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
            val subtitles = response.optJSONArray("subtitles")?.let { items ->
                (0 until items.length()).mapNotNull { index ->
                    val item = items.optJSONObject(index) ?: return@mapNotNull null
                    val rawUrl = item.optString("url")
                    if (rawUrl.isBlank() || host(rawUrl).endsWith("opensubtitles.org")) {
                        return@mapNotNull null
                    }
                    val subtitleUrl = if (rawUrl.startsWith("http")) rawUrl
                        else resolveUrl(server.url, rawUrl)
                    SubtitleOption(
                        item.optString("label", "Subtitle"),
                        subtitleUrl,
                        item.optBoolean("default", false),
                        source = "Vidflix",
                    )
                }
            }.orEmpty()
            return ExtractionResult.Redirect(
                StreamServer("RPM video", videoUrl, subtitles = subtitles),
            )
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private inner class VidLinkExtractor : HostExtractor {
        override val name = "VidLink"
        override fun supports(server: StreamServer) = host(server.url).endsWith("vidlink.pro")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            return withContext(Dispatchers.Main) {
                withTimeout(30_000) {
                    suspendCancellableCoroutine { continuation ->
                        val webView = WebView(context)
                        webView.settings.javaScriptEnabled = true
                        webView.settings.domStorageEnabled = true

                        fun finish(result: Result<StreamResult>) {
                            if (!continuation.isActive) return
                            result.fold(
                                onSuccess = { continuation.resume(ExtractionResult.Final(it)) },
                                onFailure = { continuation.resumeWithException(it) },
                            )
                            webView.post { webView.destroy() }
                        }

                        webView.addJavascriptInterface(object {
                            @JavascriptInterface
                            fun onStreamFound(payload: String) {
                                runCatching {
                                    val stream = JSONObject(payload).getJSONObject("stream")
                                    val playlist = stream.getString("playlist")
                                    val captions = stream.optJSONArray("captions")?.let { items ->
                                        (0 until items.length()).mapNotNull { index ->
                                            val item = items.optJSONObject(index) ?: return@mapNotNull null
                                            val rawUrl = item.optString("id")
                                            if (rawUrl.isBlank()) return@mapNotNull null
                                            val captionUrl = if (rawUrl.startsWith("http")) rawUrl
                                                else resolveUrl(server.url, rawUrl)
                                            SubtitleOption(
                                                item.optString("language", "Subtitle"),
                                                captionUrl,
                                                source = "VidLink",
                                            )
                                        }
                                    }.orEmpty()
                                    StreamResult(
                                        playlist,
                                        name,
                                        "direct_m3u8",
                                        refererHeaders("https://vidlink.pro/"),
                                        subtitles = captions,
                                    )
                                }.let(::finish)
                            }
                        }, "NativeBridge")

                        webView.webViewClient = object : WebViewClient() {
                            override fun onPageFinished(view: WebView, url: String) {
                                val script = """
                                    (() => {
                                      if (window.__nativeStreamHook) return;
                                      window.__nativeStreamHook = true;
                                      const send = data => window.NativeBridge.onStreamFound(JSON.stringify(data));
                                      const originalFetch = window.fetch.bind(window);
                                      window.fetch = async (...args) => {
                                        const response = await originalFetch(...args);
                                        if (response.url.includes('/api/b/')) {
                                          response.clone().json().then(send).catch(() => {});
                                        }
                                        return response;
                                      };
                                      const resource = performance.getEntriesByType('resource')
                                        .map(entry => entry.name).find(url => url.includes('/api/b/'));
                                      if (resource) originalFetch(resource).then(r => r.json()).then(send).catch(() => {});
                                    })();
                                """.trimIndent()
                                view.evaluateJavascript(script, null)
                            }
                        }
                        webView.loadUrl(server.url)
                        continuation.invokeOnCancellation {
                            webView.post {
                                webView.stopLoading()
                                webView.destroy()
                            }
                        }
                    }
                }
            }
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private inner class MaxstreamVideoExtractor : HostExtractor {
        override val name = "MaxstreamVideo"
        override fun supports(server: StreamServer) = host(server.url).endsWith("maxstream.video")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            return withContext(Dispatchers.Main) {
                withTimeout(30_000) {
                    suspendCancellableCoroutine { continuation ->
                        val webView = WebView(context)
                        webView.settings.javaScriptEnabled = true
                        webView.settings.domStorageEnabled = true
                        webView.settings.mediaPlaybackRequiresUserGesture = false

                        fun finish(result: Result<StreamResult>) {
                            if (!continuation.isActive) return
                            result.fold(
                                onSuccess = { continuation.resume(ExtractionResult.Final(it)) },
                                onFailure = { continuation.resumeWithException(it) },
                            )
                            webView.post { webView.destroy() }
                        }

                        webView.addJavascriptInterface(object {
                            @JavascriptInterface
                            fun onStreamFound(payload: String) {
                                runCatching {
                                    val json = JSONObject(payload)
                                    val streamUrl = json.optString("url").ifBlank {
                                        json.optString("src")
                                    }
                                    require(streamUrl.isNotBlank()) { "No stream URL found" }
                                    val headers = refererHeaders("https://maxstream.video/")
                                    StreamResult(streamUrl, name, mediaType(streamUrl), headers)
                                }.let(::finish)
                            }

                            @JavascriptInterface
                            fun onSourceFound(url: String) {
                                if (url.isNotBlank()) {
                                    val headers = refererHeaders("https://maxstream.video/")
                                    finish(Result.success(StreamResult(url, name, mediaType(url), headers)))
                                }
                            }
                        }, "NativeBridge")

                        webView.webViewClient = object : WebViewClient() {
                            override fun onPageFinished(view: WebView, url: String) {
                                val script = """
                                    (() => {
                                      if (window.__maxstreamHook) return;
                                      window.__maxstreamHook = true;
                                      const send = data => window.NativeBridge.onStreamFound(JSON.stringify(data));
                                      const sendUrl = url => window.NativeBridge.onSourceFound(url);

                                      // Intercept fetch
                                      const originalFetch = window.fetch.bind(window);
                                      window.fetch = async (...args) => {
                                        const response = await originalFetch(...args);
                                        const u = response.url;
                                        if (u.includes('.m3u8') || u.includes('.mp4') || u.includes('/stream/') || u.includes('/play/')) {
                                          sendUrl(u);
                                        }
                                        return response;
                                      };

                                      // Intercept XMLHttpRequest
                                      const origOpen = XMLHttpRequest.prototype.open;
                                      XMLHttpRequest.prototype.open = function(method, url, ...rest) {
                                        this.addEventListener('load', function() {
                                          if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('/stream/') || url.includes('/play/')) {
                                            sendUrl(url);
                                          }
                                        });
                                        return origOpen.apply(this, [method, url, ...rest]);
                                      };

                                      // Check for sources in window/player
                                      const checkSources = () => {
                                        if (window.player && window.player.sources) {
                                          send({ url: window.player.sources });
                                        }
                                        if (window.video && window.video.src) {
                                          sendUrl(window.video.src);
                                        }
                                        // Look for sources in scripts
                                        document.querySelectorAll('script').forEach(s => {
                                          const text = s.textContent || '';
                                          const match = text.match(/sources\s*:\s*\[\s*\{\s*[sS]rc\s*:\s*['"]([^'"]+)/);
                                          if (match) sendUrl(match[1]);
                                          const match2 = text.match(/file\s*:\s*['"]([^'"]+\.m3u8[^'"]*)/);
                                          if (match2) sendUrl(match2[1]);
                                        });
                                      };
                                      setTimeout(checkSources, 2000);
                                      setTimeout(checkSources, 5000);
                                    })();
                                """.trimIndent()
                                view.evaluateJavascript(script, null)
                            }

                            override fun shouldInterceptRequest(
                                view: WebView?,
                                request: WebResourceRequest?,
                            ): WebResourceResponse? {
                                val url = request?.url?.toString() ?: ""
                                if (url.contains(".m3u8") || url.contains(".mp4")) {
                                    if (continuation.isActive) {
                                        continuation.resume(
                                            ExtractionResult.Final(
                                                StreamResult(url, name, mediaType(url), refererHeaders("https://maxstream.video/")),
                                            ),
                                        )
                                    }
                                }
                                return super.shouldInterceptRequest(view, request)
                            }
                        }

                        webView.loadUrl(server.url)
                        continuation.invokeOnCancellation {
                            webView.post {
                                webView.stopLoading()
                                webView.destroy()
                            }
                        }
                    }
                }
            }
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
            val cloudflareNative = json.optString("cfNative").takeIf { it.isNotBlank() }
            val directSource = json.optString("source").takeIf { it.isNotBlank() }
            val tiktokVersion = runCatching {
                JSONObject(json.optString("streamingConfig"))
                    .optJSONObject("adjust")
                    ?.optJSONObject("Tiktok")
                    ?.optJSONObject("params")
                    ?.optString("v")
                    .orEmpty()
            }.getOrDefault("")

            val candidates = buildList {
                hls?.let { add(absoluteMediaUrl(origin, it)) }
                hlsTiktok?.let {
                    add(
                        absoluteMediaUrl(origin, it) +
                            if (tiktokVersion.isBlank()) "" else "?v=${encode(tiktokVersion)}",
                    )
                }
                cloudflareNative?.let(::add)
                cloudflare?.let { add(addCloudflareToken(json, it)) }
                directSource?.let(::add)
            }.distinct()
            require(candidates.isNotEmpty()) { "RPM response contains no playback routes" }

            for (candidateUrl in candidates) {
                val candidate = StreamResult(
                    candidateUrl,
                    name,
                    mediaType(candidateUrl),
                    refererHeaders(origin),
                    subtitles = server.subtitles.distinctBy { it.url },
                )
                try {
                    return ExtractionResult.Final(validateStream(candidate))
                } catch (error: Exception) {
                    Log.w(tag, "RPM route failed: ${error.message}")
                }
            }
            throw IllegalStateException("RPM returned no playable route")
        }
    }

    private inner class VixSrcExtractor : HostExtractor {
        override val name = "VixSrc"
        override fun supports(server: StreamServer) = host(server.url).endsWith("vixsrc.to")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val headers = refererHeaders("https://vixsrc.to") + mapOf("X-Requested-With" to "XMLHttpRequest")
            var api = getJson(server.url, headers)
            var embedPath = api.optString("src").trimStart('/')
            require(embedPath.isNotBlank()) { "VixSrc returned no embed path" }
            var embedUrl = "https://vixsrc.to/$embedPath"

            var html = try {
                httpGet(embedUrl, refererHeaders("https://vixsrc.to"))
            } catch (e: Exception) {
                val isGone = e.message?.contains("410") == true || e.message?.contains("Gone") == true
                if (isGone) {
                    Log.d(tag, "VixSrc embed returned 410, retrying API for fresh path")
                    api = getJson(server.url, headers)
                    embedPath = api.optString("src").trimStart('/')
                    require(embedPath.isNotBlank()) { "VixSrc retry returned no embed path" }
                    embedUrl = "https://vixsrc.to/$embedPath"
                    httpGet(embedUrl, refererHeaders("https://vixsrc.to"))
                } else throw e
            }

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
            // ExoPlayer uses a different HTTP stack than OkHttp and won't have the cookies
            // that were set during API/embed page fetching. Forward them explicitly.
            val vixCookies = client.cookieJar.loadForRequest("https://vixsrc.to".toHttpUrl())
            val cookieHeader = vixCookies.joinToString("; ") { "${it.name}=${it.value}" }
            val responseHeaders = refererHeaders("https://vixsrc.to") +
                mapOf("Origin" to "https://vixsrc.to") +
                (if (cookieHeader.isNotBlank()) mapOf("Cookie" to cookieHeader) else emptyMap())
            validateFirstHlsSegment(streamUrl, responseHeaders)
            return ExtractionResult.Final(
                StreamResult(streamUrl, name, "direct_m3u8", responseHeaders),
            )
        }
    }

    private inner class CommunityExtractor : HostExtractor {
        override val name = "Community"

        override fun supports(server: StreamServer) = host(server.url).endsWith("streamingunity.dog")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val html = httpGet(server.url, communityHeaders("https://streamingunity.dog/"))
            val iframe = Regex(
                """<iframe[^>]+src=["']([^"']+)["']""",
                RegexOption.IGNORE_CASE,
            ).find(html)?.groupValues?.get(1)?.replace("&amp;", "&")
                ?: throw IllegalStateException("Community player iframe was not found")
            return ExtractionResult.Redirect(
                StreamServer(name, resolveUrl(server.url, iframe), mapOf("Referer" to server.url)),
            )
        }
    }

    private inner class VixcloudExtractor : HostExtractor {
        override val name = "Vixcloud"

        override fun supports(server: StreamServer) = host(server.url).endsWith("vixcloud.co")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val pageUrl = server.url.replace("&amp;", "&")
            val page = httpGet(pageUrl, refererHeaders(server.headers["Referer"] ?: "https://vixcloud.co/"))
            val videoId = Regex("""window\.video\s*=\s*\{.*?id:\s*['"]?([^,'"\s}]+)""", RegexOption.DOT_MATCHES_ALL)
                .find(page)?.groupValues?.get(1)
                ?: throw IllegalStateException("Vixcloud video ID was not found")
            val playlistSection = page.substringAfter("window.masterPlaylist", "")
            val token = Regex("""['"]?token['"]?\s*:\s*['"]([^'"]+)""")
                .find(playlistSection)?.groupValues?.get(1)
                ?: throw IllegalStateException("Vixcloud token was not found")
            val expires = Regex("""['"]?expires['"]?\s*:\s*['"]([^'"]+)""")
                .find(playlistSection)?.groupValues?.get(1)
                ?: throw IllegalStateException("Vixcloud expiry was not found")
            val origin = URI(pageUrl).let { "${it.scheme}://${it.host}" }
            val parameters = mutableListOf(
                "token=${encode(token)}",
                "expires=${encode(expires)}",
                "language=en",
            )
            if (page.contains("window.canPlayFHD = true")) parameters += "h=1"
            val streamUrl = "$origin/playlist/$videoId?${parameters.joinToString("&")}"
            return ExtractionResult.Final(
                StreamResult(streamUrl, name, "direct_m3u8", refererHeaders("$origin/")),
            )
        }
    }

    private inner class VidsrcNetExtractor : HostExtractor {
        override val name = "Vidsrc"
        override fun supports(server: StreamServer): Boolean {
            val domain = host(server.url)
            return domain.endsWith("vidsrc-embed.ru") || domain.endsWith("vsembed.ru")
        }

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val embedPage = httpGet(server.url)
            val iframePath = Regex(
                """<iframe[^>]+id=["']player_iframe["'][^>]+src=["']([^"']+)["']""",
                RegexOption.IGNORE_CASE,
            ).find(embedPage)?.groupValues?.get(1)
                ?: Regex(
                    """<iframe[^>]+src=["']([^"']+)["'][^>]+id=["']player_iframe["']""",
                    RegexOption.IGNORE_CASE,
                ).find(embedPage)?.groupValues?.get(1)
                ?: throw IllegalStateException("Vidsrc player iframe not found")
            val iframeUrl = when {
                iframePath.startsWith("//") -> "https:$iframePath"
                iframePath.startsWith("http") -> iframePath
                else -> resolveUrl(server.url, iframePath)
            }

            val iframePage = httpGet(iframeUrl, refererHeaders(server.url))
            val playerPath = Regex("""src:\s*['"](/prorcp/[^'"]+)['"]""")
                .find(iframePage)?.groupValues?.get(1)
                ?: throw IllegalStateException("Vidsrc player source not found")
            val playerUrl = iframeUrl.substringBefore("/rcp") + playerPath
            val playerPage = httpGet(playerUrl, refererHeaders(iframeUrl))

            val playerId = Regex("""Playerjs.*?file:\s*([a-zA-Z0-9]+?)\s*,""", RegexOption.DOT_MATCHES_ALL)
                .find(playerPage)?.groupValues?.get(1).orEmpty()
            val decrypted = if (playerId.isNotBlank()) {
                val encrypted = Regex(
                    """<div id=["']$playerId["'][^>]*>\s*(.*?)\s*</div>""",
                    setOf(RegexOption.DOT_MATCHES_ALL, RegexOption.IGNORE_CASE),
                ).find(playerPage)?.groupValues?.get(1)
                    ?: throw IllegalStateException("Vidsrc encrypted source not found")
                decryptVidsrc(playerId, encrypted)
            } else {
                Regex(
                    """Playerjs.*?file:\s*["']([^"']+)["']\s*,""",
                    RegexOption.DOT_MATCHES_ALL,
                ).find(playerPage)?.groupValues?.get(1)
            }

            val streamUrl = decrypted?.substringBefore(" or ")
                ?.replace(Regex("""\{[a-z]\d+\}"""), "quibblezoomfable.com")
                ?.replace("&amp;", "&")
                ?.takeIf { it.isNotBlank() }
                ?: throw IllegalStateException("Vidsrc returned no stream")

            val subtitleRegex = Regex(
                """default_subtitles\s*=\s*["']([^"']+)["']""",
                RegexOption.DOT_MATCHES_ALL,
            )
            val subtitlesRaw = subtitleRegex.find(playerPage)?.groupValues?.get(1).orEmpty()
            val subtitleBase = URI(iframeUrl)
            val subtitleOrigin = "${subtitleBase.scheme}://${subtitleBase.host}"
            val subtitles = if (subtitlesRaw.isNotBlank()) {
                subtitlesRaw.split(",").mapNotNull { item ->
                    val language = item.substringAfter("[").substringBefore("]")
                    val subPath = item.substringAfter("]")
                    if (!subPath.startsWith("/")) return@mapNotNull null
                    SubtitleOption(language, "$subtitleOrigin$subPath", source = "Vidsrc")
                }
            } else emptyList()

            return ExtractionResult.Final(
                StreamResult(streamUrl, name, mediaType(streamUrl), refererHeaders(iframeUrl), subtitles = subtitles),
            )
        }

        private fun decryptVidsrc(id: String, encrypted: String): String = when (id) {
            "NdonQLf1Tzyx7bMG" -> encrypted.chunked(3).reversed().joinToString("")
            "sXnL9MQIry" -> {
                val key = "pWB9V)[*4I`nJpp?ozyB~dbr9yt!_n4u"
                val decoded = encrypted.chunked(2).joinToString("") { it.toInt(16).toChar().toString() }
                val shifted = decoded.mapIndexed { index, character ->
                    ((character.code xor key[index % key.length].code) - 3).toChar()
                }.joinToString("")
                String(Base64.decode(shifted, Base64.DEFAULT), Charsets.UTF_8)
            }
            "IhWrImMIGL" -> {
                val rotated = rot13(encrypted.reversed()).reversed()
                String(Base64.decode(rotated, Base64.DEFAULT), Charsets.UTF_8)
            }
            "xTyBxQyGTA" -> String(
                Base64.decode(encrypted.reversed().filterIndexed { index, _ -> index % 2 == 0 }, Base64.DEFAULT),
                Charsets.UTF_8,
            )
            "ux8qjPHC66" -> {
                val key = "X9a(O;FMV2-7VO5x;Ao\u0005:dN1NoFs?j,"
                encrypted.reversed().chunked(2).mapIndexed { index, value ->
                    (value.toInt(16) xor key[index % key.length].code).toChar()
                }.joinToString("")
            }
            "eSfH1IRMyL" -> encrypted.reversed()
                .map { (it.code - 1).toChar() }
                .joinToString("")
                .chunked(2)
                .joinToString("") { it.toInt(16).toChar().toString() }
            "KJHidj7det" -> {
                val trimmed = encrypted.substring(10, encrypted.length - 16)
                val key = "3SAY~#%Y(V%>5d/Yg\"\$G[Lh1rK4a;7ok"
                val decoded = String(Base64.decode(trimmed, Base64.DEFAULT), Charsets.UTF_8)
                decoded.mapIndexed { index, character ->
                    (character.code xor key[index % key.length].code).toChar()
                }.joinToString("")
            }
            "o2VSUnjnZl" -> encrypted.map { character ->
                when (character) {
                    in 'a'..'z' -> if (character - 3 < 'a') character + 23 else character - 3
                    in 'A'..'Z' -> if (character - 3 < 'A') character + 23 else character - 3
                    else -> character
                }
            }.joinToString("")
            "Oi3v1dAlaM", "TsA2KGDGux", "JoAHUMCLXV" -> {
                val shift = when (id) {
                    "Oi3v1dAlaM" -> 5
                    "TsA2KGDGux" -> 7
                    else -> 3
                }
                val normalized = encrypted.reversed().replace('-', '+').replace('_', '/')
                String(Base64.decode(normalized, Base64.DEFAULT), Charsets.UTF_8)
                    .map { (it.code - shift).toChar() }.joinToString("")
            }
            else -> throw IllegalStateException("Unsupported Vidsrc encryption: $id")
        }
    }

    private inner class VidrockExtractor : HostExtractor {
        override val name = "Vidrock"
        override fun supports(server: StreamServer) = host(server.url).endsWith("vidrock.net")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val apiUrl = server.url.substringBefore('#')
            val selectedName = server.url.substringAfter('#', "")
            val json = getJson(apiUrl, refererHeaders("https://vidrock.net/"))
            val headers = refererHeaders("https://vidrock.net/") + mapOf("Origin" to "https://vidrock.net")

            val candidates = if (selectedName.isNotBlank()) {
                val item = json.optJSONObject(selectedName)
                if (item != null) listOf(item) else emptyList()
            } else {
                json.keys().asSequence()
                    .mapNotNull { name -> json.optJSONObject(name)?.let { name to it } }
                    .filter { it.second.optString("url").isNotBlank() }
                    .map { it.second }
                    .toList()
            }

            for (item in candidates) {
                var url = item.optString("url")
                if (url.isBlank()) continue

                val serverName = item.toString().substringBefore("://").ifBlank { server.name }
                if (selectedName.isBlank()) {
                    for (key in json.keys()) {
                        if (json.optJSONObject(key) === item) {
                            val candidateName = "$name $key"
                            try {
                                val stream = resolveVidrockUrl(url, candidateName, headers)
                                if (stream != null) return ExtractionResult.Final(stream)
                            } catch (_: Exception) { }
                            break
                        }
                    }
                } else {
                    try {
                        val stream = resolveVidrockUrl(url, "$name $selectedName", headers)
                        if (stream != null) return ExtractionResult.Final(stream)
                    } catch (_: Exception) { }
                }
            }

            throw IllegalStateException("Vidrock returned no playable source")
        }

        private suspend fun resolveVidrockUrl(url: String, label: String, headers: Map<String, String>): StreamResult? {
            var resolvedUrl = url
            if (label.contains("Atlas", ignoreCase = true)) {
                val qualities = getJsonArray(resolvedUrl, headers)
                val highest = (0 until qualities.length())
                    .mapNotNull { qualities.optJSONObject(it) }
                    .maxByOrNull { it.optInt("resolution") }
                if (highest != null) resolvedUrl = highest.optString("url", resolvedUrl)
            }
            if (resolvedUrl.isBlank()) return null
            return StreamResult(resolvedUrl, label, mediaType(resolvedUrl), headers)
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
            val headers = refererHeaders(player) + mapOf("Origin" to player)
            val links = response.optJSONArray("url") ?: throw IllegalStateException("Vidzee returned no links")
            for (index in 0 until links.length()) {
                val encrypted = links.optJSONObject(index)?.optString("link").orEmpty()
                if (encrypted.isBlank()) continue
                try {
                    val url = decryptVidzeeLink(encrypted, masterKey)
                    val stream = StreamResult(url, server.name, mediaType(url), headers)
                    return ExtractionResult.Final(validateStream(stream))
                } catch (error: Exception) {
                    Log.w(tag, "Vidzee route $index failed: ${error.message}")
                }
            }
            throw IllegalStateException("Vidzee returned no playable link")
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
            return try {
                extractFromVideasy(server)
            } catch (e: Exception) {
                Log.w(tag, "Videasy extraction failed for ${server.name}: ${e.message}")
                throw e
            }
        }

        private suspend fun extractFromVideasy(server: StreamServer): ExtractionResult {
            val encrypted = httpGet(server.url)
            val tmdbId = server.url.substringAfter("tmdbId=", "").substringBefore('&')
            val requestJson = JSONObject().put("text", encrypted).put("id", tmdbId)
            val decrypted = postJson("https://enc-dec.app/api/dec-videasy", requestJson.toString())
            val result = JSONObject(decrypted).optString("result")
            val sources = JSONObject(result).optJSONArray("sources")
                ?: throw IllegalStateException("Videasy returned no sources")
            val headers = refererHeaders("https://player.videasy.net/")
            for (index in 0 until sources.length()) {
                val source = sources.optJSONObject(index)?.optString("url").orEmpty()
                if (source.isBlank()) continue
                try {
                    val stream = StreamResult(source, server.name, mediaType(source), headers)
                    return ExtractionResult.Final(validateStream(stream))
                } catch (error: Exception) {
                    Log.w(tag, "Videasy route $index failed: ${error.message}")
                }
            }
            throw IllegalStateException("Videasy returned no playable source")
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

    private inner class FrembedExtractor : HostExtractor {
        override val name = "Frembed"
        override fun supports(server: StreamServer) = host(server.url).endsWith("frembed.click")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val response = noRedirectClient.newCall(
                Request.Builder().url(server.url)
                    .header("User-Agent", userAgent)
                    .header("Referer", "https://frembed.click/")
                    .build()
            ).execute()

            val location = response.header("Location").orEmpty()
            response.close()

            if (location.isNotBlank()) {
                val resolved = if (location.startsWith("//")) "https:$location" else location
                Log.d(tag, "Frembed redirect: ${server.url} -> $resolved")
                return ExtractionResult.Redirect(
                    StreamServer(server.name, resolved, refererHeaders("https://frembed.click/")),
                )
            }

            val pageHtml = httpGet(server.url, refererHeaders("https://frembed.click/"))
            val mediaUrl = Regex(
                """https?://[^\s"'<>]+\.(?:m3u8|mp4)(?:[^\s"'<>]*)?""",
                RegexOption.IGNORE_CASE,
            ).find(pageHtml)?.value
                ?.replace("\\/", "/")?.replace("&amp;", "&")
                ?: throw IllegalStateException("Frembed returned no media URL")

            return ExtractionResult.Final(
                StreamResult(mediaUrl, name, mediaType(mediaUrl), refererHeaders("https://frembed.click/")),
            )
        }
    }

    private inner class VidsrcRuExtractor : HostExtractor {
        override val name = "VidsrcRu"
        override fun supports(server: StreamServer) = host(server.url).endsWith("vidsrc.ru")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            return withContext(Dispatchers.Main) {
                withTimeout(30_000) {
                    suspendCancellableCoroutine { continuation ->
                        val webView = WebView(context)
                        webView.settings.javaScriptEnabled = true
                        webView.settings.domStorageEnabled = true

                        webView.webViewClient = object : WebViewClient() {
                            override fun shouldInterceptRequest(
                                view: WebView?,
                                request: WebResourceRequest?,
                            ): WebResourceResponse? {
                                val url = request?.url?.toString() ?: ""
                                if (url.contains("/file2/") && url.endsWith(".m3u8")) {
                                    if (continuation.isActive) {
                                        continuation.resume(
                                            ExtractionResult.Final(
                                                StreamResult(url, name, "direct_m3u8", refererHeaders(server.url)),
                                            ),
                                        )
                                    }
                                }
                                return super.shouldInterceptRequest(view, request)
                            }
                        }
                        webView.loadUrl(server.url)
                        continuation.invokeOnCancellation {
                            webView.post {
                                webView.stopLoading()
                                webView.destroy()
                            }
                        }
                    }
                }
            }
        }
    }

    private inner class VidsrcToExtractor : HostExtractor {
        override val name = "VidsrcTo"
        override fun supports(server: StreamServer) = host(server.url).endsWith("vidsrc.to")

        override suspend fun extract(server: StreamServer): ExtractionResult {
            val html = httpGet(server.url)
            val mediaId = Regex("""data-id=["']([^"']+)["']""")
                .find(html)?.groupValues?.get(1)
                ?: throw IllegalStateException("VidsrcTo media ID not found")

            val keysUrl = "https://raw.githubusercontent.com/Ciarands/vidsrc-keys/main/keys.json"
            val keysJson = getJson(keysUrl)
            val decryptKey = keysJson.getJSONArray("decrypt").getString(0)

            val sourcesUrl = "https://vidsrc.to/ajax/embed/episode/$mediaId/sources"
            val sourcesJson = getJson(sourcesUrl)
            val sources = sourcesJson.optJSONArray("result")
                ?: throw IllegalStateException("VidsrcTo no sources")

            for (i in 0 until sources.length()) {
                val source = sources.optJSONObject(i) ?: continue
                val sourceId = source.optString("id")
                if (sourceId.isBlank()) continue

                val embedUrl = "https://vidsrc.to/ajax/embed/source/$sourceId"
                val embedJson = getJson(embedUrl)
                val encUrl = embedJson.optJSONObject("result")?.optString("url").orEmpty()
                if (encUrl.isBlank()) continue

                val decryptedUrl = decryptRc4(decryptKey, encUrl)
                if (decryptedUrl.isNotBlank() && decryptedUrl != encUrl) {
                    return ExtractionResult.Redirect(
                        StreamServer(name, decryptedUrl, server.headers),
                    )
                }
            }
            throw IllegalStateException("VidsrcTo returned no playable source")
        }

        private fun decryptRc4(key: String, encUrl: String): String {
            val keyBytes = key.toByteArray(Charsets.UTF_8)
            val s = IntArray(256) { it }
            var j = 0
            for (i in 0 until 256) {
                j = (j + s[i] + keyBytes[i % keyBytes.size].toInt()) and 0xff
                s[i] = s[j].also { s[j] = s[i] }
            }
            var data = Base64.decode(encUrl, Base64.URL_SAFE)
            val result = ByteArray(data.size)
            var ci = 0; var ck = 0
            for (index in data.indices) {
                ci = (ci + 1) and 0xff
                ck = (ck + s[ci]) and 0xff
                s[ci] = s[ck].also { s[ck] = s[ci] }
                val t = (s[ci] + s[ck]) and 0xff
                result[index] = (data[index].toInt() xor s[t]).toByte()
            }
            return java.net.URLDecoder.decode(String(result, Charsets.UTF_8), "utf-8")
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

    private suspend fun validateStream(stream: StreamResult): StreamResult {
        if (stream.type != "direct_m3u8" && !stream.url.contains(".m3u8", true)) {
            validateMediaRequest(stream.url, stream.headers)
            return stream
        }

        val validation = validateHls(stream.url, stream.headers)
        return stream.copy(
            url = validation.playbackUrl,
            qualities = validation.qualities,
            subtitles = (stream.subtitles + validation.subtitles).distinctBy { it.url },
        )
    }

    private data class HlsValidation(
        val playbackUrl: String,
        val qualities: List<QualityOption>,
        val subtitles: List<SubtitleOption>,
    )

    private data class HlsVariant(val url: String, val height: Int)

    private suspend fun validateHls(url: String, headers: Map<String, String>): HlsValidation {
        val master = getValidationResponse(url, headers)
        require(master.body.startsWith("#EXTM3U")) {
            "HLS endpoint did not return a playlist (${master.contentType})"
        }

        val variants = parseHlsVariants(master.url, master.body)
        val subtitles = parseHlsSubtitles(master.url, master.body)
        if (variants.isEmpty()) {
            validateMediaPlaylist(master.url, master.body, headers)
            return HlsValidation(master.url, emptyList(), subtitles)
        }

        // Validate all variants in parallel — skip per-variant segment checks
        val playableVariants = coroutineScope {
            variants.map { variant ->
                async(Dispatchers.IO) {
                    try {
                        val playlist = getValidationResponse(variant.url, headers)
                        require(playlist.body.startsWith("#EXTM3U")) {
                            "Variant ${variant.height}p is not a valid playlist"
                        }
                        variant.copy(url = playlist.url)
                    } catch (error: Exception) {
                        Log.w(tag, "Discarding ${variant.height}p HLS variant: ${error.message}")
                        null
                    }
                }
            }.awaitAll().filterNotNull()
        }.distinctBy { it.height }.sortedByDescending { it.height }

        require(playableVariants.isNotEmpty()) { "No playable HLS quality variants" }
        val allVariantsPlayable = playableVariants.size == variants.distinctBy { it.height }.size
        val playbackUrl = if (allVariantsPlayable) master.url else playableVariants.first().url
        val qualities = buildList {
            if (allVariantsPlayable && playableVariants.size > 1) {
                add(QualityOption("Auto", master.url, 0))
            }
            addAll(playableVariants.map { QualityOption("${it.height}p", it.url, it.height) })
        }
        return HlsValidation(playbackUrl, qualities, subtitles)
    }

    private fun validateMediaPlaylist(
        playlistUrl: String,
        body: String,
        headers: Map<String, String>,
    ) {
        require(body.startsWith("#EXTM3U")) { "HLS quality did not return a playlist" }
        val mediaUri = body.lineSequence()
            .map(String::trim)
            .firstOrNull { it.isNotEmpty() && !it.startsWith('#') }
            ?: throw IllegalStateException("HLS quality contains no media URI")
        validateMediaRequest(resolveUrl(playlistUrl, mediaUri), headers)
    }

    private fun validateFirstHlsSegment(url: String, headers: Map<String, String>) {
        val master = getValidationResponse(url, headers)
        require(master.body.startsWith("#EXTM3U")) { "HLS endpoint did not return a playlist" }
        val firstVariant = parseHlsVariants(master.url, master.body).firstOrNull()
        if (firstVariant == null) {
            validateMediaPlaylist(master.url, master.body, headers)
            return
        }
        val media = getValidationResponse(firstVariant.url, headers)
        validateMediaPlaylist(media.url, media.body, headers)
    }

    private fun parseHlsVariants(masterUrl: String, body: String): List<HlsVariant> {
        val lines = body.lineSequence().map(String::trim).toList()
        return lines.mapIndexedNotNull { index, line ->
            if (!line.startsWith("#EXT-X-STREAM-INF", true)) return@mapIndexedNotNull null
            val height = Regex("""RESOLUTION=\d+x(\d+)""", RegexOption.IGNORE_CASE)
                .find(line)?.groupValues?.getOrNull(1)?.toIntOrNull() ?: return@mapIndexedNotNull null
            val uri = lines.drop(index + 1).firstOrNull { it.isNotEmpty() && !it.startsWith('#') }
                ?: return@mapIndexedNotNull null
            HlsVariant(resolveUrl(masterUrl, uri), height)
        }
    }

    private fun parseHlsSubtitles(masterUrl: String, body: String): List<SubtitleOption> {
        fun attribute(line: String, name: String): String? {
            val match = Regex("""(?:^|,)$name=(?:"([^"]*)"|([^,]*))""", RegexOption.IGNORE_CASE)
                .find(line) ?: return null
            return match.groupValues[1].ifBlank { match.groupValues[2] }.ifBlank { null }
        }

        return body.lineSequence().mapNotNull { line ->
            if (!line.startsWith("#EXT-X-MEDIA", true) ||
                !line.contains("TYPE=SUBTITLES", true)) return@mapNotNull null
            val uri = attribute(line, "URI") ?: return@mapNotNull null
            val label = attribute(line, "NAME") ?: attribute(line, "LANGUAGE") ?: "Subtitle"
            SubtitleOption(
                label,
                resolveUrl(masterUrl, uri),
                attribute(line, "DEFAULT").equals("YES", true),
                source = "HLS",
            )
        }.distinctBy { it.url }.toList()
    }

    private data class ValidationResponse(
        val url: String,
        val body: String,
        val contentType: String,
    )

    private fun getValidationResponse(url: String, headers: Map<String, String>): ValidationResponse {
        val request = Request.Builder().url(url).apply {
            header("User-Agent", userAgent)
            headers.forEach { (name, value) -> header(name, value) }
        }.build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            require(response.isSuccessful) { "HTTP ${response.code} while validating $url" }
            return ValidationResponse(
                response.request.url.toString(),
                body,
                response.header("Content-Type").orEmpty(),
            )
        }
    }

    private fun validateMediaRequest(url: String, headers: Map<String, String>) {
        val request = Request.Builder().url(url).apply {
            header("User-Agent", userAgent)
            header("Range", "bytes=0-1023")
            headers.forEach { (name, value) -> header(name, value) }
        }.build()
        client.newCall(request).execute().use { response ->
            require(response.isSuccessful) { "HTTP ${response.code} while validating media data" }
            require((response.body?.contentLength() ?: 0L) != 0L) { "Media response was empty" }
        }
    }

    private fun refererHeaders(referer: String) = mapOf(
        "Referer" to referer,
        "User-Agent" to userAgent,
    )

    private fun communityHeaders(referer: String) = refererHeaders(referer) + mapOf(
        "Accept-Language" to "en-US,en;q=0.9",
        "Cookie" to "language=en",
        "X-Requested-With" to "XMLHttpRequest",
    )

    private fun normalizeTitle(value: String) = value.lowercase().filter(Char::isLetterOrDigit)

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
