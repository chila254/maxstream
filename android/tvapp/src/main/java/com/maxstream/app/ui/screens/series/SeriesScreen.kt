package com.maxstream.app.ui.screens.series

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.livedata.observeAsState
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
import com.maxstream.app.ui.tv.TvFocusManager
import com.maxstream.app.ui.viewmodel.HomeViewModel
import com.maxstream.app.ui.viewmodel.SeriesViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun SeriesScreen(navController: NavController, itemId: String) {
    val seriesViewModel: SeriesViewModel = viewModel()
    val homeViewModel: HomeViewModel = viewModel()
    val series = seriesViewModel.series.value
    val seasons = seriesViewModel.seasons.value.orEmpty()
    val episodes = seriesViewModel.episodes.value.orEmpty()
    val loading = seriesViewModel.loading.value ?: false
    val error = seriesViewModel.error.value
    val trendingSeries = homeViewModel.trendingSeries.value.orEmpty()
    val popularMovies = homeViewModel.popularMovies.value.orEmpty()
    val topRatedMovies = homeViewModel.topRatedMovies.value.orEmpty()

    var selectedSeason by remember { mutableStateOf(1) }
    var selectedEpisode by remember { mutableStateOf<EpisodeRef?>(null) }
    var isEntryVisible by remember { mutableStateOf(false) }

    val parsedId = itemId.toIntOrNull()

    LaunchedEffect(parsedId) {
        if (parsedId != null) {
            seriesViewModel.loadSeries(parsedId)
        }
        delay(50)
        isEntryVisible = true
    }

    LaunchedEffect(seasons) {
        if (seasons.isNotEmpty() && selectedSeason !in seasons) {
            selectedSeason = seasons.first()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Background)) {
        series?.let { mediaItem ->
            val heroKey = "series:${mediaItem.id}"

            AnimatedContent(
                targetState = heroKey,
                transitionSpec = {
                    (fadeIn(tween(480)) + scaleIn(tween(480), initialScale = 1.025f)) togetherWith
                            (fadeOut(tween(180)) + scaleOut(tween(180)))
                },
                modifier = Modifier.fillMaxSize()
            ) {
                SeriesDetailsView(
                    series = mediaItem,
                    navController = navController,
                    seasons = seasons,
                    episodes = episodes,
                    selectedSeason = selectedSeason,
                    selectedEpisode = selectedEpisode,
                    loading = loading,
                    error = error,
                    trendingSeries = trendingSeries,
                    popularMovies = popularMovies,
                    topRatedMovies = topRatedMovies,
                    onSeasonSelected = { season ->
                        selectedSeason = season
                        seriesViewModel.selectSeason(season)
                    },
                    onEpisodeSelected = { episode ->
                        selectedEpisode = episode
                    },
                    onPlayEpisode = { episode ->
                        val route = Screen.Player.createRoute(
                            mediaItem.id.toString(),
                            "tv",
                            season = selectedSeason,
                            episode = episode.number,
                        )
                        navController.navigate(route)
                    },
                    onBack = {
                        TvFocusManager.focusSidebar()
                    }
                )
            }
        } ?: Spacer(modifier = Modifier.fillMaxSize())
    }
}

