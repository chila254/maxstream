package com.maxstream.app.ui.screens.player

import android.app.Activity
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.ContextWrapper
import android.view.KeyEvent
import android.view.WindowManager
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.Image
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.res.painterResource
import com.maxstream.app.R
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
import com.maxstream.app.data.remote.EpisodeRef
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

/** Server/quality/subtitle/season selection panel currently open (null = closed). */
private enum class PlayerMenu { Servers, Quality, Subtitles, Episodes }

/** A season tab inside the episode picker. */
private data class SeasonInfo(
    val number: Int,
    val name: String,
    val episodeCount: Int,
)

/** A top-right menu button (Episodes/Subtitles/Quality/Servers). */
private data class TopMenuButton(
    val index: Int,
    val label: String,
    val subLabel: String = "",
    val onClick: () -> Unit,
)

/** Walks up the context chain to the hosting Activity (for the keep-screen-on flag). */
private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

/** A subtitle option unioned across all discovered servers, tagged with its owner. */
private data class SubtitleOption(
    val label: String,
    val url: String,
    val mimeType: String,
    val owner: String,
    val headers: Map<String, String>,
    /** Extractor tag from the source (e.g. "HLS" for VixSrc subtitle renditions). */
    val source: String = "",
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
    // Live handle to the rendered PlayerView so D-pad / OK can show its
    // controller. The AndroidView is never focusable in Compose, so ExoPlayer's
    // default "press to reveal controls" never fires — the keys below drive it.
    var playerView by remember { mutableStateOf<PlayerView?>(null) }
    // Mirrors the controller's visible state (media3 has no public getter; the
    // view auto-hides after its timeout, so this may drift from the view).
    var controlsVisible by remember { mutableStateOf(false) }
    // Focus index into the visible top-right menu buttons (0=Episodes when a
    // series, then Subtitles/Quality/Servers). -1 = focus on the surface so the
    // D-pad shows/hides controls rather than moving between menus.
    var focusedMenuButton by remember { mutableIntStateOf(-1) }
    // Position to restore when a menu is closed (mirrors Dart's _closeMenus
    // refocus on the opener button).
    var savedMenuButtonPosition by remember { mutableIntStateOf(0) }
    // One requester per possible top-right button (series + 3 menus). Episodes
    // is index 0 and only used for series.
    val menuButtonRequesters = remember { List(4) { FocusRequester() } }
    // Focus index into the bottom playback controls (0=rewind, 1=play/pause,
    // 2=forward, 3=slider). -1 = focus is on the menus/surface. These controls
    // are custom Compose widgets (like Dart's control grid) because ExoPlayer's
    // built-in controller is not focusable inside Compose.
    var focusedPlaybackControl by remember { mutableIntStateOf(-1) }
    val playbackControlRequesters = remember { List(4) { FocusRequester() } }
    // Live playback metrics for the custom progress bar (mirrors Dart's
    // _position/_duration/_isPlaying listeners).
    var positionMs by remember { mutableStateOf(0L) }
    var durationMs by remember { mutableStateOf(0L) }
    var isPlaying by remember { mutableStateOf(false) }
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
    // Root focus target so D-pad/OK always reach onKeyDown even when no control
    // is focused (the PlayerView itself is not focusable). Focus returns here
    // whenever the controls are hidden.
    val rootFocusRequester = remember { FocusRequester() }
    var title by remember { mutableStateOf("") }
    var posterPath by remember { mutableStateOf("") }
    var backdropPath by remember { mutableStateOf("") }
    var seriesTitle by remember { mutableStateOf("") }
    var episodeName by remember { mutableStateOf("") }

    // Current season/episode (mutable so autoplay can advance to the next one;
    // initialised from the navigation args). These are the LOAD TARGET: they
    // are advanced by autoplay/picker BEFORE the new stream is actually built.
    var currentSeason by remember { mutableIntStateOf(season) }
    var currentEpisode by remember { mutableIntStateOf(episode) }
    // The season/episode the CURRENT player instance actually plays (mirrors
    // Dart's _activeSeason/_activeEpisode). Progress saves must use these:
    // currentSeason/currentEpisode can already point at the next episode while
    // the old player is still alive (autoplay transition, picker jump), so a
    // save in that window would write the next episode's key with the previous
    // episode's position, producing the "Continue Watching loads another
    // episode" corruption.
    var activeSeason by remember { mutableIntStateOf(season) }
    var activeEpisode by remember { mutableIntStateOf(episode) }
    // Episode list for the current season (used to find the "next" episode).
    var seasonEpisodes by remember { mutableStateOf<List<EpisodeRef>>(emptyList()) }
    // Guards against re-entering autoplay while the next episode is loading.
    var autoAdvancing by remember { mutableStateOf(false) }

    // Episode picker state (mirrors Dart's _menuSeasons/_menuSeason/cache).
    var menuSeasons by remember { mutableStateOf<List<SeasonInfo>>(emptyList()) }
    var menuSeason by remember { mutableIntStateOf(season) }
    var menuEpisodesCache by remember { mutableStateOf<Map<Int, List<EpisodeRef>>>(emptyMap()) }
    var episodeMenuLoading by remember { mutableStateOf(false) }

    // Current subtitle options across every server (grouped + own headers).
    var subtitleOptions by remember { mutableStateOf<List<SubtitleOption>>(emptyList()) }
    // The active subtitle config attached to the playing item (null = off).
    var activeSubtitle by remember { mutableStateOf<SubtitleOption?>(null) }

    // Generation guard so stale async rebuilds never touch a disposed player.
    val rebuildGeneration = remember { mutableStateOf(0) }

    /** Saves current playback progress (position + title metadata). Uses the
     * active episode — the one the current player actually plays — not the
     * load target, so a save during an autoplay/picker transition can never
     * stamp the next episode's key with the previous player's position. */
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
            season = activeSeason,
            episode = activeEpisode,
            positionSeconds = positionMs / 1000,
            durationSeconds = durationMs / 1000,
            posterPath = posterPath,
            backdropPath = backdropPath,
            seriesTitle = seriesTitle,
            episodeName = episodeName,
        )
        // Push to Firestore so the phone (same account) sees this progress live.
        coroutineScope.launch {
            com.maxstream.app.data.repository.CloudSyncRepository.pushWatchProgress(
                context = context,
                tmdbId = itemId,
                title = title.ifBlank { itemId },
                isMovie = isMovie,
                season = activeSeason,
                episode = activeEpisode,
                positionSeconds = positionMs / 1000,
                durationSeconds = durationMs / 1000,
                posterPath = posterPath,
                seriesTitle = seriesTitle,
                episodeName = episodeName,
            )
        }
    }

    /** Marks the currently-playing item as fully watched (mirrors Dart's
     * markAsWatched in _completeCurrentItem) so it leaves Continue Watching. */
    fun markWatched() {
        WatchProgressRepository.markAsWatched(
            context = context,
            tmdbId = itemId,
            title = title.ifBlank { itemId },
            isMovie = isMovie,
            season = activeSeason,
            episode = activeEpisode,
            posterPath = posterPath,
            seriesTitle = seriesTitle,
            episodeName = episodeName,
        )
    }

    /**
     * Snapshots the live playback position into [resumePositionMs] BEFORE the
     * player is torn down. Without this, a memory-pressure release during a
     * buffer would rebuild from the position loaded at startup (last exit), not
     * where playback actually was.
     */
    fun captureResumePosition() {
        val player = exoPlayer
        if (player != null && player.playbackState != Player.STATE_IDLE && player.duration > 0) {
            resumePositionMs = player.currentPosition
        }
    }

    fun qualityLabelFor(s: Source): String {
        if (s.separateAudio) return "Auto"
        val currentUrl = s.url
        return s.qualities.firstOrNull { it.url == currentUrl }?.label ?: "Auto"
    }

    fun subtitleMimeType(url: String, source: String = ""): String = when {
        // HLS subtitle renditions (e.g. VixSrc) return an m3u8 playlist even
        // though their URLs carry no .m3u8 extension, so the extractor's
        // source tag is the authoritative signal (mirrors Dart's track.source).
        source.equals("HLS", true) || url.contains(".m3u8", true) -> MimeTypes.APPLICATION_M3U8
        url.contains(".vtt", true) -> MimeTypes.TEXT_VTT
        url.contains(".srt", true) -> MimeTypes.APPLICATION_SUBRIP
        url.contains(".ssa", true) || url.contains(".ass", true) -> MimeTypes.TEXT_SSA
        else -> MimeTypes.TEXT_VTT
    }

    fun qualityOptions(s: Source?): List<Quality> {
        val q = s?.qualities ?: return emptyList()
        return listOf(Quality(label = "Auto", url = "", height = 0)) + q
    }

    /**
     * Advances to the next episode when a series episode finishes. Mirrors
     * Dart's _resolveNextEpisode/_playNextEpisode: same-season next number, or
     * season N+1 episode 1 when the current season is exhausted.
     */
    suspend fun playNextEpisode() {
        if (isMovie || autoAdvancing) return
        autoAdvancing = true
        try {
            val numbers = seasonEpisodes.map { it.number }.filter { it > 0 }
            val maxInSeason = numbers.maxOrNull()
            val nextSeason: Int
            val nextEpisode: Int
            if (maxInSeason != null && currentEpisode >= maxInSeason) {
                nextSeason = currentSeason + 1
                nextEpisode = 1
            } else {
                nextSeason = currentSeason
                nextEpisode = currentEpisode + 1
            }
            status = "Auto-playing S${nextSeason}E$nextEpisode..."
            currentSeason = nextSeason
            currentEpisode = nextEpisode
            resumePositionMs = 0L
            // loadAndPlay() is re-invoked by the LaunchedEffect keyed on
            // (currentSeason, currentEpisode); it refetches metadata + resolves
            // the stream for the new episode.
        } finally {
            autoAdvancing = false
        }
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
        val okHttpDataSourceFactory = OkHttpDataSource.Factory(httpClient)
            .setDefaultRequestProperties(headers)
        // Wrap the OkHttp factory so file:// URIs (the local VTT files produced
        // by resolveHlsSubtitlePlaylist) open via FileDataSource while http(s)
        // still routes through OkHttp with the server headers.
        val dataSourceFactory = androidx.media3.datasource.DefaultDataSource.Factory(
            context,
            okHttpDataSourceFactory,
        )

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

        // On completion, persist the final position, mark the item watched (so
        // it leaves Continue Watching — mirrors Dart's _completeCurrentItem),
        // and auto-advance to the next episode for series. Movies stop at the
        // end screen.
        player.addListener(
            object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    if (playbackState == Player.STATE_ENDED && !autoAdvancing) {
                        saveProgress()
                        // Mark the finished item watched so it drops out of
                        // Continue Watching.
                        markWatched()
                        if (!isMovie) {
                            coroutineScope.launch { playNextEpisode() }
                        }
                    }
                }
            },
        )
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
                // Concatenate into a single WEBVTT document, stripping per-segment
                // WEBVTT headers and NOTE lines (mirrors the mobile player).
                val vtt = buildString {
                    append("WEBVTT\n\n")
                    for (part in parts) {
                        val cleaned = part
                            .replace(Regex("""WEBVTT[\s\S]*?\n\n"""), "")
                            .replace(Regex("""^NOTE.*$""", RegexOption.MULTILINE), "")
                            .trim()
                        if (cleaned.isNotEmpty()) {
                            append(cleaned)
                            append("\n\n")
                        }
                    }
                }
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
                        mimeType = subtitleMimeType(sub.url, sub.source),
                        owner = server.displayName,
                        headers = server.headers,
                        source = sub.source,
                    ),
                )
            }
        }
        return result
    }

    /** True when a subtitle option is an HLS subtitle rendition (m3u8 of .vtt
     * segments). VixSrc subtitle URLs carry no `.m3u8` extension, so the
     * extractor's source tag is the authoritative signal (mirrors Dart). */
    fun isHlsSubtitle(sub: SubtitleOption): Boolean =
        sub.source.equals("HLS", true) || sub.url.contains(".m3u8", true)

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
            if (sub != null && isHlsSubtitle(sub)) {
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
            // For series, also resolve the current episode's still + name so the
            // Continue Watching card shows that episode's own cover art (mirrors
            // Dart TvVideoPlayer._loadMediaMetadata).
            val id = itemId.toIntOrNull()
            if (id != null) {
                try {
                    if (isMovie) {
                        val details = Modules.catalogRepository.movieDetails(id)
                        title = details.optString("title").ifBlank { details.optString("name") }
                        posterPath = details.optString("poster_path")
                        backdropPath = details.optString("backdrop_path")
                    } else {
                        val details = Modules.catalogRepository.seriesDetails(id)
                        val seriesName = details.optString("name").ifBlank { details.optString("title") }
                        title = seriesName
                        posterPath = details.optString("poster_path")
                        backdropPath = details.optString("backdrop_path")
                        seriesTitle = seriesName
                        // Current episode still (its own cover art) + name.
                        val episodes = runCatching {
                            Modules.catalogRepository.seasonEpisodes(id, currentSeason)
                        }.getOrDefault(emptyList())
                        seasonEpisodes = episodes
                        val currentEpisodeInfo = episodes.firstOrNull { it.number == currentEpisode }
                        currentEpisodeInfo?.let { ep ->
                            episodeName = ep.title
                            ep.stillPath?.let { still ->
                                // Still is already a w500 path fragment; coverUrl
                                // in WatchEntry turns it into a full URL.
                                posterPath = still
                            }
                        }
                    }
                } catch (_: Exception) {
                }
            }

            // Resume position from watch history.
            resumePositionMs = WatchProgressRepository.loadPosition(
                context, itemId, isMovie, currentSeason, currentEpisode,
            ) * 1000

            // Primary stream for this title/episode. This is a parallel race
            // across all servers, so the first playable one arrives fast (a
            // single dead server can no longer stall the whole chain).
            val primary = Modules.streamRepository(context).resolve(
                tmdbId = itemId,
                isMovie = isMovie,
                season = currentSeason,
                episode = currentEpisode,
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
            if (initialSub != null && isHlsSubtitle(initialSub)) {
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
            // The player for the load target is now live — from here on, saves
            // are attributed to this episode (and not the previous one whose
            // player is still being torn down).
            activeSeason = currentSeason
            activeEpisode = currentEpisode
            activeSubtitle = initialSub
            selectedSubtitleLabel = initialSub?.label ?: "Off"
            loading = false

            // Populate the server picker + cross-server subtitle fallback in the
            // background so it never blocks the first frame of playback.
            coroutineScope.launch {
                val servers = Modules.streamRepository(context).resolveAll(
                    tmdbId = itemId,
                    isMovie = isMovie,
                    season = currentSeason,
                    episode = currentEpisode,
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

    LaunchedEffect(itemId, mediaType, currentSeason, currentEpisode) {
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
            captureResumePosition()
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
                    captureResumePosition()
                    exoPlayer?.release()
                    exoPlayer = null
                    memoryReleased = true
                    loading = true
                    status = "Resuming..."
                }
            }

            override fun onLowMemory() {
                saveProgress()
                captureResumePosition()
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

    // Keep the screen on while the player is active - including when the video
    // is paused - so the TV never sleeps mid-binge (mirrors Dart's wakelock).
    DisposableEffect(Unit) {
        val activity = context.findActivity()
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
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

    // Poll the live playback metrics so the custom progress bar / play button
    // stay in sync (mirrors Dart's controller position listener). Keyed on the
    // player instance so it restarts after every rebuild.
    LaunchedEffect(exoPlayer) {
        val player = exoPlayer ?: return@LaunchedEffect
        while (true) {
            positionMs = player.currentPosition
            durationMs = player.duration
            isPlaying = player.isPlaying
            kotlinx.coroutines.delay(500)
        }
    }

    // Ensure the D-pad/OK reach onKeyDown even when nothing is focused: grab
    // the root focus once the player is ready (the PlayerView is not focusable,
    // so without this the keys go nowhere and the controls never appear).
    LaunchedEffect(exoPlayer, loading, controlsVisible, focusedMenuButton, focusedPlaybackControl) {
        if (exoPlayer != null && !loading && !controlsVisible &&
            focusedMenuButton < 0 && focusedPlaybackControl < 0
        ) {
            runCatching { rootFocusRequester.requestFocus() }
        }
    }

    // ------------------------------------------------------------------
    // D-pad / remote handling
    // ------------------------------------------------------------------

    /** Loads (and caches) the episodes for [season] for the picker. */
    suspend fun loadMenuSeasonEpisodes(season: Int) {
        if (menuEpisodesCache.containsKey(season)) return
        val id = itemId.toIntOrNull() ?: return
        val episodes = runCatching {
            Modules.catalogRepository.seasonEpisodes(id, season)
        }.getOrDefault(emptyList())
        menuEpisodesCache = menuEpisodesCache + (season to episodes)
    }

    /** Opens the episode picker: loads the season list then the current season's
     * episodes (mirrors Dart's _openEpisodeMenu/_loadMenuEpisodes). */
    suspend fun openEpisodePicker() {
        val id = itemId.toIntOrNull() ?: return
        episodeMenuLoading = true
        try {
            if (menuSeasons.isEmpty()) {
                val details = runCatching {
                    Modules.catalogRepository.seriesDetails(id)
                }.getOrNull()
                val raw = details?.optJSONArray("seasons")
                val seasons = mutableListOf<SeasonInfo>()
                if (raw != null) {
                    for (i in 0 until raw.length()) {
                        val s = raw.optJSONObject(i) ?: continue
                        val number = s.optInt("season_number", 0)
                        if (number <= 0) continue
                        seasons.add(
                            SeasonInfo(
                                number = number,
                                name = s.optString("name").ifBlank { "Season $number" },
                                episodeCount = s.optInt("episode_count", 0),
                            ),
                        )
                    }
                }
                menuSeasons = seasons.ifEmpty {
                    listOf(SeasonInfo(currentSeason, "Season $currentSeason", 0))
                }
                menuSeason = currentSeason
            }
            if (!menuEpisodesCache.containsKey(menuSeason)) {
                loadMenuSeasonEpisodes(menuSeason)
            }
        } finally {
            episodeMenuLoading = false
        }
    }

    /** Re-queues playback onto the SAME player for the chosen episode. */
    fun playEpisode(newSeason: Int, newEpisode: Int) {
        if (newSeason == currentSeason && newEpisode == currentEpisode) return
        status = "Loading S${newSeason}E$newEpisode..."
        currentSeason = newSeason
        currentEpisode = newEpisode
        resumePositionMs = 0L
        // The LaunchedEffect keyed on (currentSeason, currentEpisode) reloads
        // and plays the new episode.
    }

    // Visible top-right menu buttons, in display order. Index 0 is the
    // Episodes button for series; 1..3 are Subtitles/Quality/Servers.
    val topMenuButtons = buildList<TopMenuButton> {
        if (!isMovie) {
            add(
                TopMenuButton(
                    index = 0,
                    label = "Episodes",
                    subLabel = "S$currentSeason  E$currentEpisode",
                    onClick = {
                        savedMenuButtonPosition = focusedMenuButton
                        menuOpen = true
                        activeMenu = PlayerMenu.Episodes
                        menuIndex = 0
                        focusedMenuButton = -1
                        coroutineScope.launch { openEpisodePicker() }
                    },
                ),
            )
        }
        add(
            TopMenuButton(
                index = 1,
                label = "Subtitles",
                subLabel = selectedSubtitleLabel,
                    onClick = {
                        savedMenuButtonPosition = focusedMenuButton
                        menuOpen = true
                        activeMenu = PlayerMenu.Subtitles
                        menuIndex = 0
                        focusedMenuButton = -1
                    },
            ),
        )
        add(
            TopMenuButton(
                index = 2,
                label = "Quality",
                subLabel = selectedQualityLabel,
                    onClick = {
                        savedMenuButtonPosition = focusedMenuButton
                        menuOpen = true
                        activeMenu = PlayerMenu.Quality
                        menuIndex = 0
                        focusedMenuButton = -1
                    },
            ),
        )
        add(
            TopMenuButton(
                index = 3,
                label = "Server",
                subLabel = source?.displayName ?: "Auto",
                    onClick = {
                        savedMenuButtonPosition = focusedMenuButton
                        menuOpen = true
                        activeMenu = PlayerMenu.Servers
                        menuIndex = 0
                        focusedMenuButton = -1
                    },
            ),
        )
    }

    // Auto-hide the controls after 5s of inactivity while a menu is closed
    // (mirrors Dart's _resetHideTimer). Any key-driven change to the focus
    // target restarts this effect, so idle playback hides the overlay.
    LaunchedEffect(controlsVisible, menuOpen, focusedMenuButton, focusedPlaybackControl) {
        if (!controlsVisible || menuOpen) return@LaunchedEffect
        delay(5_000)
        if (menuOpen) return@LaunchedEffect
        controlsVisible = false
        focusedMenuButton = -1
        focusedPlaybackControl = -1
    }

    // Request focus on the intended control AFTER the recomposition puts it in
    // the tree. Calling FocusRequester.requestFocus() synchronously inside the
    // key handler fails because the control is not composed yet (Dart solves
    // the same race with addPostFrameCallback + requestFocus). Because this
    // effect runs after composition, the requested node is usually attached.
    // requestFocus() is a silent no-op (returns Unit) when it is not, so we
    // retry over a few frames (previously the `; true` masked the failure and
    // the controls never got focus — the "focus escapes the menus" symptom).
    LaunchedEffect(controlsVisible, menuOpen, exoPlayer, loading, focusedMenuButton, focusedPlaybackControl) {
        if (exoPlayer == null || loading) return@LaunchedEffect
        if (controlsVisible && !menuOpen) {
            val requester: FocusRequester? = when {
                focusedMenuButton >= 0 && topMenuButtons.isNotEmpty() ->
                    topMenuButtons.getOrNull(focusedMenuButton)?.let { menuButtonRequesters.getOrNull(it.index) }
                focusedPlaybackControl >= 0 ->
                    playbackControlRequesters.getOrNull(focusedPlaybackControl)
                else -> null
            }
            if (requester != null) {
                var attempt = 0
                while (attempt < 6) {
                    if (attempt > 0) delay(40L * attempt)
                    runCatching { requester.requestFocus() }
                    attempt++
                }
            } else {
                runCatching { rootFocusRequester.requestFocus() }
            }
        } else {
            runCatching { rootFocusRequester.requestFocus() }
        }
    }

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
            PlayerMenu.Episodes -> {
                // Handled by onKeyDown (menuIndex = focused episode); selecting
                // the highlighted episode re-queues playback on the SAME player.
                val episodes = menuEpisodesCache[menuSeason] ?: emptyList()
                if (episodes.isEmpty() || menuIndex >= episodes.size) return
                val target = episodes[menuIndex]
                if (target.number == currentEpisode && menuSeason == currentSeason) {
                    menuOpen = false
                    activeMenu = null
                    return
                }
                menuOpen = false
                activeMenu = null
                playEpisode(menuSeason, target.number)
            }
        }
    }

    /** Moves focus onto [position] within the top-right menu buttons row. */
    fun focusMenuButton(position: Int) {
        focusedMenuButton = position
        focusedPlaybackControl = -1
        val btn = topMenuButtons.getOrNull(position) ?: return
        // Best effort synchronously; the LaunchedEffect above retries after the
        // controls are composed.
        runCatching { menuButtonRequesters.getOrNull(btn.index)?.requestFocus() }
    }

    /** Moves focus onto one of the bottom playback controls (0..3). */
    fun focusPlaybackControl(position: Int) {
        focusedPlaybackControl = position
        focusedMenuButton = -1
        // Best effort synchronously; the LaunchedEffect above retries after the
        // controls are composed.
        runCatching { playbackControlRequesters.getOrNull(position)?.requestFocus() }
    }

    fun seekBy(deltaSec: Int) {
        val player = exoPlayer ?: return
        val dur = player.duration
        val target = if (dur > 0) {
            (player.currentPosition + deltaSec * 1000L).coerceIn(0L, dur)
        } else {
            (player.currentPosition + deltaSec * 1000L).coerceAtLeast(0L)
        }
        player.seekTo(target)
    }

    fun togglePlayPause() {
        val player = exoPlayer ?: return
        if (player.isPlaying) player.pause() else player.play()
    }

    /** Activates the currently focused playback control (mirrors Dart's
     * _activateControl: rewind/forward seek, playPause toggles). */
    fun activatePlaybackControl() {
        when (focusedPlaybackControl) {
            0 -> seekBy(-10)
            1 -> togglePlayPause()
            2 -> seekBy(10)
            3 -> Unit // slider: OK does nothing
            else -> Unit
        }
    }

    fun onKeyDown(key: Key): Boolean {
        when (key) {
            Key.DirectionUp -> {
                if (menuOpen) {
                    // Episode picker: header/season row handles Up (return to
                    // season tabs) — simplified to just clamp at 0.
                    menuIndex = if (menuIndex > 0) menuIndex - 1 else menuIndex
                    return true
                }
                // Up from a playback control goes to the top-right menu row.
                if (focusedPlaybackControl >= 0) {
                    if (topMenuButtons.isNotEmpty()) focusMenuButton(0)
                    else focusedPlaybackControl = -1
                    return true
                }
                // Surface: reveal controls and focus the menu row.
                controlsVisible = true
                if (topMenuButtons.isNotEmpty()) focusMenuButton(0)
                return true
            }
            Key.DirectionDown -> {
                if (menuOpen) {
                    // While a panel is open, focus STAYS inside the submenu —
                    // DOWN only moves to the next option (clamped at the end).
                    val count = when (activeMenu) {
                        PlayerMenu.Servers -> allServers.size
                        PlayerMenu.Quality -> qualityOptions(source).size
                        PlayerMenu.Subtitles -> subtitleOptions.size + 1
                        PlayerMenu.Episodes -> (menuEpisodesCache[menuSeason] ?: emptyList()).size
                        null -> 0
                    }
                    if (menuIndex + 1 < count) menuIndex++
                    return true
                }
                // Down from a playback control (0..2) moves to the slider.
                if (focusedPlaybackControl >= 0) {
                    if (focusedPlaybackControl < 3) focusPlaybackControl(3)
                    return true
                }
                // Down from the top-right menu buttons drops onto the slider
                // (progress bar) so DOWN always reaches the controls.
                if (focusedMenuButton >= 0) {
                    focusPlaybackControl(3)
                    return true
                }
                controlsVisible = true
                focusPlaybackControl(3)
                return true
            }
            Key.DirectionCenter, Key.Enter -> {
                if (menuOpen) {
                    selectMenuOption(source)
                    return true
                }
                // A focused top-right menu button opens its panel on OK.
                if (focusedMenuButton >= 0) {
                    topMenuButtons.getOrNull(focusedMenuButton)?.onClick?.invoke()
                    return true
                }
                // A focused playback control activates (seek / play-pause).
                if (focusedPlaybackControl >= 0) {
                    activatePlaybackControl()
                    return true
                }
                // Toggle playback controls on OK (show on play/pause focus,
                // hide otherwise — Dart: select toggles _showControls).
                if (!controlsVisible) {
                    controlsVisible = true
                    focusPlaybackControl(1)
                } else {
                    controlsVisible = false
                    focusedMenuButton = -1
                    focusedPlaybackControl = -1
                }
                return true
            }
            Key.DirectionLeft, Key.DirectionRight -> {
                if (menuOpen) {
                    // Episode picker: Left/Right switches between seasons.
                    if (activeMenu == PlayerMenu.Episodes && menuSeasons.size > 1) {
                        val delta = if (key == Key.DirectionLeft) -1 else 1
                        val cur = menuSeasons.indexOfFirst { it.number == menuSeason }
                        val next = (cur + delta + menuSeasons.size) % menuSeasons.size
                        menuSeason = menuSeasons[next].number
                        menuIndex = 0
                        if (!menuEpisodesCache.containsKey(menuSeason)) {
                            coroutineScope.launch { loadMenuSeasonEpisodes(menuSeason) }
                        }
                        return true
                    }
                    return false
                }
                // When a top-right menu button has focus, move between buttons.
                if (focusedMenuButton >= 0 && topMenuButtons.isNotEmpty()) {
                    val delta = if (key == Key.DirectionLeft) -1 else 1
                    val next = (focusedMenuButton + delta + topMenuButtons.size) % topMenuButtons.size
                    focusMenuButton(next)
                    return true
                }
                // Playback control focus: slider seeks, the three buttons move
                // between each other.
                if (focusedPlaybackControl >= 0) {
                    if (focusedPlaybackControl == 3) {
                        seekBy(if (key == Key.DirectionLeft) -10 else 10)
                    } else {
                        val delta = if (key == Key.DirectionLeft) -1 else 1
                        val next = (focusedPlaybackControl + delta).coerceIn(0, 2)
                        focusPlaybackControl(next)
                    }
                    return true
                }
                // Reveal controls on a directional press (Dart: LEFT -> rewind,
                // RIGHT -> forward, DOWN -> slider, UP -> playPause).
                if (!controlsVisible) {
                    controlsVisible = true
                    if (key == Key.DirectionLeft) focusPlaybackControl(0)
                    else focusPlaybackControl(2)
                    return true
                }
                // Controls visible but nothing focused — consume the event
                // (prevents stray key propagation on some TV firmware).
                return true
            }
            Key.Back, Key.Escape -> {
                if (menuOpen) {
                    // Close the panel and return focus to the button that
                    // opened it (mirrors Dart's _closeMenus refocus).
                    menuOpen = false
                    activeMenu = null
                    menuIndex = 0
                    focusMenuButton(savedMenuButtonPosition)
                } else if (focusedPlaybackControl >= 0) {
                    focusedPlaybackControl = -1
                } else if (focusedMenuButton >= 0) {
                    focusedMenuButton = -1
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
            .focusRequester(rootFocusRequester)
            .focusable()
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
                        // Custom focusable Compose controls replace the built-in
                        // controller (which is not focusable inside Compose).
                        view.useController = false
                        playerView = view
                    }
                },
                update = { view ->
                    view.player = exoPlayer
                    playerView = view
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
                    text = if (isMovie) {
                        title.ifBlank { source?.displayName ?: "" }
                    } else {
                        val ep = episodeName.ifBlank { "Episode $currentEpisode" }
                        val series = seriesTitle.ifBlank { title }
                        "$series · S$currentSeason E$currentEpisode · $ep"
                    },
                    color = Color.White,
                    fontSize = 14.sp,
                    maxLines = 1,
                    modifier = Modifier
                        .background(Color(0x99000000))
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
        }

        // Menu buttons row (top-right) — fused with the playback controls, exactly
        // like Dart: they appear/hide together with the controller overlay, use
        // the app's rounded white focus, and each shows its current selection
        // as a sub-label under the title.
        if (controlsVisible && !loading && error == null && !menuOpen) {
            Row(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                topMenuButtons.forEachIndexed { position, btn ->
                    val index = btn.index
                    PlayerTopButton(
                        label = btn.label,
                        subLabel = btn.subLabel,
                        isFocused = focusedMenuButton == position,
                        requester = menuButtonRequesters[index],
                        onClick = btn.onClick,
                    )
                }
            }

            // Custom playback controls (bottom-center, like Dart's rewind /
            // play-pause / forward row + slider). These replace ExoPlayer's
            // built-in controller and are focusable via the D-pad. Mirrors
            // Dart's layout: the centered icon button row sits raised above
            // the progress bar.
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    PlaybackControlButton(
                        iconRes = R.drawable.ic_replay_10,
                        label = "Back 10s",
                        isFocused = focusedPlaybackControl == 0,
                        requester = playbackControlRequesters[0],
                        onClick = { seekBy(-10) },
                        onFocusChanged = {
                            if (it) focusPlaybackControl(0)
                        },
                    )
                    PlaybackControlButton(
                        iconRes = if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play,
                        label = if (isPlaying) "Pause" else "Play",
                        isFocused = focusedPlaybackControl == 1,
                        requester = playbackControlRequesters[1],
                        onClick = { togglePlayPause() },
                        onFocusChanged = {
                            if (it) focusPlaybackControl(1)
                        },
                    )
                    PlaybackControlButton(
                        iconRes = R.drawable.ic_forward_10,
                        label = "Fwd 10s",
                        isFocused = focusedPlaybackControl == 2,
                        requester = playbackControlRequesters[2],
                        onClick = { seekBy(10) },
                        onFocusChanged = {
                            if (it) focusPlaybackControl(2)
                        },
                    )
                }
                Spacer(modifier = Modifier.height(14.dp))
                // Progress bar / slider (focus index 3).
                PlayerProgressBar(
                    positionMs = positionMs,
                    durationMs = durationMs,
                    isFocused = focusedPlaybackControl == 3,
                    requester = playbackControlRequesters[3],
                    onFocusChanged = {
                        if (it) focusPlaybackControl(3)
                    },
                )
            }
        }

        // Selection panel.
        if (menuOpen) {
            if (activeMenu == PlayerMenu.Episodes && !isMovie) {
                EpisodePanel(
                    seriesTitle = seriesTitle.ifBlank { title },
                    seasons = menuSeasons,
                    menuSeason = menuSeason,
                    episodes = menuEpisodesCache[menuSeason] ?: emptyList(),
                    focusedEpisode = menuIndex,
                    currentSeason = currentSeason,
                    currentEpisode = currentEpisode,
                    loading = episodeMenuLoading,
                    onSeasonSelect = { newSeason ->
                        if (newSeason != menuSeason) {
                            menuSeason = newSeason
                            menuIndex = 0
                            if (!menuEpisodesCache.containsKey(newSeason)) {
                                coroutineScope.launch { loadMenuSeasonEpisodes(newSeason) }
                            }
                        }
                    },
                    onEpisodeSelect = { newSeason, newEpisode ->
                        menuOpen = false
                        activeMenu = null
                        playEpisode(newSeason, newEpisode)
                    },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 76.dp, end = 16.dp),
                )
            } else {
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
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 76.dp, end = 16.dp),
                )
            }
        }
    }
}

