package com.maxstream.app.ui.screens.genre

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.di.Modules
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background

@Composable
fun GenreScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit = {},
    isVisible: Boolean = true,
    initialMediaType: String = "all",
) {
    var genres        by remember { mutableStateOf<List<Pair<Int, String>>>(emptyList()) }
    var selectedGenre by remember { mutableStateOf<Pair<Int, String>?>(null) }
    var genreItems    by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var loading       by remember { mutableStateOf(true) }
    var error         by remember { mutableStateOf<String?>(null) }
    var focusedGenreIndex by remember { mutableIntStateOf(0) }

    val firstGenreFocusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        try {
            val movieGenres = Modules.catalogRepository.genres("movie")
            val tvGenres    = Modules.catalogRepository.genres("tv")
            // Merge both maps (movie + tv), dedup by id, sort by name
            genres = (movieGenres + tvGenres).entries
                .map { Pair(it.key, it.value) }
                .sortedBy { it.second }
        } catch (e: Exception) {
            error = e.message
        } finally {
            loading = false
        }
    }

    LaunchedEffect(selectedGenre) {
        val genre = selectedGenre ?: run { genreItems = emptyList(); return@LaunchedEffect }
        try {
            val movies = Modules.catalogRepository.catalogByGenre(genre.first, "movie")
            val tv     = Modules.catalogRepository.catalogByGenre(genre.first, "tv")
            genreItems = (movies + tv).distinctBy { it.id to it.mediaType }
        } catch (e: Exception) {
            error = e.message
        }
    }

    // Seed focus on first genre chip when tab becomes visible
    LaunchedEffect(isVisible, loading) {
        if (!isVisible || loading) return@LaunchedEffect
        kotlinx.coroutines.delay(80)
        runCatching { firstGenreFocusRequester.requestFocus() }
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
            else -> Column(modifier = Modifier.fillMaxSize()) {
                // ── Header ────────────────────────────────────────────────
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 48.dp)
                        .padding(horizontal = 48.dp),
                ) {
                    Text(
                        text = if (selectedGenre == null) "Browse by Genre" else selectedGenre!!.second,
                        color = Color.White,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.ExtraBold,
                    )
                    if (selectedGenre != null) {
                        Spacer(Modifier.height(8.dp))
                        GenreBackButton(
                            onClick = { selectedGenre = null },
                            onReturnToSidebar = onReturnToSidebar,
                        )
                    }
                }

                Spacer(Modifier.height(24.dp))

                // ── Genre chips ───────────────────────────────────────────
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 48.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(genres.size) { index ->
                        val genre = genres[index]
                        val isSelected = genre == selectedGenre
                        val focusRequester = if (index == 0) firstGenreFocusRequester
                                            else remember { FocusRequester() }
                        var isFocused by remember { mutableStateOf(false) }

                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .background(
                                    when {
                                        isSelected -> Color(0xFFE50914)
                                        isFocused  -> Color(0xFF2A2A2A)
                                        else       -> Color(0xFF1A1A1A)
                                    }
                                )
                                .border(
                                    width = if (isFocused) 2.dp else 1.dp,
                                    color = if (isFocused) Color.White else Color.White.copy(alpha = 0.15f),
                                    shape = RoundedCornerShape(20.dp),
                                )
                                .focusRequester(focusRequester)
                                .focusable()
                                .onFocusChanged { state ->
                                    isFocused = state.hasFocus
                                    if (state.hasFocus) focusedGenreIndex = index
                                }
                                .onKeyEvent { event ->
                                    if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                                    when (event.key) {
                                        Key.DirectionLeft -> {
                                            if (index == 0) { onReturnToSidebar(); true }
                                            else false
                                        }
                                        Key.Enter, Key.DirectionCenter -> {
                                            selectedGenre = genre; true
                                        }
                                        else -> false
                                    }
                                }
                                .clickable { selectedGenre = genre }
                                .padding(horizontal = 20.dp, vertical = 10.dp),
                        ) {
                            Text(
                                text = genre.second,
                                color = if (isSelected || isFocused) Color.White else Color.White.copy(alpha = 0.7f),
                                fontSize = 14.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            )
                        }
                    }
                }

                Spacer(Modifier.height(24.dp))

                // ── Content grid ──────────────────────────────────────────
                if (genreItems.isNotEmpty()) {
                    var focusedCardIndex by remember { mutableIntStateOf(-1) }

                    LazyVerticalGrid(
                        columns = GridCells.Adaptive(minSize = 140.dp),
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 48.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        items(genreItems) { item ->
                            val idx = genreItems.indexOf(item)
                            ContentCard(
                                posterUrl = item.posterUrl,
                                title = item.title,
                                rating = item.voteAverage.takeIf { it > 0 },
                                isFocused = focusedCardIndex == idx,
                                onFocusChanged = { focused ->
                                    if (focused) focusedCardIndex = idx
                                    else if (focusedCardIndex == idx) focusedCardIndex = -1
                                },
                                onClick = {
                                    val route = if (item.mediaType == "tv")
                                        Screen.Series.createRoute(item.id.toString())
                                    else
                                        Screen.Details.createRoute(item.id.toString())
                                    navController.navigate(route)
                                },
                                modifier = Modifier.height(180.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GenreBackButton(onClick: () -> Unit, onReturnToSidebar: () -> Unit) {
    var isFocused by remember { mutableStateOf(false) }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (isFocused) Color(0xFF2A2A2A) else Color(0xFF1A1A1A))
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) Color.White else Color.White.copy(alpha = 0.2f),
                shape = RoundedCornerShape(8.dp),
            )
            .focusable()
            .onFocusChanged { state -> isFocused = state.hasFocus }
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionLeft  -> { onReturnToSidebar(); true }
                    Key.Enter, Key.DirectionCenter -> { onClick(); true }
                    else -> false
                }
            }
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Text(
            text = "← All Genres",
            color = if (isFocused) Color.White else Color.White.copy(alpha = 0.7f),
            fontSize = 14.sp,
        )
    }
}
