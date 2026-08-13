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
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
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
import kotlinx.coroutines.launch

@Composable
fun DetailsScreen(navController: NavController, itemId: String) {
    val viewModel: HomeViewModel = viewModel()
    val trendingSeries by viewModel.trendingSeries.observeAsState(emptyList())
    val popularMovies by viewModel.popularMovies.observeAsState(emptyList())
    val topRatedMovies by viewModel.topRatedMovies.observeAsState(emptyList())

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
        TvCinematicDetails(item = item!!, mediaType = item!!.mediaType, navController = navController)
    }
}

@Composable
fun TvCinematicDetails(
    item: MediaItem,
    mediaType: String,
    navController: NavController,
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
                                painter = androidx.compose.foundation.res.painterResource(id = R.drawable.ic_play),
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
                                painter = androidx.compose.foundation.res.painterResource(id = R.drawable.ic_watchlist),
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
                    Column(modifier = Modifier.padding(top = 24.dp, horizontal = 48.dp)) {
                        androidx.compose.material3.Text(
                            text = "Seasons",
                            color = Color.White,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(bottom = 12.dp)
                        )

                        val seasons = (1..5).toList()
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 48.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(seasons) { season ->
                                val isSelected = season == 1
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(
                                            if (isSelected) Color.White else Color.White.copy(alpha = 0.12f)
                                        )
                                        .padding(horizontal = 20.dp, vertical = 10.dp)
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
                            modifier = Modifier.padding(horizontal = 48.dp, bottom = 12.dp)
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
                                        val route = Screen.Details.createRoute(movie.id.toString())
                                        navController.navigate(route)
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
                            modifier = Modifier.padding(horizontal = 48.dp, bottom = 12.dp)
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
                                        val route = Screen.Details.createRoute(movie.id.toString())
                                        navController.navigate(route)
                                    },
                                    modifier = Modifier.height(180.dp)
                                )
                            }
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
                            modifier = Modifier.padding(horizontal = 48.dp, bottom = 12.dp)
                        )

                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 48.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
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
                }
            }
        }
    }
}