@Composable
private fun SeriesDetailsView(
    series: MediaItem,
    navController: NavController,
    seasons: List<Int>,
    episodes: List<EpisodeRef>,
    selectedSeason: Int,
    selectedEpisode: EpisodeRef?,
    loading: Boolean,
    error: String?,
    trendingSeries: List<MediaItem>,
    popularMovies: List<MediaItem>,
    topRatedMovies: List<MediaItem>,
    onSeasonSelected: (Int) -> Unit,
    onEpisodeSelected: (EpisodeRef) -> Unit,
    onPlayEpisode: (EpisodeRef) -> Unit,
    onBack: () -> Unit,
) {
    val backdropUrl = series.backdropUrl.ifEmpty { series.posterUrl }
    val title = series.title
    val year = series.releaseDate.take(4).toIntOrNull() ?: 0
    val rating = series.voteAverage
    val overview = series.overview

    val heroMetadata = buildString {
        if (rating > 0) append(String.format("★ %.1f  ", rating))
        if (year > 0) append(year)
        append("  ")
        append("TV Series")
    }

    Box(modifier = Modifier.fillMaxSize()) {
        AsyncImage(
            model = backdropUrl,
            contentDescription = title,
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

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            state = rememberLazyListState(),
            contentPadding = PaddingValues(bottom = 56.dp)
        ) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 260.dp)
                        .padding(horizontal = 48.dp, vertical = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    androidx.compose.material3.Text(
                        text = title,
                        color = Color.White,
                        fontSize = 42.sp,
                        fontWeight = FontWeight.ExtraBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )

                    androidx.compose.material3.Text(
                        text = heroMetadata,
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold
                    )

                    if (overview.isNotBlank()) {
                        androidx.compose.material3.Text(
                            text = overview,
                            color = Color(0xFFD8D8D8),
                            fontSize = 15.sp,
                            lineHeight = 1.45.sp,
                            maxLines = 7,
                            overflow = TextOverflow.Ellipsis
                        )
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        val playFocusRequester = remember { FocusRequester() }
                        androidx.compose.material3.Button(
                            onClick = {
                                if (episodes.isNotEmpty()) {
                                    onPlayEpisode(episodes.first())
                                }
                            },
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
                            androidx.compose.material3.Text(text = stringResource(R.string.play))
                        }

                        val detailsFocusRequester = remember { FocusRequester() }
                        androidx.compose.material3.OutlinedButton(
                            onClick = { },
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

            item {
                Column(
                    modifier = Modifier
                        .padding(top = 24.dp)
                        .padding(horizontal = 48.dp)
                ) {
                    androidx.compose.material3.Text(
                        text = "Seasons",
                        color = Color.White,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(bottom = 12.dp)
                    )

                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 48.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(seasons) { season ->
                            val isSelected = season == selectedSeason
                            SeasonChip(
                                label = "Season $season",
                                isSelected = isSelected,
                                onClick = { onSeasonSelected(season) }
                            )
                        }
                    }
                }
            }

            if (error != null) {
                item {
                    Column(
                        modifier = Modifier
                            .padding(top = 24.dp)
                            .padding(horizontal = 48.dp)
                    ) {
                        androidx.compose.material3.Text(
                            text = "Error: $error",
                            color = Color(0xFFCF6679),
                            fontSize = 14.sp
                        )
                    }
                }
            }

            item {
                Column(
                    modifier = Modifier
                        .padding(top = 24.dp)
                        .padding(horizontal = 48.dp)
                ) {
                    androidx.compose.material3.Text(
                        text = "Episodes",
                        color = Color.White,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(bottom = 12.dp)
                    )

                    if (loading) {
                        androidx.compose.material3.CircularProgressIndicator(
                            color = androidx.compose.material3.MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(16.dp)
                        )
                    }

                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 48.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(episodes) { episode ->
                            val isSelected = episode == selectedEpisode
                            EpisodeChip(
                                label = "E${episode.number}: ${episode.title}",
                                isSelected = isSelected,
                                onClick = { onEpisodeSelected(episode) },
                                onPlay = { onPlayEpisode(episode) }
                            )
                        }
                    }
                }
            }

            if (trendingSeries.isNotEmpty()) {
                item {
                    Column(modifier = Modifier.padding(top = 24.dp)) {
                        androidx.compose.material3.Text(
                            text = stringResource(R.string.trending_series),
                            color = Color.White,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier
                                .padding(horizontal = 48.dp)
                                .padding(bottom = 12.dp)
                        )

                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 48.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(trendingSeries.take(10)) { seriesItem ->
                                ContentCard(
                                    posterUrl = seriesItem.posterUrl,
                                    title = seriesItem.title,
                                    rating = seriesItem.voteAverage.takeIf { it > 0 },
                                    onClick = {
                                        navController.navigate(Screen.Series.createRoute(seriesItem.id.toString()))
                                    },
                                    modifier = Modifier.height(180.dp)
                                )
                            }
                        }
                    }
                }
            }

            if (popularMovies.isNotEmpty()) {
                item {
                    Column(modifier = Modifier.padding(top = 24.dp)) {
                        androidx.compose.material3.Text(
                            text = stringResource(R.string.popular_movies),
                            color = Color.White,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier
                                .padding(horizontal = 48.dp)
                                .padding(bottom = 12.dp)
                        )

                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 48.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(popularMovies.take(10)) { movie ->
                                ContentCard(
                                    posterUrl = movie.posterUrl,
                                    title = movie.title,
                                    rating = movie.voteAverage.takeIf { it > 0 },
                                    onClick = {
                                        navController.navigate(Screen.Details.createRoute(movie.id.toString()))
                                    },
                                    modifier = Modifier.height(180.dp)
                                )
                            }
                        }
                    }
                }
            }

            if (topRatedMovies.isNotEmpty()) {
                item {
                    Column(modifier = Modifier.padding(top = 24.dp)) {
                        androidx.compose.material3.Text(
                            text = stringResource(R.string.top_rated),
                            color = Color.White,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier
                                .padding(horizontal = 48.dp)
                                .padding(bottom = 12.dp)
                        )

                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 48.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(topRatedMovies.take(10)) { movie ->
                                ContentCard(
                                    posterUrl = movie.posterUrl,
                                    title = movie.title,
                                    rating = movie.voteAverage.takeIf { it > 0 },
                                    onClick = {
                                        navController.navigate(Screen.Details.createRoute(movie.id.toString()))
                                    },
                                    modifier = Modifier.height(180.dp)
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
private fun SeasonChip(label: String, isSelected: Boolean, onClick: () -> Unit) {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(
                if (isSelected) Color.White else Color.White.copy(alpha = 0.12f)
            )
            .onFocusChanged { focusState ->
                if (focusState.hasFocus) {
                    onClick()
                }
            }
            .padding(horizontal = 20.dp, vertical = 10.dp)
    ) {
        androidx.compose.material3.Text(
            text = label,
            color = if (isSelected) Color.Black else Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun EpisodeChip(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    onPlay: () -> Unit,
) {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(
                if (isSelected) Color.White else Color.White.copy(alpha = 0.12f)
            )
            .onFocusChanged { focusState ->
                if (focusState.hasFocus) {
                    onClick()
                }
            }
            .padding(horizontal = 20.dp, vertical = 10.dp)
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            androidx.compose.material3.Text(
                text = label,
                color = if (isSelected) Color.Black else Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (isSelected) {
                Spacer(modifier = Modifier.height(4.dp))
                androidx.compose.material3.Text(
                    text = "Play",
                    color = Color.Black,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}
