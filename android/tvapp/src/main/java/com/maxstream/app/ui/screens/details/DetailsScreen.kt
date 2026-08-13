package com.maxstream.app.ui.screens.details

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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
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
import com.maxstream.app.data.local.WatchEntryCompat
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.tv.TvFocusManager
import com.maxstream.app.ui.viewmodel.HomeViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun DetailsScreen(navController: NavController, itemId: String) {
    val viewModel: HomeViewModel = viewModel()
    val trendingSeries = viewModel.trendingSeries.value.orEmpty()
    val popularMovies = viewModel.popularMovies.value.orEmpty()
    val topRatedMovies = viewModel.topRatedMovies.value.orEmpty()

    var item by remember { mutableStateOf<MediaItem?>(null) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(itemId) {
        val id = itemId.toIntOrNull()
        if (id == null) {
            error = "Invalid item ID"
            loading = false
            return@LaunchedEffect
        }
        loading = true
        error = null
        try {
            val movieJson = com.maxstream.app.di.Modules.catalogRepository.movieDetails(id)
            val mediaItem = MediaItem.fromJson(movieJson)
            item = mediaItem
        } catch (e: Exception) {
            try {
                val seriesJson = com.maxstream.app.di.Modules.catalogRepository.seriesDetails(id)
                val mediaItem = MediaItem.fromJson(seriesJson)
                item = mediaItem
            } catch (e2: Exception) {
                error = e2.message
            }
        } finally {
            loading = false
        }
    }

    if (loading) {
        Box(modifier = Modifier.fillMaxSize().background(Background)) {
            androidx.compose.material3.CircularProgressIndicator(
                color = androidx.compose.material3.MaterialTheme.colorScheme.primary,
                modifier = Modifier.align(Alignment.Center)
            )
        }
    } else if (error != null) {
        Box(modifier = Modifier.fillMaxSize().background(Background)) {
            androidx.compose.material3.Text(
                text = "Error: $error",
                color = Color(0xFFCF6679),
                modifier = Modifier.align(Alignment.Center)
            )
        }
    } else if (item != null) {
        TvCinematicDetails(
            item = item!!,
            mediaType = item!!.mediaType,
            navController = navController,
            popularMovies = popularMovies,
            topRatedMovies = topRatedMovies,
            trendingSeries = trendingSeries
        )
    }
}

@Composable
fun TvCinematicDetails(
    item: MediaItem,
    mediaType: String,
    navController: NavController,
    popularMovies: List<MediaItem> = emptyList(),
    topRatedMovies: List<MediaItem> = emptyList(),
    trendingSeries: List<MediaItem> = emptyList(),
) {
    val backdropUrl = item.backdropUrl.ifEmpty { item.posterUrl }
    val title = item.title
    val year = item.releaseDate.take(4).toIntOrNull() ?: 0
    val rating = item.voteAverage
    val overview = item.overview
    val contentTypeLabel = if (mediaType == "tv") "TV Series" else "Movie"

    val heroMetadata = buildString {
        if (rating > 0) append(String.format("★ %.1f  ", rating))
        if (year > 0) append(year)
        append("  •  ")
        append(contentTypeLabel)
    }

    Box(modifier = Modifier.fillMaxSize().background(Background)) {
        AnimatedContent(
            targetState = "${item.id}:$mediaType",
            transitionSpec = {
                (fadeIn(tween(450)) + scaleIn(tween(450), initialScale = 1.025f)) togetherWith
                        (fadeOut(tween(180)) + scaleOut(tween(180)))
            },
            modifier = Modifier.fillMaxSize()
        ) { currentKey ->
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
                                colors = listOf(Color(0xff090909), Color(0xdd090909), Color.Transparent),
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
                                colors = listOf(Color.Transparent, Color(0x33090909), Color(0xff090909)),
                                startY = 0f,
                                endY = 280f
                            )
                        )
                )
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 64.dp)
        ) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 260.dp)
                        .padding(horizontal = 48.dp, vertical = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    androidx.compose.material3.Text(
                        text = title,
                        color = Color.White,
                        fontSize = 42.sp,
                        fontWeight = FontWeight.ExtraBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.fillMaxWidth(0.7f)
                    )

                    androidx.compose.material3.Text(
                        text = heroMetadata,
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 15.sp,
                        lineHeight = 1.4.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.fillMaxWidth(0.85f)
                    )

                    if (overview.isNotBlank()) {
                        androidx.compose.material3.Text(
                            text = overview,
                            color = Color(0xFFD8D8D8),
                            fontSize = 15.sp,
                            lineHeight = 1.6.sp,
                            maxLines = 7,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.fillMaxWidth(0.8f)
                        )
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        val playFocusRequester = remember { FocusRequester() }
                        androidx.compose.material3.Button(
                            onClick = {
                                val route = if (mediaType == "tv") {
                                    Screen.Series.createRoute(item.id.toString())
                                } else {
                                    Screen.Player.createRoute(item.id.toString(), mediaType)
                                }
                                navController.navigate(route)
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

                        val watchlistFocusRequester = remember { FocusRequester() }
                        androidx.compose.material3.OutlinedButton(
                            onClick = { },
                            modifier = Modifier.focusRequester(watchlistFocusRequester)
                        ) {
                            androidx.compose.material3.Icon(
                                painter = painterResource(id = R.drawable.ic_watchlist),
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            androidx.compose.material3.Text(text = stringResource(R.string.watchlist))
                        }
                    }
                }
            }

            if (mediaType == "tv") {
                item {
                    TvSection(
                        title = "Seasons",
                        height = 52,
                        content = {
                            LazyRow(
                                contentPadding = PaddingValues(horizontal = 48.dp),
                                horizontalArrangement = Arrangement.spacedBy(10)
                            ) {
                                items((1..5).toList()) { season ->
                                    val isSelected = season == 1
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(
                                                if (isSelected) Color.White else Color.White.copy(alpha = 0.12f)
                                            )
                                            .padding(horizontal = 20.dp, vertical = 11.dp)
                                    ) {
                                        androidx.compose.material3.Text(
                                            text = "Season $season",
                                            color = if (isSelected) Color.Black else Color.White,
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.SemiBold
                                        )
                                    }
                                }
                            }
                        }
                    )
                }
            }

            item {
                TvSection(
                    title = "Continue Watching",
                    height = 240,
                    content = {
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 48.dp),
                            horizontalArrangement = Arrangement.spacedBy(18)
                        ) {
                            items(5) { index ->
                                TvTile(
                                    node = remember { FocusRequester() },
                                    order = 15 + index / 100,
                                    onPressed = { },
                                    child = Box(
                                        modifier = Modifier
                                            .size(width = 286.dp, height = 180.dp)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(Color(0xFF242424))
                                    )
                                )
                            }
                        }
                    }
                )
            }

            if (popularMovies.isNotEmpty()) {
                item {
                    TvSection(
                        title = stringResource(R.string.popular_movies),
                        height = 260,
                        content = {
                            LazyRow(
                                contentPadding = PaddingValues(horizontal = 48.dp),
                                horizontalArrangement = Arrangement.spacedBy(18)
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
                    )
                }
            }

            if (topRatedMovies.isNotEmpty()) {
                item {
                    TvSection(
                        title = stringResource(R.string.top_rated),
                        height = 260,
                        content = {
                            LazyRow(
                                contentPadding = PaddingValues(horizontal = 48.dp),
                                horizontalArrangement = Arrangement.spacedBy(18)
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
                    )
                }
            }

            if (trendingSeries.isNotEmpty()) {
                item {
                    TvSection(
                        title = stringResource(R.string.trending_series),
                        height = 260,
                        content = {
                            LazyRow(
                                contentPadding = PaddingValues(horizontal = 48.dp),
                                horizontalArrangement = Arrangement.spacedBy(18)
                            ) {
                                items(trendingSeries.take(10)) { series ->
                                    ContentCard(
                                        posterUrl = series.posterUrl,
                                        title = series.title,
                                        rating = series.voteAverage.takeIf { it > 0 },
                                        onClick = {
                                            navController.navigate(Screen.Series.createRoute(series.id.toString()))
                                        },
                                        modifier = Modifier.height(180.dp)
                                    )
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun TvSection(
    title: String,
    height: Int,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .padding(top = 26.dp)
            .padding(horizontal = 54.dp)
    ) {
        androidx.compose.material3.Text(
            text = title,
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.W700,
            modifier = Modifier.padding(bottom = 14.dp)
        )
        Box(modifier = Modifier.height(height.dp)) {
            content()
        }
    }
}

@Composable
private fun TvTile(
    node: FocusRequester,
    order: Double,
    onPressed: () -> Unit,
    child: @Composable () -> Unit,
) {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .focusRequester(node)
            .onFocusChanged { }
    ) {
        child()
    }
}