@Composable
private fun PlaybackControlButton(
    iconRes: Int,
    label: String,
    isFocused: Boolean,
    requester: FocusRequester,
    onClick: () -> Unit,
    onFocusChanged: (Boolean) -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.08f else 1f,
        animationSpec = tween(durationMillis = 150, easing = FastOutSlowInEasing),
        label = "playbackControlScale",
    )
    Row(
        modifier = Modifier
            .scale(scale)
            .background(
                if (isFocused) Color(0xFFE50914) else Color(0xCC000000),
                RoundedCornerShape(50),
            )
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(50),
            )
            .focusRequester(requester)
            .onFocusChanged { onFocusChanged(it.isFocused) }
            .focusable()
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(iconRes),
            contentDescription = label,
            colorFilter = ColorFilter.tint(if (isFocused) Color.White else Color(0xCCFFFFFF)),
            modifier = Modifier.size(22.dp),
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = label,
            color = if (isFocused) Color.White else Color(0xCCFFFFFF),
            fontSize = 15.sp,
            maxLines = 1,
        )
    }
}

@Composable
private fun PlayerProgressBar(
    positionMs: Long,
    durationMs: Long,
    isFocused: Boolean,
    requester: FocusRequester,
    onFocusChanged: (Boolean) -> Unit,
) {
    val fraction = if (durationMs > 0) {
        (positionMs.toFloat() / durationMs.toFloat()).coerceIn(0f, 1f)
    } else {
        0f
    }
    val barWidth = 560.dp
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .width(barWidth)
                .height(8.dp)
                .background(Color(0x66FFFFFF), RoundedCornerShape(4.dp))
                .focusRequester(requester)
                .onFocusChanged { onFocusChanged(it.isFocused) }
                .focusable(),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(fraction)
                    .height(8.dp)
                    .background(Color(0xFFE50914), RoundedCornerShape(4.dp)),
            )
            if (isFocused) {
                Box(
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .width(4.dp)
                        .height(20.dp)
                        .background(Color.White, RoundedCornerShape(2.dp))
                        .offset(x = (barWidth * fraction) - 2.dp),
                )
            }
        }
        Spacer(modifier = Modifier.height(4.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = formatTimeMs(positionMs),
                color = Color.White,
                fontSize = 13.sp,
            )
            Text(
                text = "/",
                color = Color(0x66FFFFFF),
                fontSize = 13.sp,
            )
            Text(
                text = formatTimeMs(durationMs),
                color = Color(0x66FFFFFF),
                fontSize = 13.sp,
            )
        }
    }
}

