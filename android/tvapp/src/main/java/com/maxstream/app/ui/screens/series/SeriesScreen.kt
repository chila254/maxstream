package com.maxstream.app.ui.screens.series

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
fun SeriesScreen(navController: NavController, itemId: String) {
    val homeViewModel: HomeViewModel = viewModel()
    val trendingSeries by homeViewModel.trendingSeries.observeAsState(emptyList())
    val popularSeries by homeViewModel.popularMovies.observeAsState(emptyList())
    val topRatedSeries by homeViewModel.topRatedMovies.observeAsState(emptyList())

    var heroItem by remember { mutableStateOf<MediaItem?>(null) }
    var heroType by remember { mutableStateOf("series") }
    var isEntryVisible by remember { mutableStateOf(false) }

    val playFocusRequester = remember { FocusRequester() }
    val detailsFocusRequester = remember { FocusRequester() }
    val firstRowFocusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()

    val hasTrendingSeries = trendingSeries.isNotEmpty()
    val hasPopularSeries = popularSeries.isNotEmpty()
    val hasTopRatedSeries = topRatedSeries.isNotEmpty()

    LaunchedEffect(Unit) {
        delay(50)
        isEntryVisible = true
        if (trendingSeries.isNotEmpty()) {
            heroItem = trendingSeries.first()
            heroType = "series"
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
    ) {
        if (!isEntryVisible) {
            Spacer(modifier = Modifier.fillMaxSize())
        } else {
            androidx.compose.animation.AnimatedVisibility(
                visible = isEntryVisible,
                enter = fadeIn(tween(330)) + scaleIn(tween(330), initialScale = 0.97f),
                exit = fadeOut(tween(180))
            ) {
                Box(modifier = Modifier.fillMaxSize()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .fillMaxHeight(0.62f)
                            .align(Alignment.TopStart)
                    ) {
                        HomeHeroSection(
                            item = heroItem,
                            mediaType = heroType,
                            isResume = false,
                            playFocusRequester = playFocusRequester,
                            detailsFocusRequester = detailsFocusRequester,
                            onPlay = { mediaItem ->
                                if (mediaItem != null) {
                                    val route = Screen.Player.createRoute(mediaItem.id.toString(), "tv")
                                    navController.navigate(route)
                                }
                            },
                            onDetails = { mediaItem ->
                                if (mediaItem != null) {
                                    navController.navigate(Screen.Details.createRoute(mediaItem.id.toString()))
                                }
                            },
                            onReturnToSidebar = {
                                TvFocusManager.focusSidebar()
                            },
                            onArrowDown = {
                                coroutineScope.launch {
                                    firstRowFocusRequester.requestFocus()
                                }
                            },
                            modifier = Modifier.fillMaxSize()
                        )
                    }

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .fillMaxHeight(0.52f)
                            .align(Alignment.BottomStart)
                    ) {
                        androidx.compose.animation.AnimatedVisibility(
                            visible = isEntryVisible,
                            enter = fadeIn(tween(330)),
                            exit = fadeOut(tween(180))
                        ) {
                            LazyColumn(
                                modifier = Modifier.fillMaxSize(),
                                state = rememberLazyListState(),
                                contentPadding = PaddingValues(bottom = 56.dp),
                                userScrollEnabled = false
                            ) {
                                if (hasTrendingSeries) {
                                    item {
                                        ContentRow(
                                            title = stringResource(R.string.trending_series),
                                            items = trendingSeries.take(15),
                                            navController = navController,
                                            rowFocusRequester = firstRowFocusRequester,
                                            onItemFocus = { mediaItem ->
                                                heroItem = mediaItem
                                                heroType = "series"
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

                                if (hasPopularSeries) {
                                    item {
                                        val nextRowRequester = remember { FocusRequester() }
                                        ContentRow(
                                            title = "Popular TV Shows",
                                            items = popularSeries.take(15),
                                            navController = navController,
                                            rowFocusRequester = nextRowRequester,
                                            onItemFocus = { mediaItem ->
                                                heroItem = mediaItem
                                                heroType = "series"
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

                                if (hasTopRatedSeries) {
                                    item {
                                        ContentRow(
                                            title = "Top Rated TV Shows",
                                            items = topRatedSeries.take(15),
                                            navController = navController,
                                            rowFocusRequester = remember { FocusRequester() },
                                            onItemFocus = { mediaItem ->
                                                heroItem = mediaItem
                                                heroType = "series"
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
    }
}
