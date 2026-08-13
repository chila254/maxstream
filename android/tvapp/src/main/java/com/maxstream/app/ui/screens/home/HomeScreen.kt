package com.maxstream.app.ui.screens.home

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.maxstream.app.data.local.WatchEntryCompat
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
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
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.tv.TvFocusManager
import com.maxstream.app.ui.viewmodel.HomeViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun HomeScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit,
    contentFocusRequester: FocusRequester = remember { FocusRequester() },
) {
    val viewModel: HomeViewModel = viewModel()
    val trendingMovies by viewModel.trendingMovies.observeAsState(emptyList())
    val trendingSeries by viewModel.trendingSeries.observeAsState(emptyList())
    val popularMovies by viewModel.popularMovies.observeAsState(emptyList())
    val topRatedMovies by viewModel.topRatedMovies.observeAsState(emptyList())
    val continueWatching by viewModel.continueWatching.observeAsState(emptyList())

    var heroItem by remember { mutableStateOf<MediaItem?>(null) }
    var heroType by remember { mutableStateOf("movie") }
    var heroResume by remember { mutableStateOf(false) }
    var isEntryVisible by remember { mutableStateOf(false) }

    val playFocusRequester = remember { FocusRequester() }
    val detailsFocusRequester = remember { FocusRequester() }
    val firstRowFocusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        delay(50)
        isEntryVisible = true
        if (trendingMovies.isNotEmpty()) {
            heroItem = trendingMovies.first()
            heroType = "movie"
            heroResume = false
        }
    }

    val hasContinueWatching = continueWatching.isNotEmpty()
    val hasTrendingMovies = trendingMovies.isNotEmpty()
    val hasTrendingSeries = trendingSeries.isNotEmpty()
    val hasPopularMovies = popularMovies.isNotEmpty()
    val hasTopRated = topRatedMovies.isNotEmpty()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
            .focusRequester(contentFocusRequester)
    ) {
        if (!isEntryVisible) {
            Spacer(modifier = Modifier.fillMaxSize())
        } else {
            androidx.compose.animation.AnimatedVisibility(
                visible = isEntryVisible,
                enter = fadeIn(tween(330)) + scaleIn(tween(330), initialScale = 0.97f),
                exit = fadeOut(tween(180))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .offset(y = (-0.025f).dp)
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        state = rememberLazyListState(),
                        contentPadding = PaddingValues(bottom = 56.dp)
                    ) {
                        val heroHeight = 420.dp

                        item {
                            HomeHeroSection(
                                item = heroItem,
                                mediaType = heroType,
                                isResume = heroResume,
                                playFocusRequester = playFocusRequester,
                                detailsFocusRequester = detailsFocusRequester,
                                onPlay = { mediaItem ->
                                    if (mediaItem != null) {
                                        // Series open the episode picker (S/E selection lives
                                        // there); movies go straight to the player.
                                        val route = if (heroType == "series") {
                                            Screen.Series.createRoute(mediaItem.id.toString())
                                        } else {
                                            Screen.Player.createRoute(mediaItem.id.toString(), "movie")
                                        }
                                        navController.navigate(route)
                                    }
                                },
                                onDetails = { mediaItem ->
                                    if (mediaItem != null) {
                                        val route = if (heroType == "series") {
                                            Screen.Series.createRoute(mediaItem.id.toString())
                                        } else {
                                            Screen.Details.createRoute(mediaItem.id.toString())
                                        }
                                        navController.navigate(route)
                                    }
                                },
                                onReturnToSidebar = onReturnToSidebar,
                                onArrowDown = {
                                    coroutineScope.launch {
                                        firstRowFocusRequester.requestFocus()
                                    }
                                },
                                modifier = Modifier.height(heroHeight)
                            )
                        }

                        if (hasContinueWatching) {
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
                                    onArrowUp = {
                                        coroutineScope.launch {
                                            playFocusRequester.requestFocus()
                                        }
                                    },
                                    modifier = Modifier.padding(top = 20.dp)
                                )
                            }
                        }

                        if (hasTrendingMovies) {
                            item {
                                val nextRowRequester = remember { FocusRequester() }
                                ContentRow(
                                    title = stringResource(R.string.trending_movies),
                                    items = trendingMovies.take(15),
                                    navController = navController,
                                    rowFocusRequester = nextRowRequester,
                                    onItemFocus = { mediaItem ->
                                        heroItem = mediaItem
                                        heroType = "movie"
                                        heroResume = false
                                    },
                                    onArrowUp = {
                                        coroutineScope.launch {
                                            playFocusRequester.requestFocus()
                                        }
                                    },
                                    modifier = Modifier.padding(top = 20.dp)
                                )
                            }
                        }

                        if (hasTrendingSeries) {
                            item {
                                val nextRowRequester = remember { FocusRequester() }
                                ContentRow(
                                    title = stringResource(R.string.trending_series),
                                    items = trendingSeries.take(15),
                                    navController = navController,
                                    rowFocusRequester = nextRowRequester,
                                    onItemFocus = { mediaItem ->
                                        heroItem = mediaItem
                                        heroType = "series"
                                        heroResume = false
                                    },
                                    onArrowUp = {
                                        coroutineScope.launch {
                                            playFocusRequester.requestFocus()
                                        }
                                    },
                                    modifier = Modifier.padding(top = 20.dp)
                                )
                            }
                        }

                        if (hasPopularMovies) {
                            item {
                                val nextRowRequester = remember { FocusRequester() }
                                ContentRow(
                                    title = stringResource(R.string.popular_movies),
                                    items = popularMovies.take(15),
                                    navController = navController,
                                    rowFocusRequester = nextRowRequester,
                                    onItemFocus = { mediaItem ->
                                        heroItem = mediaItem
                                        heroType = "movie"
                                        heroResume = false
                                    },
                                    onArrowUp = {
                                        coroutineScope.launch {
                                            playFocusRequester.requestFocus()
                                        }
                                    },
                                    modifier = Modifier.padding(top = 20.dp)
                                )
                            }
                        }

                        if (hasTopRated) {
                            item {
                                ContentRow(
                                    title = stringResource(R.string.top_rated),
                                    items = topRatedMovies.take(15),
                                    navController = navController,
                                    rowFocusRequester = remember { FocusRequester() },
                                    onItemFocus = { mediaItem ->
                                        heroItem = mediaItem
                                        heroType = "movie"
                                        heroResume = false
                                    },
                                    onArrowUp = {
                                        coroutineScope.launch {
                                            playFocusRequester.requestFocus()
                                        }
                                    },
                                    modifier = Modifier.padding(top = 20.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeHeroSection(
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
    val backdropUrl = item?.let { it.backdropUrl.ifEmpty { it.posterUrl } } ?: ""

    val heroKey = item?.let { "${it.id}:$mediaType" } ?: "empty"

    val displayTitle = item?.title ?: ""
    val year = item?.releaseDate?.take(4)?.toIntOrNull() ?: 0
    val rating = item?.voteAverage ?: 0.0
    val overview = item?.overview ?: ""

    val heroMetadata = buildString {
        if (isResume) append("Resume")
        if (rating > 0) {
            if (isNotEmpty()) append("   ")
            append(String.format("★ %.1f", rating))
        }
        if (year > 0) {
            if (isNotEmpty()) append("   ")
            append(year)
        }
        if (isNotEmpty()) append("   ")
        append(if (mediaType == "series") "TV Series" else "Movie")
    }

    AnimatedContent(
        targetState = heroKey,
        transitionSpec = {
            (fadeIn(tween(480)) + scaleIn(tween(480), initialScale = 1.025f)) togetherWith
                    (fadeOut(tween(180)) + scaleOut(tween(180)))
        },
        modifier = modifier
            .onKeyEvent { keyEvent ->
                if (keyEvent.type == KeyEventType.KeyDown && keyEvent.key == Key.DirectionDown) {
                    onArrowDown()
                    true
                } else false
            }
    ) { currentKey ->
        if (currentKey == "empty") {
            Box(modifier = Modifier.fillMaxSize())
        } else {
            Box(modifier = Modifier.fillMaxSize()) {
                AsyncImage(
                    model = backdropUrl,
                    contentDescription = displayTitle,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.horizontalGradient(
                                colors = listOf(Color.Black, Color(0xD9000000), Color.Transparent),
                                startX = 0f,
                                endX = 1200f
                            )
                        )
                )

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Transparent, Color.Transparent, Color(0xFF080808)),
                                startY = 0f,
                                endY = 280f
                            )
                        )
                )

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(start = 48.dp, top = 32.dp, end = 48.dp, bottom = 56.dp),
                    verticalArrangement = Arrangement.Bottom
                ) {
                    androidx.compose.material3.Text(
                        text = displayTitle,
                        color = Color.White,
                        fontSize = 38.sp,
                        fontWeight = FontWeight.ExtraBold,
                        lineHeight = 1.05.sp,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        letterSpacing = (-0.7).sp,
                        modifier = Modifier.fillMaxWidth(0.65f)
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    androidx.compose.material3.Text(
                        text = heroMetadata,
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold
                    )

                    if (overview.isNotBlank()) {
                        Spacer(modifier = Modifier.height(10.dp))
                        androidx.compose.material3.Text(
                            text = overview,
                            color = Color(0xFFD8D8D8),
                            fontSize = 14.sp,
                            lineHeight = 1.45.sp,
                            maxLines = 3,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.fillMaxWidth(0.75f)
                        )
                    }

                    Spacer(modifier = Modifier.height(18.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        androidx.compose.material3.Button(
                            onClick = { onPlay(item) },
                            modifier = Modifier.focusRequester(playFocusRequester),
                            colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                                containerColor = Color(0xFFE50914)
                            )
                        ) {
                            androidx.compose.material3.Icon(
                                painter = painterResource(id = R.drawable.ic_play),
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            androidx.compose.material3.Text(
                                text = if (isResume) stringResource(R.string.resume) else stringResource(R.string.play)
                            )
                        }

                        androidx.compose.material3.OutlinedButton(
                            onClick = { onDetails(item) },
                            modifier = Modifier.focusRequester(detailsFocusRequester)
                        ) {
                            androidx.compose.material3.Icon(
                                painter = painterResource(id = R.drawable.ic_info),
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            androidx.compose.material3.Text(text = stringResource(R.string.details))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ContentRow(
    title: String,
    items: List<MediaItem>,
    navController: NavController,
    rowFocusRequester: FocusRequester,
    showProgress: Boolean = false,
    resumeOnSelect: Boolean = false,
    onItemFocus: (MediaItem) -> Unit = {},
    onArrowUp: suspend () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val rowState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()
    var focusedItemIndex by remember { mutableStateOf(0) }

    Column(modifier = modifier.padding(horizontal = 48.dp)) {
        androidx.compose.material3.Text(
            text = title,
            color = Color(0xFFFFFFFF),
            fontSize = 24.sp,
            lineHeight = 32.sp,
            letterSpacing = 0.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(bottom = 12.dp)
        )

        LazyRow(
            state = rowState,
            contentPadding = PaddingValues(horizontal = 48.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .focusRequester(rowFocusRequester)
                .onKeyEvent { keyEvent ->
                    if (keyEvent.type == KeyEventType.KeyDown) {
                        when (keyEvent.key) {
                            Key.DirectionLeft -> {
                                true
                            }
                            Key.DirectionRight -> {
                                true
                            }
                            Key.DirectionUp -> {
                                coroutineScope.launch {
                                    onArrowUp()
                                }
                                true
                            }
                            else -> false
                        }
                    } else false
                }
        ) {
            items(
                count = items.size,
                key = { index -> "row_${title.hashCode()}_$index" }
            ) { index ->
                val item = items[index]
                val isSeries = item.mediaType == "tv"
                val year = item.releaseDate.take(4).toIntOrNull()
                val rating = item.voteAverage.takeIf { it > 0 }
                val contentTypeLabel = if (isSeries) "TV Series" else "Movie"
                val isFocused = index == focusedItemIndex

                ContentCard(
                    posterUrl = item.posterUrl,
                    title = item.title,
                    rating = rating,
                    year = year,
                    progress = if (showProgress) {
                        WatchEntryCompat.progressOf(
                            item.id, item.mediaType, item.season, item.episode,
                        ).takeIf { it > 0f }
                    } else null,
                    contentTypeLabel = contentTypeLabel,
                    isFocused = isFocused,
                    onClick = {
                        if (resumeOnSelect) {
                            navController.navigate(
                                Screen.Player.createRoute(
                                    item.id.toString(),
                                    item.mediaType,
                                    season = item.season,
                                    episode = item.episode,
                                ),
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
                        }
                    },
                    modifier = Modifier
                        .height(190.dp)
                )
            }
        }
    }
}
