package com.maxstream.app.ui.screens.player

import android.content.ComponentCallbacks2
import android.content.Context
import android.view.KeyEvent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.Player
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import androidx.navigation.NavController
import com.maxstream.app.data.local.WatchProgressRepository
import com.maxstream.app.data.model.Quality
import com.maxstream.app.data.model.Source
import com.maxstream.app.data.model.Subtitle
import com.maxstream.app.di.Modules
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.util.concurrent.TimeUnit
import kotlin.math.abs

/** Server/quality/subtitle selection panel currently open (null = closed). */
private enum class PlayerMenu { Servers, Quality, Subtitles }

/** A subtitle option unioned across all discovered servers, tagged with its owner. */
private data class SubtitleOption(
    val label: String,
    val url: String,
    val mimeType: String,
    val owner: String,
    val headers: Map<String, String>,
)

@Composable
fun PlayerScreen(
    navController: NavController,
    itemId: String,
    mediaType: String,
    season: Int,
    episode: Int,
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val isMovie = mediaType == "movie"

    var source by remember { mutableStateOf<Source?>(null) }
    var allServers by remember { mutableStateOf<List<Source>>(emptyList()) }
    var exoPlayer by remember { mutableStateOf<ExoPlayer?>(null) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var status by remember { mutableStateOf("") }
    var menuOpen by remember { mutableStateOf(false) }
    var activeMenu by remember { mutableStateOf<PlayerMenu?>(null) }
    var menuIndex by remember { mutableStateOf(0) }
    var selectedQualityLabel by remember { mutableStateOf("Auto") }
    var selectedSubtitleLabel by remember { mutableStateOf("Off") }
    var resumePositionMs by remember { mutableStateOf(0L) }
    // True after a memory-pressure release so the recovery effect rebuilds the
    // player (distinct from the initial load, which must not double-resolve).
    var memoryReleased by remember { mutableStateOf(false) }
    var title by remember { mutableStateOf("") }
    var posterPath by remember { mutableStateOf("") }
    var backdropPath by remember { mutableStateOf("") }

    // Current subtitle options across every server (grouped + own headers).
    var subtitleOptions by remember { mutableStateOf<List<SubtitleOption>>(emptyList()) }
    // The active subtitle config attached to the playing item (null = off).
    var activeSubtitle by remember { mutableStateOf<SubtitleOption?>(null) }

    // Generation guard so stale async rebuilds never touch a disposed player.
    val rebuildGeneration = remember { mutableStateOf(0) }

    /** Saves current playback progress (position + title metadata). */
    fun saveProgress() {
        val player = exoPlayer ?: return
        val positionMs = player.currentPosition
        val durationMs = player.duration
        if (positionMs <= 0 || durationMs <= 0) return
        WatchProgressRepository.saveProgress(
            context = context,
            tmdbId = itemId,
            title = title.ifBlank { itemId },
            isMovie = isMovie,
            season = season,
            episode = episode,
            positionSeconds = positionMs / 1000,
            durationSeconds = durationMs / 1000,
            posterPath = posterPath,
            backdropPath = backdropPath,
        )
    }

    fun qualityLabelFor(s: Source): String {
        if (s.separateAudio) return "Auto"
        val currentUrl = s.url
        return s.qualities.firstOrNull { it.url == currentUrl }?.label ?: "Auto"
    }

    fun subtitleMimeType(url: String): String = when {
        url.contains(".vtt", true) -> MimeTypes.TEXT_VTT
        url.contains(".srt", true) -> MimeTypes.APPLICATION_SUBRIP
        url.contains(".ssa", true) || url.contains(".ass", true) -> MimeTypes.TEXT_SSA
        url.contains(".m3u8", true) -> MimeTypes.APPLICATION_M3U8
        else -> MimeTypes.TEXT_VTT
    }

    fun qualityOptions(s: Source?): List<Quality> {
        val q = s?.qualities ?: return emptyList()
        return listOf(Quality(label = "Auto", url = "", height = 0)) + q
    }

    /**
     * Builds a fresh player for [media] and swaps it in. Used for initial load,
     * server switches, quality switches and subtitle changes - a full rebuild is
     * the most reliable path on TV firmware (mirrors the Dart player, which
     * abandoned in-place re-queuing after it silently failed on some boxes).
     */
    fun buildPlayer(
        url: String,
        headers: Map<String, String>,
        isHls: Boolean,
        subtitle: SubtitleOption?,
        startMs: Long,
    ): ExoPlayer {
        val httpClient = OkHttpClient.Builder()
            .connectTimeout(12, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .followRedirects(true)
            .followSslRedirects(true)
            .build()
        val dataSourceFactory = OkHttpDataSource.Factory(httpClient)
            .setDefaultRequestProperties(headers)

        val itemBuilder = MediaItem.Builder()
            .setMediaId(url)
            .setUri(url)
        if (isHls) {
            // The HLS format hint: without an explicit mime type the media source
            // factory treats tokenized playlists (no .m3u8 in the path, e.g.
            // VixSrc's /playlist/...) as progressive media and fails with a
            // source error.
            itemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
        }
        if (subtitle != null) {
            itemBuilder.setSubtitleConfigurations(
                listOf(
                    MediaItem.SubtitleConfiguration.Builder(android.net.Uri.parse(subtitle.url))
                        .setMimeType(subtitle.mimeType)
                        .setLabel(subtitle.label)
                        .build(),
                ),
            )
        }

        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)

        val player = ExoPlayer.Builder(context, renderersFactory)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSourceFactory))
            .setLoadControl(
                DefaultLoadControl.Builder()
                    .setBufferDurationsMs(
                        DefaultLoadControl.DEFAULT_MIN_BUFFER_MS,
                        300_000,
                        DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS,
                        DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS,
                    )
                    .build(),
            )
            .build()
        player.setMediaItem(itemBuilder.build(), startMs)
        player.prepare()
        player.playWhenReady = true
        return player
    }

    /** Resolves an HLS subtitle playlist (m3u8 of .vtt segments) to a local VTT file. */
    suspend fun resolveHlsSubtitlePlaylist(
        playlistUrl: String,
        headers: Map<String, String>,
    ): String? = withContext(Dispatchers.IO) {
        try {
            val client = OkHttpClient.Builder()
                .connectTimeout(8, TimeUnit.SECONDS)
                .readTimeout(10, TimeUnit.SECONDS)
                .build()
            val request = Request.Builder()
                .url(playlistUrl)
                .apply {
                    headers.forEach { (k, v) -> addHeader(k, v) }
                }
                .build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@withContext null
                val body = response.body?.string() ?: return@withContext null
                val baseUri = java.net.URI(playlistUrl)
                val segments = body.lineSequence()
                    .map(String::trim)
                    .filter { it.isNotEmpty() && !it.startsWith('#') }
                    .toList()
                if (segments.isEmpty()) return@withContext null
                val parts = mutableListOf<String>()
                for (segment in segments) {
                    val segUrl = baseUri.resolve(segment).toString()
                    val segReq = Request.Builder().url(segUrl).apply {
                        headers.forEach { (k, v) -> addHeader(k, v) }
                    }.build()
                    client.newCall(segReq).execute().use { seg ->
                        if (seg.isSuccessful) {
                            parts.add(seg.body?.string().orEmpty())
                        }
                    }
                }
                if (parts.isEmpty()) return@withContext null
                val vtt = parts.joinToString("\n")
                val file = File(
                    context.cacheDir,
                    "subtitle_${abs(playlistUrl.hashCode())}.vtt",
                )
                file.writeText(vtt)
                file.absolutePath
            }
        } catch (e: Exception) {
            null
        }
    }

    /** Builds the per-server subtitle option list (current server first). */
    fun buildSubtitleOptions(current: Source, servers: List<Source>): List<SubtitleOption> {
        val ordered = listOf(current) + servers.filter { it.url != current.url }
        val seen = mutableSetOf<String>()
        val result = mutableListOf<SubtitleOption>()
        for (server in ordered) {
            for (sub in server.subtitles) {
                if (sub.url.isBlank() || !seen.add(sub.url)) continue
                result.add(
                    SubtitleOption(
                        label = "${server.displayName} · ${sub.label}",
                        url = sub.url,
                        mimeType = subtitleMimeType(sub.url),
                        owner = server.displayName,
                        headers = server.headers,
                    ),
                )
            }
        }
        return result
    }

    /** Rebuilds the player with a new MediaItem while preserving the position. */
    fun switchMedia(
        newUrl: String,
        newHeaders: Map<String, String>,
        newIsHls: Boolean,
        newSubtitle: SubtitleOption?,
    ) {
        val old = exoPlayer
        val positionMs = if (old != null && old.playbackState != Player.STATE_IDLE) {
            old.currentPosition
        } else {
            resumePositionMs
        }
        old?.release()
        val gen = ++rebuildGeneration.value
        loading = true
        status = "Switching..."
        coroutineScope.launch {
            var sub: SubtitleOption? = newSubtitle
            // HLS subtitle playlists must be resolved to a local VTT before the
            // player can consume them.
            if (sub != null && sub.url.contains(".m3u8", true)) {
                val local = resolveHlsSubtitlePlaylist(sub.url, sub.headers)
                if (local != null) {
                    sub = sub.copy(url = "file://$local", mimeType = MimeTypes.TEXT_VTT)
                }
            }
            if (gen != rebuildGeneration.value) return@launch
            val player = buildPlayer(newUrl, newHeaders, newIsHls, sub, positionMs)
            if (gen != rebuildGeneration.value) {
                player.release()
                return@launch
            }
            exoPlayer?.release()
            exoPlayer = player
            loading = false
            status = ""
            selectedSubtitleLabel = sub?.label ?: "Off"
        }
    }

    /** Resolves the initial stream, remembers the resume position, and starts playback. */
    suspend fun loadAndPlay() {
        loading = true
        error = null
        try {
            // Fetch metadata so Continue Watching entries carry a title + poster.
            val id = itemId.toIntOrNull()
            if (id != null) {
                try {
                    val details = if (isMovie) {
                        Modules.catalogRepository.movieDetails(id)
                    } else {
                        Modules.catalogRepository.seriesDetails(id)
                    }
                    title = details.optString("title").ifBlank { details.optString("name") }
                    posterPath = details.optString("poster_path")
                    backdropPath = details.optString("backdrop_path")
                } catch (_: Exception) {
                }
            }

            // Resume position from watch history.
            resumePositionMs = WatchProgressRepository.loadPosition(
                context, itemId, isMovie, season, episode,
            ) * 1000

            // Primary stream for this title/episode. This is a parallel race
            // across all servers, so the first playable one arrives fast (a
            // single dead server can no longer stall the whole chain).
            val primary = Modules.streamRepository(context).resolve(
                tmdbId = itemId,
                isMovie = isMovie,
                season = season,
                episode = episode,
                title = title,
            )
            if (primary == null) {
                error = "No stream found"
                loading = false
                return
            }

            // Start with just the primary server so playback begins immediately.
            source = primary
            allServers = listOf(primary)
            subtitleOptions = buildSubtitleOptions(primary, listOf(primary))

            // Default subtitle from the primary server (isDefault, else first).
            var defaultSub: SubtitleOption? = null
            val primDefaults = primary.subtitles
            if (primDefaults.isNotEmpty()) {
                val def = primDefaults.firstOrNull { it.isDefault } ?: primDefaults.first()
                defaultSub = subtitleOptions.firstOrNull { it.url == def.url }
            }

            selectedQualityLabel = qualityLabelFor(primary)
            // HLS subtitle playlists must be resolved to a local VTT first
            // (same path as switchMedia) so the player can consume them.
            var initialSub = defaultSub
            if (initialSub != null && initialSub.url.contains(".m3u8", true)) {
                initialSub = resolveHlsSubtitlePlaylist(initialSub.url, initialSub.headers)
                    ?.let { local ->
                        initialSub.copy(url = "file://$local", mimeType = MimeTypes.TEXT_VTT)
                    }
            }
            val player = buildPlayer(
                url = primary.url,
                headers = primary.headers,
                isHls = primary.isHls,
                subtitle = initialSub,
                startMs = resumePositionMs,
            )
            exoPlayer?.release()
            exoPlayer = player
            activeSubtitle = initialSub
            selectedSubtitleLabel = initialSub?.label ?: "Off"
            loading = false

            // Populate the server picker + cross-server subtitle fallback in the
            // background so it never blocks the first frame of playback.
            coroutineScope.launch {
                val servers = Modules.streamRepository(context).resolveAll(
                    tmdbId = itemId,
                    isMovie = isMovie,
                    season = season,
                    episode = episode,
                    title = title,
                )
                if (servers.isNotEmpty()) {
                    allServers = servers
                    subtitleOptions = buildSubtitleOptions(primary, servers)
                }
            }
        } catch (e: Exception) {
            error = e.message ?: "Failed to load stream"
            loading = false
        }
    }

    // ------------------------------------------------------------------
    // Effects
    // ------------------------------------------------------------------

    LaunchedEffect(itemId, mediaType, season, episode) {
        loadAndPlay()
    }

    // Periodic progress save while the current player instance is alive.
    LaunchedEffect(exoPlayer) {
        val player = exoPlayer ?: return@LaunchedEffect
        while (player === exoPlayer) {
            delay(25_000)
            if (player === exoPlayer) saveProgress()
        }
    }

    // Release the player and persist progress when leaving the screen.
    DisposableEffect(Unit) {
        onDispose {
            saveProgress()
            exoPlayer?.release()
            exoPlayer = null
        }
    }

    // Memory pressure: on critical trims, release the player (and let the
    // resume path rebuild it) so the Low-Memory Killer never SIGKILLs the app
    // mid-playback on 1GB TV boxes.
    DisposableEffect(Unit) {
        val callbacks = object : ComponentCallbacks2 {
            override fun onTrimMemory(level: Int) {
                if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL) {
                    saveProgress()
                    exoPlayer?.release()
                    exoPlayer = null
                    memoryReleased = true
                    loading = true
                    status = "Resuming..."
                }
            }

            override fun onLowMemory() {
                saveProgress()
                exoPlayer?.release()
                exoPlayer = null
                memoryReleased = true
                loading = true
                status = "Resuming..."
            }

            @Deprecated("Deprecated in Java")
            override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
            }
        }
        context.registerComponentCallbacks(callbacks)
        onDispose { context.unregisterComponentCallbacks(callbacks) }
    }

    // Rebuild the player after a memory-pressure release (and only then -
    // the initial load is driven by the itemId LaunchedEffect).
    LaunchedEffect(loading, exoPlayer) {
        if (loading && exoPlayer == null && error == null && memoryReleased) {
            memoryReleased = false
            val current = source
            if (current != null) {
                switchMedia(current.url, current.headers, current.isHls, activeSubtitle)
            } else {
                loadAndPlay()
            }
        }
    }

    // ------------------------------------------------------------------
    // D-pad / remote handling
    // ------------------------------------------------------------------

    fun selectMenuOption(s: Source?) {
        val menu = activeMenu ?: return
        when (menu) {
            PlayerMenu.Servers -> {
                val servers = allServers
                if (servers.isEmpty() || menuIndex >= servers.size) return
                val target = servers[menuIndex]
                if (target.url == s?.url) {
                    menuOpen = false
                    activeMenu = null
                    return
                }
                // Switching servers: rebuild with the target's own headers/URL,
                // reset subtitle selection, keep the position.
                subtitleOptions = buildSubtitleOptions(target, allServers)
                activeSubtitle = null
                selectedSubtitleLabel = "Off"
                selectedQualityLabel = qualityLabelFor(target)
                source = target
                switchMedia(target.url, target.headers, target.isHls, null)
                menuOpen = false
                activeMenu = null
            }
            PlayerMenu.Quality -> {
                val opts = qualityOptions(s)
                if (opts.isEmpty() || menuIndex >= opts.size) return
                val q = opts[menuIndex]
                menuOpen = false
                activeMenu = null
                if (s == null) return
                if (s.separateAudio) {
                    // Separate-audio masters (VixSrc) carry audio in #EXT-X-MEDIA
                    // groups; their variants are video-only and would play
                    // silently. Keep the master URL and only update the label
                    // (mirrors the Dart fix).
                    selectedQualityLabel = q.label
                    status = "Switched to ${q.label}"
                    return
                }
                if (q.url.isBlank()) {
                    selectedQualityLabel = "Auto"
                    switchMedia(s.url, s.headers, s.isHls, activeSubtitle)
                    return
                }
                selectedQualityLabel = q.label
                switchMedia(q.url, s.headers, s.isHls, activeSubtitle)
            }
            PlayerMenu.Subtitles -> {
                // Index 0 = Off.
                if (menuIndex == 0) {
                    activeSubtitle = null
                    selectedSubtitleLabel = "Off"
                    menuOpen = false
                    activeMenu = null
                    s?.let { switchMedia(it.url, it.headers, it.isHls, null) }
                    return
                }
                val opts = subtitleOptions
                if (opts.isEmpty() || menuIndex - 1 >= opts.size) return
                val target = opts[menuIndex - 1]
                activeSubtitle = target
                menuOpen = false
                activeMenu = null
                s?.let { switchMedia(it.url, it.headers, it.isHls, target) }
            }
        }
    }

    fun onKeyDown(key: Key): Boolean {
        when (key) {
            Key.DirectionUp -> {
                if (menuOpen) {
                    menuIndex = if (menuIndex > 0) menuIndex - 1 else menuIndex
                    return true
                }
            }
            Key.DirectionDown -> {
                if (menuOpen) {
                    val count = when (activeMenu) {
                        PlayerMenu.Servers -> allServers.size
                        PlayerMenu.Quality -> qualityOptions(source).size
                        PlayerMenu.Subtitles -> subtitleOptions.size + 1
                        null -> 0
                    }
                    if (menuIndex + 1 < count) menuIndex++
                    return true
                }
            }
            Key.DirectionCenter, Key.Enter -> {
                if (menuOpen) {
                    selectMenuOption(source)
                    return true
                }
            }
            Key.Back, Key.Escape -> {
                if (menuOpen) {
                    menuOpen = false
                    activeMenu = null
                    menuIndex = 0
                } else {
                    saveProgress()
                    navController.popBackStack()
                }
                return true
            }
            else -> return false
        }
        return false
    }

    // ------------------------------------------------------------------
    // UI
    // ------------------------------------------------------------------

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .onPreviewKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown) {
                    onKeyDown(event.key)
                } else {
                    false
                }
            },
    ) {
        if (exoPlayer != null) {
            AndroidView(
                factory = { ctx ->
                    PlayerView(ctx).also { view ->
                        view.player = exoPlayer
                        view.useController = true
                        view.controllerAutoShow = true
                    }
                },
                update = { view ->
                    view.player = exoPlayer
                },
                modifier = Modifier.fillMaxSize(),
            )
        }

        if (loading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xCC000000)),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator(color = Color(0xFFE50914))
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = status.ifBlank { "Loading stream..." },
                        color = Color.White,
                        fontSize = 16.sp,
                    )
                }
            }
        }

        if (error != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xCC000000)),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(text = "Error: $error", color = Color(0xFFCF6679), fontSize = 18.sp)
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(
                            onClick = {
                                error = null
                                loading = true
                                coroutineScope.launch { loadAndPlay() }
                            },
                        ) { Text("Retry") }
                        TextButton(onClick = { navController.popBackStack() }) { Text("Back") }
                    }
                }
            }
        }

        // Top-left: title + current server.
        if (!loading && error == null) {
            Row(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = source?.displayName ?: "",
                    color = Color.White,
                    fontSize = 14.sp,
                    modifier = Modifier
                        .background(Color(0x99000000))
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
        }

        // Menu buttons row (top-right) — matches Dart's server/quality/subtitle buttons
        if (!loading && error == null && !menuOpen) {
            Row(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (!isMovie) {
                    PlayerTopButton(label = "Episodes") {
                        menuOpen = true
                        activeMenu = PlayerMenu.Servers // reuse for episodes in future
                        menuIndex = 0
                    }
                }
                PlayerTopButton(label = "Subtitles [${if (selectedSubtitleLabel == "Off") "Off" else "On"}]") {
                    menuOpen = true
                    activeMenu = PlayerMenu.Subtitles
                    menuIndex = 0
                }
                PlayerTopButton(label = "Quality [$selectedQualityLabel]") {
                    menuOpen = true
                    activeMenu = PlayerMenu.Quality
                    menuIndex = 0
                }
                PlayerTopButton(label = "Servers") {
                    menuOpen = true
                    activeMenu = PlayerMenu.Servers
                    menuIndex = 0
                }
            }
        }

        // Selection panel.
        if (menuOpen) {
            MenuPanel(
                activeMenu = activeMenu,
                menuIndex = menuIndex,
                servers = allServers,
                currentServerUrl = source?.url,
                qualities = qualityOptions(source),
                currentQualityLabel = selectedQualityLabel,
                subtitles = subtitleOptions,
                currentSubtitleLabel = selectedSubtitleLabel,
                onSelect = { menuOpen = false; activeMenu = null },
                modifier = Modifier.align(Alignment.CenterEnd),
            )
        }
    }
}

