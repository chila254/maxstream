package com.maxstream.app.ui.screens.home

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import com.maxstream.app.data.local.WatchEntryCompat
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.viewmodel.HomeViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun HomeScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit,
    isVisible: Boolean = true,
) {
    val viewModel: HomeViewModel = viewModel()
    val trendingMovies  by viewModel.trendingMovies.observeAsState(emptyList())
    val trendingSeries  by viewModel.trendingSeries.observeAsState(emptyList())
    val popularMovies   by viewModel.popularMovies.observeAsState(emptyList())
    val topRatedMovies  by viewModel.topRatedMovies.observeAsState(emptyList())
    val continueWatching by viewModel.continueWatching.observeAsState(emptyList())

    var heroItem   by remember { mutableStateOf<MediaItem?>(null) }
    var heroType   by remember { mutableStateOf("movie") }
    var heroResume by remember { mutableStateOf(false) }
    var isEntryVisible by remember { mutableStateOf(false) }

    // Focus requesters for the hero buttons and the first content row
    val playFocusRequester    = remember { FocusRequester() }
    val detailsFocusRequester = remember { FocusRequester() }
    val firstRowFocusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()

    // Seed hero item once data loads
    LaunchedEffect(trendingMovies) {
        if (heroItem == null && trendingMovies.isNotEmpty()) {
            heroItem = trendingMovies.first()
            heroType = "movie"
            heroResume = false
        }
    }

    // Entry animation + initial focus seed.
    // Re-runs whenever this tab becomes visible so focus is restored on tab return.
    LaunchedEffect(isVisible) {
        if (!isVisible) return@LaunchedEffect
        delay(80) // Let the layout settle
        isEntryVisible = true
        // Seed focus on the Play button; if data isn't loaded yet the node
        // may not exist — the runCatching absorbs the IllegalStateException.
        runCatching { playFocusRequester.requestFocus() }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
    ) {
        AnimatedVisibility(
            visible = isEntryVisible,
            enter = fadeIn(tween(330)) + scaleIn(tween(330), initialScale = 0.97f),
            exit  = fadeOut(tween(180)),
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                // ── Hero backdrop (top 55%) ────────────────────────────────
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .fillMaxHeight(0.55f)
                        .align(Alignment.TopStart)
                ) {
                    HeroSection(
                        item = heroItem,
                        mediaType = heroType,
                        isResume = heroResume,
                        playFocusRequester = playFocusRequester,
                        detailsFocusRequester = detailsFocusRequester,
                        onPlay = { mediaItem ->
                            if (mediaItem != null) {
                                val route = if (heroType == "series")
                                    Screen.Series.createRoute(mediaItem.id.toString())
                                else
                                    Screen.Player.createRoute(mediaItem.id.toString(), "movie")
                                navController.navigate(route)
                            }
                        },
                        onDetails = { mediaItem ->
                            if (mediaItem != null) {
                                val route = if (heroType == "series")
                                    Screen.Series.createRoute(mediaItem.id.toString())
                                else
                                    Screen.Details.createRoute(mediaItem.id.toString())
                                navController.navigate(route)
                            }
                        },
                        onReturnToSidebar = onReturnToSidebar,
                        onArrowDown = {
                            coroutineScope.launch { firstRowFocusRequester.requestFocus() }
                        },
                        modifier = Modifier.fillMaxSize(),
                    )
                }

                // ── Content rows (bottom 45%) ─────────────────────────────
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .fillMaxHeight(0.45f)
                        .align(Alignment.BottomStart)
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        state = rememberLazyListState(),
                        contentPadding = PaddingValues(bottom = 56.dp),
                        userScrollEnabled = false,
                    ) {
                        if (continueWatching.isNotEmpty()) {
                            item {
                                ContentRow(
                                    title = stringResource(R.string.continue_watching),
                                    items = continueWatching,
                                    navController = navController,
                                    rowFocusRequester = firstRowFocusRequester,
                                    showProgress = true,
                                    resumeOnSelect = true,
                                    onItemFocus = { mediaItem ->
                                        heroItem = mediaItem
                                        heroType = if (mediaItem.mediaType == "tv") "series" else "movie"
                                        heroResume = true
                                    },
                                    onArrowUp = { playFocusRequester.requestFocus() },
                                    onReturnToSidebar = onReturnToSidebar,
                                    modifier = Modifier.padding(top = 20.dp),
                                )
                            }
                        }

                        if (trendingMovies.isNotEmpty()) {
                            item {
                                ContentRow(
                                    title = stringResource(R.string.trending_movies),
                                    items = trendingMovies.take(15),
                                    navController = navController,
                                    rowFocusRequester = if (continueWatching.isEmpty()) firstRowFocusRequester
                                                        else remember { FocusRequester() },
                                    onItemFocus = { mediaItem ->
                                        heroItem = mediaItem; heroType = "movie"; heroResume = false
                                    },
                                    onArrowUp = { playFocusRequester.requestFocus() },
                                    onReturnToSidebar = onReturnToSidebar,
                                    modifier = Modifier.padding(top = 20.dp),
                                )
                            }
                        }

                        if (trendingSeries.isNotEmpty()) {
                            item {
                                ContentRow(
                                    title = stringResource(R.string.trending_series),
                                    items = trendingSeries.take(15),
                                    navController = navController,
                                    rowFocusRequester = remember { FocusRequester() },
                                    onItemFocus = { mediaItem ->
                                        heroItem = mediaItem; heroType = "series"; heroResume = false
                                    },
                                    onArrowUp = { playFocusRequester.requestFocus() },
                                    onReturnToSidebar = onReturnToSidebar,
                                    modifier = Modifier.padding(top = 20.dp),
                                )
                            }
                        }

                        if (popularMovies.isNotEmpty()) {
                            item {
                                ContentRow(
                                    title = stringResource(R.string.popular_movies),
                                    items = popularMovies.take(15),
                                    navController = navController,
                                    rowFocusRequester = remember { FocusRequester() },
                                    onItemFocus = { mediaItem ->
                                        heroItem = mediaItem; heroType = "movie"; heroResume = false
                                    },
                                    onArrowUp = { playFocusRequester.requestFocus() },
                                    onReturnToSidebar = onReturnToSidebar,
                                    modifier = Modifier.padding(top = 20.dp),
                                )
                            }
                        }

                        if (topRatedMovies.isNotEmpty()) {
                            item {
                                ContentRow(
                                    title = stringResource(R.string.top_rated),
                                    items = topRatedMovies.take(15),
                                    navController = navController,
                                    rowFocusRequester = remember { FocusRequester() },
                                    onItemFocus = { mediaItem ->
                                        heroItem = mediaItem; heroType = "movie"; heroResume = false
                                    },
                                    onArrowUp = { playFocusRequester.requestFocus() },
                                    onReturnToSidebar = onReturnToSidebar,
                                    modifier = Modifier.padding(top = 20.dp),
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
// Hero section
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun HeroSection(
    item: MediaItem?,
    mediaType: String,
    isResume: Boolean,
    playFocusRequester: FocusRequester,
    detailsFocusRequester: FocusRequester,
    onPlay: (MediaItem?) -> Unit,
    onDetails: (MediaItem?) -> Unit,
    onReturnToSidebar: () -> Unit,
    onArrowDown: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val heroKey = item?.let { "${it.id}:$mediaType" } ?: "empty"

    AnimatedContent(
        targetState = heroKey,
        transitionSpec = {
            (fadeIn(tween(480)) + scaleIn(tween(480), initialScale = 1.025f)) togetherWith
                    (fadeOut(tween(180)) + scaleOut(tween(180)))
        },
        modifier = modifier,
        label = "heroTransition",
    ) { currentKey ->
        if (currentKey == "empty" || item == null) {
            Box(modifier = Modifier.fillMaxSize())
            return@AnimatedContent
        }

        val backdropUrl = item.backdropUrl.ifEmpty { item.posterUrl }
        val displayTitle = item.title
        val year = item.releaseDate.take(4).toIntOrNull() ?: 0
        val rating = item.voteAverage
        val overview = item.overview

        val heroMetadata = buildString {
            if (isResume) append("Resume")
            if (rating > 0) { if (isNotEmpty()) append("   "); append(String.format("★ %.1f", rating)) }
            if (year > 0)   { if (isNotEmpty()) append("   "); append(year) }
            if (isNotEmpty()) append("   ")
            append(if (mediaType == "series") "TV Series" else "Movie")
        }

        Box(modifier = Modifier.fillMaxSize()) {
            AsyncImage(
                model = backdropUrl,
                contentDescription = displayTitle,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )

            // Horizontal gradient (left side dark)
            Box(
                modifier = Modifier.fillMaxSize().background(
                    Brush.horizontalGradient(
                        colors = listOf(Color.Black, Color(0xD9000000), Color.Transparent),
                        startX = 0f, endX = 1200f,
                    )
                )
            )
            // Bottom fade to background colour
            Box(
                modifier = Modifier.fillMaxSize().background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.Transparent, Color(0xFF0F0F0F)),
                        startY = 0f, endY = 400f,
                    )
                )
            )

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(start = 48.dp, top = 32.dp, end = 48.dp, bottom = 56.dp),
                verticalArrangement = Arrangement.Bottom,
            ) {
                androidx.compose.material3.Text(
                    text = displayTitle,
                    color = Color.White,
                    fontSize = 38.sp,
                    fontWeight = FontWeight.ExtraBold,
                    lineHeight = 44.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    letterSpacing = (-0.7).sp,
                    modifier = Modifier.fillMaxWidth(0.65f),
                )
                Spacer(modifier = Modifier.height(10.dp))
                androidx.compose.material3.Text(
                    text = heroMetadata,
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.fillMaxWidth(0.85f),
                )
                if (overview.isNotBlank()) {
                    Spacer(modifier = Modifier.height(10.dp))
                    androidx.compose.material3.Text(
                        text = overview,
                        color = Color(0xFFD8D8D8),
                        fontSize = 14.sp,
                        lineHeight = 22.sp,
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.fillMaxWidth(0.75f),
                    )
                }
                Spacer(modifier = Modifier.height(18.dp))

                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    // ── Play button ── Key handlers are on the BUTTON, not a container
                    androidx.compose.material3.Button(
                        onClick = { onPlay(item) },
                        modifier = Modifier
                            .focusRequester(playFocusRequester)
                            .onKeyEvent { event ->
                                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                                when (event.key) {
                                    Key.DirectionLeft  -> { onReturnToSidebar(); true }
                                    Key.DirectionRight -> { runCatching { detailsFocusRequester.requestFocus() }; true }
                                    Key.DirectionDown  -> { onArrowDown(); true }
                                    else -> false
                                }
                            },
                        colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                            containerColor = Color(0xFFE50914)
                        ),
                    ) {
                        androidx.compose.material3.Icon(
                            painter = painterResource(R.drawable.ic_play),
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        androidx.compose.material3.Text(
                            text = if (isResume) stringResource(R.string.resume) else stringResource(R.string.play)
                        )
                    }

                    // ── Details button ──
                    androidx.compose.material3.OutlinedButton(
                        onClick = { onDetails(item) },
                        modifier = Modifier
                            .focusRequester(detailsFocusRequester)
                            .onKeyEvent { event ->
                                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                                when (event.key) {
                                    Key.DirectionLeft  -> { runCatching { playFocusRequester.requestFocus() }; true }
                                    Key.DirectionDown  -> { onArrowDown(); true }
                                    else -> false
                                }
                            },
                    ) {
                        androidx.compose.material3.Icon(
                            painter = painterResource(R.drawable.ic_info),
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        androidx.compose.material3.Text(text = stringResource(R.string.details))
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content row
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ContentRow(
    title: String,
    items: List<MediaItem>,
    navController: NavController,
    rowFocusRequester: FocusRequester,
    showProgress: Boolean = false,
    resumeOnSelect: Boolean = false,
    onItemFocus: (MediaItem) -> Unit = {},
    onArrowUp: () -> Unit = {},
    onReturnToSidebar: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val coroutineScope = rememberCoroutineScope()
    // Track which card is focused within THIS row
    var focusedItemIndex by remember { mutableIntStateOf(-1) }

    Column(modifier = modifier.padding(horizontal = 48.dp)) {
        androidx.compose.material3.Text(
            text = title,
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.W700,
            modifier = Modifier.padding(bottom = 12.dp),
        )

        LazyRow(
            state = rememberLazyListState(),
            contentPadding = PaddingValues(vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .focusRequester(rowFocusRequester)
                // Row-level key handler: ← on first item → sidebar, ↑ → hero
                .onKeyEvent { event ->
                    if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                    when (event.key) {
                        Key.DirectionLeft -> {
                            if (focusedItemIndex <= 0) { onReturnToSidebar(); true }
                            else false // let normal focus traversal handle it
                        }
                        Key.DirectionUp -> {
                            coroutineScope.launch { onArrowUp() }
                            true
                        }
                        else -> false
                    }
                },
        ) {
            items(
                count = items.size,
                key = { index -> "${title.hashCode()}_$index" },
            ) { index ->
                val item = items[index]
                val isSeries = item.mediaType == "tv"

                ContentCard(
                    posterUrl = item.posterUrl,
                    title = item.title,
                    rating = item.voteAverage.takeIf { it > 0 },
                    year = item.releaseDate.take(4).toIntOrNull(),
                    contentTypeLabel = if (isSeries) "TV Series" else "Movie",
                    isFocused = focusedItemIndex == index,
                    progress = if (showProgress) {
                        WatchEntryCompat.progressOf(
                            item.id, item.mediaType, item.season, item.episode
                        ).takeIf { it > 0f }
                    } else null,
                    onClick = {
                        if (resumeOnSelect) {
                            navController.navigate(
                                Screen.Player.createRoute(
                                    item.id.toString(), item.mediaType,
                                    season = item.season, episode = item.episode,
                                )
                            )
                        } else {
                            val route = if (isSeries) Screen.Series.createRoute(item.id.toString())
                                        else Screen.Details.createRoute(item.id.toString())
                            navController.navigate(route)
                        }
                    },
                    onFocusChanged = { focused ->
                        if (focused) {
                            focusedItemIndex = index
                            onItemFocus(item)
                        } else {
                            if (focusedItemIndex == index) focusedItemIndex = -1
                        }
                    },
                    modifier = Modifier.height(190.dp),
                )
            }
        }
    }
}
