package com.maxstream.app.ui.screens.genre

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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.di.Modules
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background

@Composable
fun GenreScreen(navController: NavController, onReturnToSidebar: () -> Unit = {}) {
    var genres by remember { mutableStateOf<List<Pair<Int, String>>>(emptyList()) }
    var selectedGenre by remember { mutableStateOf<Pair<Int, String>?>(null) }
    var genreItems by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        try {
            val movieGenres = Modules.catalogRepository.genres("movie")
            val tvGenres = Modules.catalogRepository.genres("tv")
            val combined = (movieGenres + tvGenres).toList().distinctBy { it.first }
            genres = combined.sortedBy { it.second }
        } catch (e: Exception) {
            error = e.message
        } finally {
            loading = false
        }
    }

    LaunchedEffect(selectedGenre) {
        val genre = selectedGenre
        if (genre != null) {
            try {
                val movieResults = Modules.catalogRepository.catalogByGenre(genre.first, "movie")
                val tvResults = Modules.catalogRepository.catalogByGenre(genre.first, "tv")
                genreItems = (movieResults + tvResults).distinctBy { it.id to it.mediaType }
            } catch (e: Exception) {
                error = e.message
            }
        } else {
            genreItems = emptyList()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Background)) {
        if (loading) {
            CircularProgressIndicator(
                color = com.maxstream.app.ui.theme.Primary,
                modifier = Modifier.align(Alignment.Center)
            )
        } else if (error != null) {
            Text(
                text = "Error: $error",
                color = Color(0xFFCF6679),
                modifier = Modifier.align(Alignment.Center)
            )
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 56.dp)
            ) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 48.dp)
                            .padding(horizontal = 48.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = if (selectedGenre == null) "Genres" else selectedGenre!!.second,
                            color = Color.White,
                            fontSize = 28.sp,
                            fontWeight = androidx.compose.ui.text.font.FontWeight.ExtraBold
                        )
                        if (selectedGenre != null) {
                            TextButton(onClick = { selectedGenre = null }) {
                                Text("Back to genres")
                            }
                        }
                    }
                }

                if (selectedGenre == null) {
                    item {
                        Column(
                            modifier = Modifier
                                .padding(top = 24.dp)
                                .padding(horizontal = 48.dp)
                        ) {
                            LazyRow(
                                contentPadding = PaddingValues(horizontal = 48.dp),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                items(genres) { genre ->
                                    val isSelected = genre == selectedGenre
                                    TextButton(
                                        onClick = { selectedGenre = genre },
                                        modifier = Modifier
                                            .focusRequester(remember { FocusRequester() })
                                    ) {
                                        Text(
                                            text = genre.second,
                                            color = if (isSelected) Color.Black else Color.White
                                        )
                                    }
                                }
                            }
                        }
                    }
                } else if (genreItems.isNotEmpty()) {
                    item {
                        Column(modifier = Modifier.padding(top = 24.dp)) {
                            LazyRow(
                                contentPadding = PaddingValues(horizontal = 48.dp),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                items(genreItems) { item ->
                                    val isSeries = item.mediaType == "tv"
                                    ContentCard(
                                        posterUrl = item.posterUrl,
                                        title = item.title,
                                        rating = item.voteAverage.takeIf { it > 0 },
                                        onClick = {
                                            val route = if (isSeries) {
                                                Screen.Series.createRoute(item.id.toString())
                                            } else {
                                                Screen.Details.createRoute(item.id.toString())
                                            }
                                            navController.navigate(route)
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
}
