package com.maxstream.app.ui.screens.details

import android.content.Context
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.maxstream.app.R
import com.maxstream.app.core.Constants
import com.maxstream.app.data.local.WatchEntryCompat
import com.maxstream.app.data.local.WatchlistRepository
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.remote.EpisodeRef
import com.maxstream.app.data.remote.formatReleaseDate
import com.maxstream.app.data.remote.isAirDateReleased
import com.maxstream.app.data.remote.isReleased
import com.maxstream.app.di.Modules
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.tv.isItemFullyVisible
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject

// ─────────────────────────────────────────────────────────────────────────────
// Detail data holder (mirrors _TvCinematicDetailsState fields)
// ─────────────────────────────────────────────────────────────────────────────

private data class DetailState(
    val item: MediaItem,
    val details: JSONObject?,
    val cast: List<CastEntry>,
    val recommendations: List<MediaItem>,
    val seasons: List<SeasonEntry>,
    val isSaved: Boolean,
)

private data class CastEntry(val name: String, val character: String, val profilePath: String?)
private data class SeasonEntry(val number: Int, val name: String)

// A focusable horizontal row within the details page. itemIndex is the row's
// index inside the outer LazyColumn (0 = hero, 1 = continue, 2 = seasons,
// 3 = episodes, 4 = cast, 5 = recommendations).
private data class DetailsSection(val rowId: String, val itemIndex: Int, val count: Int)

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun DetailsScreen(
    navController: NavController,
    itemId: String,
    mediaType: String = "movie",
    onReturnToSidebar: () -> Unit = {},
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var state        by remember { mutableStateOf<DetailState?>(null) }
    var episodes     by remember { mutableStateOf<List<EpisodeRef>>(emptyList()) }
    var selectedSeason by remember { mutableIntStateOf(1) }
    var loadingEpisodes by remember { mutableStateOf(false) }
    var loading      by remember { mutableStateOf(true) }
    var error        by remember { mutableStateOf<String?>(null) }

    // Continue-watching entries matching this item
    var continueWatching by remember { mutableStateOf<List<WatchEntryCompat.Entry>>(emptyList()) }

    val playFocusRequester      = remember { FocusRequester() }
    val watchlistFocusRequester = remember { FocusRequester() }

    // ── Load detail + watchlist + continue-watching ────────────────────────
    LaunchedEffect(itemId, mediaType) {
        val id = itemId.toIntOrNull() ?: run { error = "Invalid ID"; loading = false; return@LaunchedEffect }
        loading = true; error = null
        try {
            // Pull the phone's watchlist/progress so the save state and the
            // Continue Watching row match the phone (same account).
            runCatching { com.maxstream.app.data.repository.CloudSyncRepository.pullToDevice(context) }
            // Load the right endpoint directly — TMDB ids are NOT unique across
            // types, so a series id can resolve to an unrelated movie (the old
            // "try movie first, fall back to tv" made series show movie details).
            val isTv = mediaType == "tv"
            val json: JSONObject = if (isTv) {
                Modules.catalogRepository.seriesDetails(id)
            } else {
                Modules.catalogRepository.movieDetails(id)
            }

            val item = if (isTv) {
                MediaItem.fromJson(json).copy(mediaType = "tv")
            } else {
                MediaItem.fromJson(json)
            }
            val isSaved = WatchlistRepository.isIn(context, item)
            val cw = WatchEntryCompat.getEntriesFor(id, isTv)

            // Cast
            val castArr = json.optJSONObject("credits")?.optJSONArray("cast")
            val cast = if (castArr != null) {
                (0 until minOf(castArr.length(), 12)).mapNotNull { i ->
                    val p = castArr.optJSONObject(i) ?: return@mapNotNull null
                    CastEntry(
                        name = p.optString("name"),
                        character = p.optString("character"),
                        profilePath = p.optString("profile_path").ifBlank { null },
                    )
                }
            } else emptyList()

            // Recommendations / similar
            val recsArr = (json.optJSONObject("recommendations")
                ?: json.optJSONObject("similar"))?.optJSONArray("results")
            val recs = if (recsArr != null) {
                MediaItem.fromJsonList(recsArr, if (isTv) "tv" else "movie").take(12)
            } else emptyList()

            // Seasons (TV only)
            val seasons = if (isTv) {
                val arr = json.optJSONArray("seasons")
                if (arr != null) {
                    (0 until arr.length()).mapNotNull { i ->
                        val s = arr.optJSONObject(i) ?: return@mapNotNull null
                        val num = s.optInt("season_number", 0)
                        if (num <= 0) return@mapNotNull null
                        SeasonEntry(number = num, name = s.optString("name").ifBlank { "Season $num" })
                    }
                } else emptyList()
            } else emptyList()

            state = DetailState(item, json, cast, recs, seasons, isSaved)
            continueWatching = cw

            if (isTv && seasons.isNotEmpty()) {
                selectedSeason = seasons.first().number
                loadingEpisodes = true
                episodes = Modules.catalogRepository.seasonEpisodes(id, selectedSeason)
                loadingEpisodes = false
            }
        } catch (e: Exception) {
            error = e.message
        } finally {
            loading = false
        }

        // Seed focus on the hero Play button after render — first attempt is
        // IMMEDIATE, retry only while the node is unattached (no pre-delay,
        // which made Details entry feel laggy). requestFocus() is a silent
        // no-op (returns Unit) while unattached or on a disabled button, so
        // retry until the button is actually focusable (data loaded).
        delay(100)
        var attempt = 0
        while (attempt < 6) {
            if (attempt > 0) delay(50L * attempt)
            runCatching { playFocusRequester.requestFocus() }
            if (mediaType != "tv" || (!loadingEpisodes && episodes.isNotEmpty())) return@LaunchedEffect
            attempt++
        }
    }

    // Continuous inbound sync: when the phone changes the watchlist or watch
    // progress, CloudSyncCoordinator re-pulls and bumps these revisions — refresh
    // the save state + Continue Watching row to match (like the phone's
    // historyRevision/watchlistRevision notifiers).
    val historyRevision by com.maxstream.app.data.repository.CloudSyncCoordinator.historyRevision.collectAsState()
    val watchlistRevision by com.maxstream.app.data.repository.CloudSyncCoordinator.watchlistRevision.collectAsState()
    LaunchedEffect(historyRevision, watchlistRevision) {
        val s = state ?: return@LaunchedEffect
        val id = itemId.toIntOrNull() ?: return@LaunchedEffect
        val isTv = mediaType == "tv"
        val item = MediaItem.fromJson(s.details ?: return@LaunchedEffect).copy(mediaType = mediaType)
        state = s.copy(isSaved = WatchlistRepository.isIn(context, item))
        continueWatching = WatchEntryCompat.getEntriesFor(id, isTv)
    }

    // Season switch
    fun switchSeason(seasonNumber: Int) {
        if (loadingEpisodes) return
        selectedSeason = seasonNumber
        val id = itemId.toIntOrNull() ?: return
        scope.launch {
            loadingEpisodes = true
            episodes = runCatching { Modules.catalogRepository.seasonEpisodes(id, seasonNumber) }.getOrDefault(emptyList())
            loadingEpisodes = false
        }
    }

    // Watchlist toggle
    fun toggleWatchlist() {
        val s = state ?: return
        scope.launch {
            val nowSaved = WatchlistRepository.toggle(context, s.item)
            state = s.copy(isSaved = nowSaved)
            // Keep the phone in sync: add/remove the Firestore doc.
            if (nowSaved) {
                com.maxstream.app.data.repository.CloudSyncRepository.pushWatchlist(context, s.item)
            } else {
                com.maxstream.app.data.repository.CloudSyncRepository.deleteWatchlist(
                    context, s.item.id.toString(), s.item.mediaType,
                )
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Background)) {
        when {
            loading -> CircularProgressIndicator(
                color = com.maxstream.app.ui.theme.Primary,
                modifier = Modifier.align(Alignment.Center),
            )
            error != null -> Text(
                text = "Error: $error",
                color = Color(0xFFCF6679),
                modifier = Modifier.align(Alignment.Center),
            )
            state != null -> {
                val s = state!!
                AnimatedVisibility(
                    visible = true,
                    enter = fadeIn(tween(320)),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    TvCinematicDetailsView(
                        state = s,
                        episodes = episodes,
                        selectedSeason = selectedSeason,
                        loadingEpisodes = loadingEpisodes,
                        continueWatching = continueWatching,
                        playFocusRequester = playFocusRequester,
                        watchlistFocusRequester = watchlistFocusRequester,
                        navController = navController,
                        onSeasonSelected = { n -> switchSeason(n) },
                        onWatchlistToggle = { toggleWatchlist() },
                        onPlay = { episode ->
                            val route = if (s.item.mediaType == "tv")
                                Screen.Player.createRoute(s.item.id.toString(), "tv",
                                    season = selectedSeason,
                                    episode = episode?.number ?: 1)
                            else
                                Screen.Player.createRoute(s.item.id.toString(), "movie")
                            navController.navigate(route)
                        },
                        onResume = { season, episode ->
                            navController.navigate(
                                Screen.Player.createRoute(
                                    s.item.id.toString(), s.item.mediaType,
                                    season = season, episode = episode,
                                )
                            )
                        },
                        onReturnToSidebar = onReturnToSidebar,
                    )
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main view — mirrors TvCinematicDetails._build* methods
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun TvCinematicDetailsView(
    state: DetailState,
    episodes: List<EpisodeRef>,
    selectedSeason: Int,
    loadingEpisodes: Boolean,
    continueWatching: List<WatchEntryCompat.Entry>,
    playFocusRequester: FocusRequester,
    watchlistFocusRequester: FocusRequester,
    navController: NavController,
    onSeasonSelected: (Int) -> Unit,
    onWatchlistToggle: () -> Unit,
    onPlay: (EpisodeRef?) -> Unit,
    onResume: (Int, Int) -> Unit,
    onReturnToSidebar: () -> Unit,
) {
    val item    = state.item
    val details = state.details
    val isTv    = item.mediaType == "tv"
    val backdrop = item.backdropUrl.ifEmpty { item.posterUrl }

    // Build metadata string — matches Dart: rating • year • runtime • genres
    val genresFromDetails = details?.optJSONArray("genres")?.let { arr ->
        (0 until minOf(arr.length(), 3)).mapNotNull { arr.optJSONObject(it)?.optString("name") }
    } ?: emptyList()
    val year = details?.let {
        (it.optString("release_date").ifBlank { it.optString("first_air_date") }).take(4)
    }.orEmpty()
    val runtime = details?.optInt("runtime", 0).takeIf { (it ?: 0) > 0 }
    val seasonCount = state.seasons.size.takeIf { it > 0 }
    val metadata = buildList<String> {
        if (item.voteAverage > 0) add("★ ${String.format("%.1f", item.voteAverage)}")
        if (year.isNotEmpty()) add(year)
        if (runtime != null) add("${runtime}m")
        if (isTv && seasonCount != null) add("$seasonCount Season${if (seasonCount != 1) "s" else ""}")
        addAll(genresFromDetails)
    }.joinToString("  •  ")

    // Production / air status (mirrors mobile's buildInfoRow('Status', ...)):
    //  • TV series: "Returning Series" / "Ended" / "Canceled"
    //  • Movies: "Released" vs "To be released on <date>" vs "Post Production"
    val statusText: String?
    val statusColor: Color
    if (isTv) {
        val raw = details?.optString("status").orEmpty().ifBlank { null }
        statusText = when (raw) {
            "Canceled" -> "Cancelled"
            else -> raw
        }
        statusColor = when (raw) {
            "Returning Series" -> Color(0xFF3FB950)
            "Ended" -> Color(0xFF9AA0A6)
            "Canceled" -> Color(0xFFE5534B)
            else -> Color(0xFF9AA0A6)
        }
    } else {
        val raw = details?.optString("status").orEmpty().ifBlank { null }
        val rd = details?.optString("release_date").orEmpty()
        statusText = when {
            raw == "Post Production" -> "Post Production"
            rd.isNotBlank() && !isAirDateReleased(rd) -> "To be released on ${formatReleaseDate(rd)}"
            raw == "Released" -> "Released"
            rd.isNotBlank() -> "Released"
            else -> raw
        }
        statusColor = when {
            raw == "Post Production" -> Color(0xFFD29922)
            rd.isNotBlank() && !isAirDateReleased(rd) -> Color(0xFFD29922)
            else -> Color(0xFF3FB950)
        }
    }

    // Play button label — matches Dart: "Watch S1E1" for series
    val playLabel = if (isTv) {
        if (loadingEpisodes) "Loading…"
        else "Watch S${selectedSeason}E${episodes.firstOrNull()?.number ?: 1}"
    } else "Play"

    // ── Section navigation (mirrors Dart's FocusTraversalGroup + ensureVisible) ──
    // Sections are the outer LazyColumn items in fixed order:
    //   0 = hero, 1 = continue, 2 = seasons, 3 = episodes, 4 = cast, 5 = recs.
    // Each focusable row owns a per-card FocusRequester and its LazyListState,
    // so UP/DOWN/LEFT/RIGHT scroll-then-focus like the Home rows.
    val scope = rememberCoroutineScope()
    val outerListState = rememberLazyListState()
    val tileRequesters = remember { mutableMapOf<String, FocusRequester>() }
    val rowStates = remember { mutableMapOf<String, LazyListState>() }

    // In-flight focus move. Cancelled before every new move so rapid D-pad
    // presses never queue up stale scroll+focus jobs that fight each other
    // (mirrors GridNavState.moveTo used by the watchlist grid).
    val focusJob = remember { mutableStateOf<Job?>(null) }

    fun launchFocus(block: suspend () -> Unit) {
        focusJob.value?.cancel()
        focusJob.value = scope.launch { block() }
    }

    val sections = buildList {
        // Real LazyColumn item indices (hero = 0), incremented in the SAME order
        // the items are emitted below. The old hardcoded 1/2/3/4/5 were wrong
        // whenever "Continue Watching" was absent, so focusing a section scrolled
        // to the wrong item and the tiles were never composed.
        var next = 1
        if (continueWatching.isNotEmpty()) add(DetailsSection("details:continue", next++, continueWatching.size))
        if (isTv && state.seasons.isNotEmpty()) add(DetailsSection("details:seasons", next++, state.seasons.size))
        if (isTv) {
            // Episodes item is ALWAYS emitted for TV (spinner while loading) —
            // reserve its slot even when there is nothing navigable yet.
            if (!loadingEpisodes && episodes.isNotEmpty()) {
                add(DetailsSection("details:episodes", next++, episodes.size))
            } else {
                next++
            }
        }
        if (state.cast.isNotEmpty()) add(DetailsSection("details:cast", next++, state.cast.size))
        if (state.recommendations.isNotEmpty()) add(DetailsSection("details:recommendations", next++, state.recommendations.size))
    }

    fun requester(rowId: String, index: Int): FocusRequester =
        tileRequesters.getOrPut("$rowId:$index") { FocusRequester() }

    fun sectionIndexOf(rowId: String): Int = sections.firstOrNull { it.rowId == rowId }?.itemIndex ?: 1

    suspend fun focusTile(rowId: String, requestedIndex: Int, itemIndex: Int, count: Int) {
        if (count <= 0) return
        val index = requestedIndex.coerceIn(0, count - 1)
        val target = requester(rowId, index)
        val rowState = rowStates[rowId]
        // Reveal the section and tile ONLY when they are not fully visible.
        // Snapping via scrollToItem on every move — even between fully-visible
        // tiles — jumped the rows back and forth on LEFT/RIGHT (the "bounce").
        if (!outerListState.isItemFullyVisible(itemIndex)) {
            runCatching { outerListState.scrollToItem(itemIndex) }
        }
        if (rowState != null && !rowState.isItemFullyVisible(index)) {
            runCatching { rowState.scrollToItem(index) }
        }
        // requestFocus() is a silent no-op (returns Unit) while the node is not
        // attached — no success value to test. The tile is composed once
        // scrollToItem has awaited layout, so this single call lands; retries
        // only guard the rare case where the scroll silently failed.
        var attempt = 0
        while (attempt < 4) {
            if (attempt > 0) delay(30L * attempt)
            runCatching { target.requestFocus() }
            val composed = rowState?.layoutInfo?.visibleItemsInfo?.any { it.index == index } ?: true
            if (composed) break
            attempt++
        }
    }

    fun focusSection(rowId: String) {
        val section = sections.firstOrNull { it.rowId == rowId } ?: return
        launchFocus { focusTile(rowId, 0, section.itemIndex, section.count) }
    }

    fun focusHero() {
        launchFocus {
            if (!outerListState.isItemFullyVisible(0)) {
                runCatching { outerListState.scrollToItem(0) }
            }
            // Hero is LazyColumn item 0 — composed once visible, so a single
            // requestFocus() lands (it no-ops silently while unattached).
            runCatching { playFocusRequester.requestFocus() }
        }
    }

    fun focusFirstSection() {
        sections.firstOrNull { it.count > 0 }?.let { focusSection(it.rowId) }
    }

    fun focusPrevSection(itemIndex: Int) {
        val target = sections.filter { it.itemIndex < itemIndex && it.count > 0 }.maxByOrNull { it.itemIndex }
        if (target != null) focusSection(target.rowId) else focusHero()
    }

    fun focusNextSection(itemIndex: Int) {
        sections.filter { it.itemIndex > itemIndex && it.count > 0 }.minByOrNull { it.itemIndex }?.let {
            focusSection(it.rowId)
        }
    }

    fun onTileKey(rowId: String, itemIndex: Int, count: Int, index: Int, event: KeyEvent): Boolean {
        if (event.type != KeyEventType.KeyDown) return false
        return when (event.key) {
            Key.DirectionLeft -> {
                if (index > 0) launchFocus { focusTile(rowId, index - 1, itemIndex, count) }
                else focusHero()
                true
            }
            Key.DirectionRight -> {
                if (index + 1 < count) launchFocus { focusTile(rowId, index + 1, itemIndex, count) }
                true
            }
            Key.DirectionUp -> { focusPrevSection(itemIndex); true }
            Key.DirectionDown -> { focusNextSection(itemIndex); true }
            Key.Back, Key.Escape -> { onReturnToSidebar(); true }
            else -> false
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            // Back/Escape pops back to the previous screen (deep nav stack).
            .onKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown &&
                    (event.key == Key.Back || event.key == Key.Escape)
                ) {
                    onReturnToSidebar(); true
                } else false
            }
    ) {
        // Backdrop
        AsyncImage(
            model = backdrop,
            contentDescription = item.title,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop,
        )
        // Left horizontal gradient
        Box(modifier = Modifier.fillMaxSize().background(
            Brush.horizontalGradient(
                listOf(Color(0xFF090909), Color(0xDD090909), Color.Transparent),
                startX = 0f, endX = 1200f,
            )
        ))
        // Bottom vertical gradient
        Box(modifier = Modifier.fillMaxSize().background(
            Brush.verticalGradient(
                colorStops = arrayOf(0f to Color.Transparent, 0.72f to Color(0x33090909), 1f to Color(0xFF090909)),
            )
        ))

        // Scrollable content
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            state = outerListState,
            contentPadding = PaddingValues(bottom = 64.dp),
        ) {
            // ── Hero ───────────────────────────────────────────────────────
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(550.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth(0.6f)
                            .align(Alignment.BottomStart)
                            .padding(start = 54.dp, bottom = 42.dp),
                    ) {
                        Text(
                            text = item.title,
                            color = Color.White,
                            fontSize = 42.sp,
                            fontWeight = FontWeight.W800,
                            lineHeight = 46.sp,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Spacer(Modifier.height(12.dp))
                        Text(text = metadata, color = Color.White.copy(alpha = 0.7f), fontSize = 15.sp)
                        if (statusText != null) {
                            Spacer(Modifier.height(8.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(9.dp)
                                        .background(statusColor, CircleShape),
                                )
                                Spacer(Modifier.width(8.dp))
                                Text(
                                    text = statusText,
                                    color = statusColor,
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.W600,
                                )
                            }
                        }
                        Spacer(Modifier.height(14.dp))
                        val overview = details?.optString("overview").orEmpty().ifBlank { item.overview }
                        if (overview.isNotBlank()) {
                            Text(
                                text = overview,
                                color = Color(0xFFDDDDDD),
                                fontSize = 15.sp,
                                lineHeight = 22.sp,
                                maxLines = 7,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                        Spacer(Modifier.height(20.dp))

                        // ── Buttons ────────────────────────────────────────
                        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            CinematicButton(
                                label = playLabel,
                                iconRes = R.drawable.ic_play,
                                primary = true,
                                enabled = !isTv || (!loadingEpisodes && episodes.isNotEmpty()),
                                focusRequester = playFocusRequester,
                                onKeyLeft = { /* nothing left of Play — consume */ },
                                onKeyRight = { runCatching { watchlistFocusRequester.requestFocus() } },
                                onKeyUp = { /* at top — consume */ },
                                onKeyDown = { focusFirstSection() },
                                onClick = { onPlay(if (isTv) episodes.firstOrNull() else null) },
                            )
                            CinematicButton(
                                label = if (state.isSaved) "In Watchlist" else "Watchlist",
                                iconRes = if (state.isSaved) R.drawable.ic_watchlist else R.drawable.ic_watchlist,
                                primary = false,
                                focusRequester = watchlistFocusRequester,
                                onKeyLeft = { runCatching { playFocusRequester.requestFocus() } },
                                onKeyRight = { /* nothing right of Watchlist — consume */ },
                                onKeyUp = { /* at top — consume */ },
                                onKeyDown = { focusFirstSection() },
                                onClick = onWatchlistToggle,
                            )
                        }
                    }
                }
            }

            // ── Continue watching ──────────────────────────────────────────
            if (continueWatching.isNotEmpty()) {
                item {
                    CinematicSection(title = "Continue Watching", height = 240.dp) {
                        val rowId = "details:continue"
                        val rowListState = rememberLazyListState()
                        LaunchedEffect(rowId, rowListState) { rowStates[rowId] = rowListState }
                        var focusedIdx by remember { mutableIntStateOf(-1) }
                        LazyRow(
                            state = rowListState,
                            contentPadding = PaddingValues(end = 54.dp),
                            horizontalArrangement = Arrangement.spacedBy(18.dp),
                        ) {
                            items(continueWatching.size) { i ->
                                val cw = continueWatching[i]
                                TvTile(
                                    isFocused = focusedIdx == i,
                                    onFocused = { focusedIdx = i },
                                    focusRequester = requester(rowId, i),
                                    onKeyEvent = { onTileKey(rowId, sectionIndexOf(rowId), continueWatching.size, i, it) },
                                    onPress = { onResume(cw.season, cw.episode) },
                                ) {
                                    ContinueWatchingCard(entry = cw, isTv = isTv)
                                }
                            }
                        }
                    }
                }
            }

            // ── Seasons (TV only) ──────────────────────────────────────────
            if (isTv && state.seasons.isNotEmpty()) {
                item {
                    CinematicSection(title = "Seasons", height = 52.dp) {
                        val rowId = "details:seasons"
                        val rowListState = rememberLazyListState()
                        LaunchedEffect(rowId, rowListState) { rowStates[rowId] = rowListState }
                        var focusedSeason by remember { mutableIntStateOf(-1) }
                        LazyRow(
                            state = rowListState,
                            contentPadding = PaddingValues(end = 54.dp),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            items(state.seasons.size) { i ->
                                val s = state.seasons[i]
                                TvTile(
                                    isFocused = focusedSeason == i,
                                    isSelected = s.number == selectedSeason,
                                    onFocused = { focusedSeason = i },
                                    focusRequester = requester(rowId, i),
                                    onKeyEvent = { onTileKey(rowId, sectionIndexOf(rowId), state.seasons.size, i, it) },
                                    onPress = { onSeasonSelected(s.number) },
                                ) {
                                    Text(
                                        text = s.name,
                                        color = Color.White,
                                        fontSize = 14.sp,
                                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 11.dp),
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // ── Episodes (TV only) ─────────────────────────────────────────
            if (isTv) {
                item {
                    CinematicSection(title = "Episodes", height = 190.dp) {
                        if (loadingEpisodes) {
                            CircularProgressIndicator(color = Color(0xFFE50914), modifier = Modifier.padding(16.dp))
                        } else {
                            val rowId = "details:episodes"
                            val rowListState = rememberLazyListState()
                            LaunchedEffect(rowId, rowListState) { rowStates[rowId] = rowListState }
                            var focusedEp by remember { mutableIntStateOf(-1) }
                            LazyRow(
                                state = rowListState,
                                contentPadding = PaddingValues(end = 54.dp),
                                horizontalArrangement = Arrangement.spacedBy(16.dp),
                            ) {
                                items(episodes.size) { i ->
                                    val ep = episodes[i]
                                    TvTile(
                                        isFocused = focusedEp == i,
                                        onFocused = { focusedEp = i },
                                        focusRequester = requester(rowId, i),
                                        onKeyEvent = { onTileKey(rowId, sectionIndexOf(rowId), episodes.size, i, it) },
                                        onPress = { if (ep.isReleased()) onPlay(ep) },
                                    ) {
                                        EpisodeTileContent(ep)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Cast ───────────────────────────────────────────────────────
            if (state.cast.isNotEmpty()) {
                item {
                    CinematicSection(title = "Cast", height = 150.dp) {
                        val rowId = "details:cast"
                        val rowListState = rememberLazyListState()
                        LaunchedEffect(rowId, rowListState) { rowStates[rowId] = rowListState }
                        var focusedCast by remember { mutableIntStateOf(-1) }
                        LazyRow(
                            state = rowListState,
                            contentPadding = PaddingValues(end = 54.dp),
                            horizontalArrangement = Arrangement.spacedBy(18.dp),
                        ) {
                            items(state.cast.size) { i ->
                                val person = state.cast[i]
                                TvTile(
                                    isFocused = focusedCast == i,
                                    onFocused = { focusedCast = i },
                                    focusRequester = requester(rowId, i),
                                    onKeyEvent = { onTileKey(rowId, sectionIndexOf(rowId), state.cast.size, i, it) },
                                    onPress = { /* cast detail */ },
                                ) {
                                    CastCard(person = person)
                                }
                            }
                        }
                    }
                }
            }

            // ── More Like This (recommendations) ──────────────────────────
            if (state.recommendations.isNotEmpty()) {
                item {
                    CinematicSection(title = "More Like This", height = 260.dp) {
                        val rowId = "details:recommendations"
                        val rowListState = rememberLazyListState()
                        LaunchedEffect(rowId, rowListState) { rowStates[rowId] = rowListState }
                        var focusedRec by remember { mutableIntStateOf(-1) }
                        LazyRow(
                            state = rowListState,
                            contentPadding = PaddingValues(end = 54.dp),
                            horizontalArrangement = Arrangement.spacedBy(18.dp),
                        ) {
                            items(state.recommendations.size) { i ->
                                val rec = state.recommendations[i]
                                TvTile(
                                    isFocused = focusedRec == i,
                                    onFocused = { focusedRec = i },
                                    focusRequester = requester(rowId, i),
                                    onKeyEvent = { onTileKey(rowId, sectionIndexOf(rowId), state.recommendations.size, i, it) },
                                    onPress = {
                                        navController.navigate(Screen.Details.createRoute(rec.id.toString(), rec.mediaType))
                                    },
                                ) {
                                    RecommendationCard(item = rec)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// TvTile — matches Dart _TvTile: scale + border on focus, selected highlight
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun TvTile(
    isFocused: Boolean,
    onFocused: () -> Unit,
    onPress: () -> Unit,
    isSelected: Boolean = false,
    focusRequester: FocusRequester = remember { FocusRequester() },
    onKeyEvent: (KeyEvent) -> Boolean = { false },
    content: @Composable () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.02f else 1f,
        animationSpec = tween(180),
        label = "tileScale",
    )

    val borderColor = when {
        isFocused  -> Color.White
        isSelected -> Color(0xFFE50914)
        else       -> Color.Transparent
    }
    val bgColor = when {
        isSelected -> Color(0x44E50914)
        else       -> Color.Transparent
    }

    Box(
        modifier = Modifier
            .scale(scale)
            .clip(RoundedCornerShape(10.dp))
            .background(bgColor)
            .border(2.dp, borderColor, RoundedCornerShape(10.dp))
            .focusRequester(focusRequester)
            .onFocusChanged { state -> if (state.hasFocus) onFocused() }
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                if (onKeyEvent(event)) return@onKeyEvent true
                when (event.key) {
                    Key.Enter, Key.DirectionCenter -> { onPress(); true }
                    else -> false
                }
            }
            .clickable(onClick = onPress)
            .padding(2.dp),
    ) {
        content()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// CinematicButton (matches Dart _TvButton)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun CinematicButton(
    label: String,
    iconRes: Int,
    primary: Boolean,
    enabled: Boolean = true,
    focusRequester: FocusRequester,
    onKeyLeft: () -> Unit,
    onKeyRight: () -> Unit,
    onKeyUp: () -> Unit = {},
    onKeyDown: () -> Unit = {},
    onClick: () -> Unit,
) {
    var isFocused by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.03f else 1f,
        animationSpec = tween(180),
        label = "btnScale",
    )

    val bgColor = when {
        !enabled  -> Color(0x88333333)
        primary   -> Color(0xFFE50914)
        else      -> Color(0xBB222222)
    }

    Row(
        modifier = Modifier
            .scale(scale)
            .clip(RoundedCornerShape(8.dp))
            .background(bgColor)
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(8.dp),
            )
            .focusRequester(focusRequester)
            .onFocusChanged { state -> isFocused = state.hasFocus }
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionLeft  -> { onKeyLeft(); true }
                    Key.DirectionRight -> { onKeyRight(); true }
                    Key.DirectionUp    -> { onKeyUp(); true }
                    Key.DirectionDown  -> { onKeyDown(); true }
                    Key.Enter, Key.DirectionCenter -> { if (enabled) onClick(); true }
                    else -> false
                }
            }
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 24.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            painter = painterResource(iconRes),
            contentDescription = null,
            tint = if (enabled) Color.White else Color.White.copy(alpha = 0.38f),
            modifier = Modifier.size(20.dp),
        )
        Text(
            text = label,
            color = if (enabled) Color.White else Color.White.copy(alpha = 0.38f),
            fontSize = 16.sp,
            fontWeight = FontWeight.W700,
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section wrapper (matches Dart _section)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun CinematicSection(title: String, height: Dp, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .padding(top = 26.dp)
            .padding(start = 54.dp),
    ) {
        Text(
            text = title,
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.W700,
            modifier = Modifier.padding(bottom = 14.dp),
        )
        Box(modifier = Modifier.height(height)) {
            content()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card sub-composables
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun EpisodeTileContent(episode: EpisodeRef) {
    val released = episode.isReleased()
    val stillUrl = episode.stillPath?.let { "${Constants.TMDB_IMAGE_BASE}/w500$it" }.orEmpty()
    Column(modifier = Modifier.width(286.dp).fillMaxHeight()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xFF242424)),
        ) {
            if (stillUrl.isNotEmpty()) {
                AsyncImage(
                    model = stillUrl,
                    contentDescription = episode.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            } else {
                Icon(
                    painter = painterResource(R.drawable.ic_play),
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.4f),
                    modifier = Modifier.align(Alignment.Center).size(40.dp),
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = "E${episode.number}  ${episode.title}",
            color = if (released) Color.White else Color.White.copy(alpha = 0.45f),
            fontWeight = FontWeight.W600,
            fontSize = 13.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (!released && episode.airDate.isNotBlank()) {
            Text(
                text = "To be released on ${formatReleaseDate(episode.airDate)}",
                color = Color(0xFFF5B81B),
                fontSize = 12.sp,
                maxLines = 1,
            )
        } else if (episode.overview.isNotBlank()) {
            Text(
                text = episode.overview,
                color = Color.White.copy(alpha = 0.54f),
                fontSize = 12.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 16.sp,
            )
        }
    }
}

@Composable
private fun CastCard(person: CastEntry) {
    val profileUrl = person.profilePath?.let { "${Constants.TMDB_IMAGE_BASE}/w185$it" }.orEmpty()
    Column(
        modifier = Modifier.width(105.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(92.dp)
                .clip(CircleShape)
                .background(Color(0xFF242424)),
            contentAlignment = Alignment.Center,
        ) {
            if (profileUrl.isNotEmpty()) {
                AsyncImage(
                    model = profileUrl,
                    contentDescription = person.name,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            } else {
                Icon(
                    painter = painterResource(R.drawable.ic_home), // person placeholder
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.4f),
                    modifier = Modifier.size(40.dp),
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = person.name,
            color = Color.White,
            fontSize = 12.sp,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun RecommendationCard(item: MediaItem) {
    Column(
        modifier = Modifier.width(150.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(RoundedCornerShape(9.dp))
                .background(Color(0xFF242424)),
        ) {
            if (item.posterUrl.isNotEmpty()) {
                AsyncImage(
                    model = item.posterUrl,
                    contentDescription = item.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = item.title,
            color = Color.White,
            fontSize = 13.sp,
            fontWeight = FontWeight.W600,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun ContinueWatchingCard(entry: WatchEntryCompat.Entry, isTv: Boolean) {
    val title = if (isTv) {
        val base = "S${entry.season} E${entry.episode}"
        if (entry.episodeName.isNotEmpty()) "$base  ${entry.episodeName}" else base
    } else entry.title
    Column(
        modifier = Modifier
            .width(286.dp)
            .fillMaxHeight(),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xFF242424)),
        ) {
            if (entry.posterUrl.isNotEmpty()) {
                AsyncImage(
                    model = entry.posterUrl,
                    contentDescription = title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            }
            // Progress bar
            val progress = entry.progress
            if (progress > 0f) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .height(4.dp)
                        .padding(horizontal = 8.dp)
                ) {
                    Box(Modifier.fillMaxSize().clip(RoundedCornerShape(2.dp)).background(Color.White.copy(alpha = 0.24f)))
                    Box(Modifier.fillMaxWidth(progress).fillMaxSize().clip(RoundedCornerShape(2.dp)).background(Color(0xFFE50914)))
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(text = title, color = Color.White, fontWeight = FontWeight.W600, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Spacer(Modifier.height(4.dp))
        Icon(painter = painterResource(R.drawable.ic_play), contentDescription = null, tint = Color(0xFFE50914), modifier = Modifier.size(20.dp))
    }
}

// end of DetailsScreen.kt