@Composable
private fun PlayerTopButton(label: String, onClick: () -> Unit) {
    var isFocused by remember { androidx.compose.runtime.mutableStateOf(false) }
    Box(
        modifier = Modifier
            .background(
                if (isFocused) Color(0xFFE50914) else Color(0xCC000000),
                androidx.compose.foundation.shape.RoundedCornerShape(6.dp),
            )
            .focusable()
            .onFocusChanged { isFocused = it.hasFocus }
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        Text(text = label, color = Color.White, fontSize = 13.sp)
    }
}

@Composable
private fun MenuPanel(
    activeMenu: PlayerMenu?,
    menuIndex: Int,
    servers: List<Source>,
    currentServerUrl: String?,
    qualities: List<Quality>,
    currentQualityLabel: String,
    subtitles: List<SubtitleOption>,
    currentSubtitleLabel: String,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val items: List<Pair<String, Boolean>> = when (activeMenu) {
        PlayerMenu.Servers -> servers.map { it.displayName to (it.url == currentServerUrl) }
        PlayerMenu.Quality -> qualities.map { it.label to (it.label == currentQualityLabel) }
        PlayerMenu.Subtitles ->
            listOf("Off" to (currentSubtitleLabel == "Off")) +
                subtitles.map { it.label to (it.label == currentSubtitleLabel) }
        null -> emptyList()
    }

    Column(
        modifier = modifier
            .padding(16.dp)
            .background(Color(0xF0111111))
            .padding(vertical = 8.dp),
    ) {
        Text(
            text = when (activeMenu) {
                PlayerMenu.Servers -> "Servers"
                PlayerMenu.Quality -> "Quality"
                PlayerMenu.Subtitles -> "Subtitles"
                null -> ""
            },
            color = Color(0xFFB3B3B3),
            fontSize = 12.sp,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
        )
        items.forEachIndexed { index, (label, isSelected) ->
            val focused = index == menuIndex
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        when {
                            focused -> Color(0xFFE50914)
                            isSelected -> Color(0x33FFFFFF)
                            else -> Color.Transparent
                        },
                    )
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = if (isSelected) "● " else "  ",
                    color = Color.White,
                    fontSize = 14.sp,
                )
                Text(
                    text = label,
                    color = Color.White,
                    fontSize = 14.sp,
                    maxLines = 1,
                )
            }
        }
    }
}
