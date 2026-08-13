package com.maxstream.app.ui.screens.series

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.maxstream.app.R
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.remote.EpisodeRef
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.viewmodel.HomeViewModel
import com.maxstream.app.ui.viewmodel.SeriesViewModel

@Composable
fun SeriesScreen(
    navController: NavController,
    itemId: String,
    onReturnToSidebar: () -> Unit = {},
) {
    val seriesViewModel: SeriesViewModel = viewModel()
    val homeViewModel: HomeViewModel = viewModel()

    val series       = seriesViewModel.series.value
    val seasons      = seriesViewModel.seasons.value.orEmpty()
    val episodes     = seriesViewModel.episodes.value.orEmpty()
    val loading      = seriesViewModel.loading.value ?: false
    val error        = seriesViewModel.error.value
    val trendingSeries  = homeViewModel.trendingSeries.value.orEmpty()
    val popularMovies   = homeViewModel.popularMovies.value.orEmpty()

    var selectedSeason  by remember { mutableIntStateOf(1) }
    var isEntryVisible  by remember { mutableStateOf(false) }

    val playFocusRequester = remember { FocusRequester() }

    LaunchedEffect(itemId) {
        val id = itemId.toIntOrNull() ?: return@LaunchedEffect
        seriesViewModel.loadSeries(id)
        kotlinx.coroutines.delay(80)
        isEntryVisible = true
        // Seed focus on Play button after brief layout delay
        kotlinx.coroutines.delay(80)
        runCatching { playFocusRequester.requestFocus() }
    }

    LaunchedEffect(seasons) {
        if (seasons.isNotEmpty() && selectedSeason !in seasons) {
            selectedSeason = seasons.first()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Background)) {
        if (loading && series == null) {
            CircularProgressIndicator(
                color = com.maxstream.app.ui.theme.Primary,
                modifier = Modifier.align(Alignment.Center),
            )
            return@Box
        }

        series?.let { mediaItem ->
            AnimatedVisibility(
                visible = isEntryVisible,
                enter = fadeIn(tween(330)),
                exit  = fadeOut(tween(180)),
            ) {
                SeriesDetailsView(
                    series = mediaItem,
                    navController = navController,
                    seasons = seasons,
                    episodes = episodes,
                    selectedSeason = selectedSeason,
                    loading = loading,
                    error = error,
                    trendingSeries = trendingSeries,
                    popularMovies = popularMovies,
                    playFocusRequester = playFocusRequester,
                    onSeasonSelected = { season ->
                        selectedSeason = season
                        seriesViewModel.selectSeason(season)
                    },
                    onPlayEpisode = { episode ->
                        navController.navigate(
                            Screen.Player.createRoute(
                                mediaItem.id.toString(), "tv",
                                season = selectedSeason,
                                episode = episode.number,
                            )
                        )
                    },
                    onReturnToSidebar = onReturnToSidebar,
                )
            }
        } ?: run {
            if (!loading) {
                Text(
                    text = "Series not found",
                    color = Color.White.copy(alpha = 0.6f),
                    modifier = Modifier.align(Alignment.Center),
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Details view
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SeriesDetailsView(
    series: MediaItem,
    navController: NavController,
    seasons: List<Int>,
    episodes: List<EpisodeRef>,
    selectedSeason: Int,
    loading: Boolean,
    error: String?,
    trendingSeries: List<MediaItem>,
    popularMovies: List<MediaItem>,
    playFocusRequester: FocusRequester,
    onSeasonSelected: (Int) -> Unit,
    onPlayEpisode: (EpisodeRef) -> Unit,
    onReturnToSidebar: () -> Unit,
) {
    val backdropUrl = series.backdropUrl.ifEmpty { series.posterUrl }
    val year   = series.releaseDate.take(4).toIntOrNull() ?: 0
    val rating = series.voteAverage

    val detailsFocusRequester = remember { FocusRequester() }

    Box(modifier = Modifier.fillMaxSize()) {
        // ── Backdrop ───────────────────────────────────────────────────────
        AsyncImage(
            model = backdropUrl,
            contentDescription = series.title,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop,
        )
        Box(
            modifier = Modifier.fillMaxSize().background(
                Brush.horizontalGradient(
                    listOf(Color.Black, Color(0xD9000000), Color.Transparent),
                    startX = 0f, endX = 1200f,
                )
            )
        )
        Box(
            modifier = Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    listOf(Color.Transparent, Color.Transparent, Color(0xFF0F0F0F)),
                    startY = 0f, endY = 400f,
                )
            )
        )

        // ── Scrollable content ─────────────────────────────────────────────
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            state = rememberLazyListState(),
            contentPadding = PaddingValues(bottom = 64.dp),
        ) {
            // ── Hero info block ────────────────────────────────────────────
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 240.dp)
                        .padding(horizontal = 48.dp, vertical = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        text = series.title,
                        color = Color.White,
                        fontSize = 42.sp,
                        fontWeight = FontWeight.ExtraBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.fillMaxWidth(0.7f),
                    )
                    val meta = buildString {
                        if (rating > 0) append(String.format("★ %.1f  ", rating))
                        if (year > 0) append(year)
                        append("  •  TV Series")
                    }
                    Text(text = meta, color = Color.White.copy(alpha = 0.7f), fontSize = 15.sp)
                    if (series.overview.isNotBlank()) {
                        Text(
                            text = series.overview,
                            color = Color(0xFFD8D8D8),
                            fontSize = 15.sp,
                            lineHeight = 24.sp,
                            maxLines = 5,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.fillMaxWidth(0.8f),
                        )
                    }

                    Spacer(Modifier.height(8.dp))

                    // Buttons — key handlers on the buttons themselves
                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        androidx.compose.material3.Button(
                            onClick = { if (episodes.isNotEmpty()) onPlayEpisode(episodes.first()) },
                            modifier = Modifier
                                .focusRequester(playFocusRequester)
                                .onKeyEvent { event ->
                                    if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                                    when (event.key) {
                                        Key.DirectionLeft  -> { onReturnToSidebar(); true }
                                        Key.DirectionRight -> { runCatching { detailsFocusRequester.requestFocus() }; true }
                                        else -> false
                                    }
                                },
                            colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                                containerColor = Color(0xFFE50914)
                            ),
                        ) {
                            Icon(
                                painter = painterResource(R.drawable.ic_play),
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.play))
                        }

                        androidx.compose.material3.OutlinedButton(
                            onClick = { },
                            modifier = Modifier
                                .focusRequester(detailsFocusRequester)
                                .onKeyEvent { event ->
                                    if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                                    when (event.key) {
                                        Key.DirectionLeft -> { runCatching { playFocusRequester.requestFocus() }; true }
                                        else -> false
                                    }
                                },
                        ) {
                            Icon(
                                painter = painterResource(R.drawable.ic_info),
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.details))
                        }
                    }
                }
            }

            // ── Season chips ───────────────────────────────────────────────
            if (seasons.isNotEmpty()) {
                item {
                    SeriesSection(title = "Seasons") {
                        val seasonFocusRequesters = remember(seasons) { seasons.map { FocusRequester() } }
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 48.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            items(seasons.size) { idx ->
                                val season = seasons[idx]
                                SeriesChip(
                                    label = "Season $season",
                                    isSelected = season == selectedSeason,
                                    focusRequester = seasonFocusRequesters[idx],
                                    onSelect = { onSeasonSelected(season) },
                                    onMoveLeft = {
                                        if (idx == 0) runCatching { playFocusRequester.requestFocus() }
                                        else seasonFocusRequesters[idx - 1].requestFocus()
                                    },
                                    onMoveRight = {
                                        if (idx < seasons.lastIndex)
                                            seasonFocusRequesters[idx + 1].requestFocus()
                                    },
                                )
                            }
                        }
                    }
                }
            }

            // ── Episodes ───────────────────────────────────────────────────
            item {
                SeriesSection(title = "Episodes") {
                    if (loading) {
                        CircularProgressIndicator(
                            color = com.maxstream.app.ui.theme.Primary,
                            modifier = Modifier.padding(16.dp),
                        )
                    } else if (error != null) {
                        Text(text = "Error loading episodes", color = Color(0xFFCF6679))
                    } else {
                        val episodeFocusRequesters = remember(episodes) { episodes.map { FocusRequester() } }
                        var focusedEpIndex by remember { mutableIntStateOf(-1) }

                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 48.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            items(episodes.size) { idx ->
                                val ep = episodes[idx]
                                EpisodeCard(
                                    episode = ep,
                                    isFocused = focusedEpIndex == idx,
                                    focusRequester = episodeFocusRequesters[idx],
                                    onFocused = { focusedEpIndex = idx },
                                    onPlay = { onPlayEpisode(ep) },
                                    onMoveLeft = {
                                        if (idx == 0) runCatching { playFocusRequester.requestFocus() }
                                        else episodeFocusRequesters[idx - 1].requestFocus()
                                    },
                                    onMoveRight = {
                                        if (idx < episodes.lastIndex)
                                            episodeFocusRequesters[idx + 1].requestFocus()
                                    },
                                )
                            }
                        }
                    }
                }
            }

            // ── More content rows ──────────────────────────────────────────
            if (trendingSeries.isNotEmpty()) {
                item {
                    SeriesSection(title = stringResource(R.string.trending_series)) {
                        var focusedIdx by remember { mutableIntStateOf(-1) }
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 48.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            items(trendingSeries.take(10)) { s ->
                                val i = trendingSeries.indexOf(s)
                                ContentCard(
                                    posterUrl = s.posterUrl, title = s.title,
                                    rating = s.voteAverage.takeIf { it > 0 },
                                    isFocused = focusedIdx == i,
                                    onFocusChanged = { f -> if (f) focusedIdx = i else if (focusedIdx == i) focusedIdx = -1 },
                                    onClick = { navController.navigate(Screen.Series.createRoute(s.id.toString())) },
                                    modifier = Modifier.height(180.dp),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SeriesSection(title: String, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .padding(top = 28.dp)
            .padding(horizontal = 48.dp),
    ) {
        Text(
            text = title,
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 14.dp),
        )
        content()
    }
}

@Composable
private fun SeriesChip(
    label: String,
    isSelected: Boolean,
    focusRequester: FocusRequester,
    onSelect: () -> Unit,
    onMoveLeft: () -> Unit,
    onMoveRight: () -> Unit,
) {
    var isFocused by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(
                when {
                    isSelected -> Color.White
                    isFocused  -> Color(0xFF3A3A3A)
                    else       -> Color.White.copy(alpha = 0.12f)
                }
            )
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(8.dp),
            )
            .focusRequester(focusRequester)
            .focusable()
            .onFocusChanged { state -> isFocused = state.hasFocus }
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionLeft  -> { onMoveLeft(); true }
                    Key.DirectionRight -> { onMoveRight(); true }
                    Key.Enter, Key.DirectionCenter -> { onSelect(); true }
                    else -> false
                }
            }
            .clickable(onClick = onSelect)
            .padding(horizontal = 20.dp, vertical = 10.dp),
    ) {
        Text(
            text = label,
            color = if (isSelected) Color.Black else Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun EpisodeCard(
    episode: EpisodeRef,
    isFocused: Boolean,
    focusRequester: FocusRequester,
    onFocused: () -> Unit,
    onPlay: () -> Unit,
    onMoveLeft: () -> Unit,
    onMoveRight: () -> Unit,
) {
    Column(
        modifier = Modifier
            .width(200.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(if (isFocused) Color(0xFF2A2A2A) else Color(0xFF1E1E1E))
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(10.dp),
            )
            .focusRequester(focusRequester)
            .focusable()
            .onFocusChanged { state ->
                if (state.hasFocus) onFocused()
            }
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionLeft  -> { onMoveLeft(); true }
                    Key.DirectionRight -> { onMoveRight(); true }
                    Key.Enter, Key.DirectionCenter -> { onPlay(); true }
                    else -> false
                }
            }
            .clickable(onClick = onPlay)
            .padding(14.dp),
    ) {
        Text(
            text = "E${episode.number}",
            color = Color(0xFFE50914),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = episode.title,
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        if (isFocused) {
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    painter = painterResource(R.drawable.ic_play),
                    contentDescription = "Play",
                    tint = Color(0xFFE50914),
                    modifier = Modifier.size(14.dp),
                )
                Spacer(Modifier.width(4.dp))
                Text(text = "Play", color = Color(0xFFE50914), fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}