private fun formatTimeMs(ms: Long): String {
    val totalSeconds = ms / 1000
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) {
        String.format("%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format("%d:%02d", minutes, seconds)
    }
}

@Composable
private fun PlayerTopButton(
    label: String,
    subLabel: String,
    isFocused: Boolean,
    requester: FocusRequester,
    onClick: () -> Unit,
) {
    // Uses the app's rounded white focus (like ContentCard), driven by state so
    // it always shows even though the underlying PlayerView is not focusable.
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.08f else 1f,
        animationSpec = tween(durationMillis = 150, easing = FastOutSlowInEasing),
        label = "playerTopButtonScale",
    )
    Box(
        modifier = Modifier
            .scale(scale)
            .background(
                if (isFocused) Color(0xFFE50914) else Color(0xCC000000),
                RoundedCornerShape(8.dp),
            )
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(8.dp),
            )
            .focusRequester(requester)
            .focusable()
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = label,
                color = if (isFocused) Color.White else Color.White,
                fontSize = 13.sp,
                maxLines = 1,
            )
            if (subLabel.isNotBlank()) {
                Text(
                    text = subLabel,
                    color = if (isFocused) Color(0xFFFFCCCC) else Color(0xFFE50914),
                    fontSize = 11.sp,
                    maxLines = 1,
                )
            }
        }
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
        PlayerMenu.Episodes -> emptyList()
        null -> emptyList()
    }

    val title = when (activeMenu) {
        PlayerMenu.Servers -> "Server"
        PlayerMenu.Quality -> "Quality"
        PlayerMenu.Subtitles -> "Subtitles"
        PlayerMenu.Episodes -> "Episodes"
        null -> ""
    }

    Column(
        modifier = modifier
            .width(340.dp)
            .background(
                Color(0xF2181818),
                RoundedCornerShape(12.dp),
            )
            .border(
                1.dp,
                Color(0x40FFFFFF),
                RoundedCornerShape(12.dp),
            ),
    ) {
        // Header — mirrors Dart's red-accent title with the focus arrow.
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = title,
                color = Color(0xFFE50914),
                fontSize = 18.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
            )
            Spacer(modifier = Modifier.weight(1f))
            if (menuIndex < 0) {
                Text(
                    text = "▲",
                    color = Color(0xFFE50914),
                    fontSize = 14.sp,
                )
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(Color(0x40FFFFFF)),
        )
        // Auto-scroll so the focused row stays in view as the D-pad moves
        // through long lists (mirrors Dart's ListView + ensureVisible).
        val listState = rememberLazyListState()
        LaunchedEffect(menuIndex) {
            if (menuIndex >= 0 && menuIndex < items.size) {
                listState.animateScrollToItem(menuIndex)
            }
        }
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 420.dp),
        ) {
            items(items.size) { index ->
                val (label, isSelected) = items[index]
                val focused = index == menuIndex
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            when {
                                isSelected -> Color(0xFFE50914)
                                focused -> Color(0x1FFFFFFF)
                                else -> Color.Transparent
                            },
                        )
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = label,
                        color = if (isSelected) Color.White else Color(0xB3FFFFFF),
                        fontSize = 16.sp,
                        fontWeight = if (isSelected) {
                            androidx.compose.ui.text.font.FontWeight.Bold
                        } else {
                            androidx.compose.ui.text.font.FontWeight.Normal
                        },
                        maxLines = 1,
                        modifier = Modifier.weight(1f),
                    )
                    if (isSelected) {
                        Text(
                            text = "✓",
                            color = Color.White,
                            fontSize = 18.sp,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EpisodePanel(
    seriesTitle: String,
    seasons: List<SeasonInfo>,
    menuSeason: Int,
    episodes: List<EpisodeRef>,
    focusedEpisode: Int,
    currentSeason: Int,
    currentEpisode: Int,
    loading: Boolean,
    onSeasonSelect: (Int) -> Unit,
    onEpisodeSelect: (Int, Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .width(420.dp)
            .background(
                Color(0xF2181818),
                RoundedCornerShape(12.dp),
            )
            .border(
                1.dp,
                Color(0x40FFFFFF),
                RoundedCornerShape(12.dp),
            ),
    ) {
        // Header (mirrors Dart's series title + "Episodes").
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = seriesTitle,
                color = Color(0xFFE50914),
                fontSize = 18.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                maxLines = 1,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = "Episodes",
                color = Color(0xFFE50914),
                fontSize = 16.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(Color(0x40FFFFFF)),
        )
        // Season tabs (horizontal, active = red pill).
        if (seasons.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                seasons.forEach { season ->
                    val active = season.number == menuSeason
                    val label = if (season.name.isNotEmpty() && season.name.length <= 14) {
                        season.name
                    } else {
                        "Season ${season.number}"
                    }
                    Row(
                        modifier = Modifier
                            .background(
                                if (active) Color(0xFFE50914) else Color.Transparent,
                                RoundedCornerShape(20.dp),
                            )
                            .border(
                                1.dp,
                                if (active) Color.Transparent else Color(0x40FFFFFF),
                                RoundedCornerShape(20.dp),
                            )
                            .clickable { onSeasonSelect(season.number) }
                            .padding(horizontal = 18.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = label,
                            color = if (active) Color.White else Color(0xB3FFFFFF),
                            fontSize = 16.sp,
                            fontWeight = if (active) {
                                androidx.compose.ui.text.font.FontWeight.Bold
                            } else {
                                androidx.compose.ui.text.font.FontWeight.Normal
                            },
                        )
                        if (season.episodeCount > 0) {
                            Text(
                                text = "(${season.episodeCount})",
                                color = if (active) Color(0xB3FFFFFF) else Color(0x61FFFFFF),
                                fontSize = 13.sp,
                            )
                        }
                    }
                }
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(Color(0x40FFFFFF)),
            )
        }
        // Episode list (mirrors Dart's _episodeTile: thumbnail + S#E# + name).
        when {
            loading && episodes.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(color = Color(0xFFE50914))
                }
            }
            episodes.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "No episodes found",
                        color = Color(0xB3FFFFFF),
                        fontSize = 16.sp,
                    )
                }
            }
            else -> {
                // Auto-scroll so the focused episode stays in view as the D-pad
                // moves through the list (mirrors Dart's ListView + ensureVisible).
                val listState = rememberLazyListState()
                LaunchedEffect(focusedEpisode) {
                    if (focusedEpisode >= 0 && focusedEpisode < episodes.size) {
                        listState.animateScrollToItem(focusedEpisode)
                    }
                }
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 420.dp)
                        .padding(vertical = 6.dp),
                ) {
                    items(episodes.size) { index ->
                        val ep = episodes[index]
                        val isPlaying =
                            menuSeason == currentSeason && ep.number == currentEpisode
                        val isFocused = index == focusedEpisode
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 6.dp)
                                .background(
                                    when {
                                        isPlaying -> Color(0x33E50914)
                                        isFocused -> Color(0x1FFFFFFF)
                                        else -> Color.Transparent
                                    },
                                    RoundedCornerShape(8.dp),
                                )
                                .border(
                                    if (isFocused) 2.dp else 0.dp,
                                    Color(0xFFE50914),
                                    RoundedCornerShape(8.dp),
                                )
                                .clickable {
                                    onEpisodeSelect(menuSeason, ep.number)
                                }
                                .padding(8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(
                                modifier = Modifier
                                    .width(148.dp)
                                    .height(80.dp)
                                    .background(Color(0xFF2A2A2A), RoundedCornerShape(6.dp)),
                            ) {
                                if (!ep.stillPath.isNullOrBlank()) {
                                    coil.compose.AsyncImage(
                                        model = "${com.maxstream.app.core.Constants.TMDB_IMAGE_BASE}/w500${ep.stillPath}",
                                        contentDescription = null,
                                        modifier = Modifier.fillMaxSize(),
                                        contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.width(14.dp))
                            Column(
                                modifier = Modifier.weight(1f),
                            ) {
                                Text(
                                    text = "S$menuSeason  E${ep.number}",
                                    color = if (isPlaying) Color(0xFFE50914) else Color(0xB3FFFFFF),
                                    fontSize = 15.sp,
                                    fontWeight = if (isPlaying) {
                                        androidx.compose.ui.text.font.FontWeight.Bold
                                    } else {
                                        androidx.compose.ui.text.font.FontWeight.Normal
                                    },
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = ep.title,
                                    color = Color.White,
                                    fontSize = 16.sp,
                                    maxLines = 1,
                                )
                            }
                            if (isPlaying) {
                                Text(text = "▶", color = Color.White, fontSize = 28.sp)
                            } else if (isFocused) {
                                Text(text = "▶", color = Color(0xB3FFFFFF), fontSize = 28.sp)
                            }
                        }
                    }
                }
            }
        }
    }
}
