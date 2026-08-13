package com.maxstream.app.ui.screens.search

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.maxstream.app.R
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.di.Modules
import com.maxstream.app.ui.components.TvKeyboard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.tv.TvKeyboardFocusManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

// ─────────────────────────────────────────────────────────────────────────────
// SearchScreen
// Matches Dart TvSearchScreen:
//  - Left panel: keyboard
//  - Right panel: "Discover" grid when no query (trending + popular mix)
//                 "Movies" + "TV Series" sections when searching
//  - Cards show poster + title + type badge + rating + year (full metadata)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun SearchScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit = {},
    isVisible: Boolean = true,
) {
    val scope = rememberCoroutineScope()

    // ── State ──────────────────────────────────────────────────────────────
    var query       by remember { mutableStateOf("") }
    var discoverItems by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var movieResults  by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var seriesResults by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var isSearching   by remember { mutableStateOf(false) }
    var searchError   by remember { mutableStateOf<String?>(null) }
    var debounceJob   by remember { mutableStateOf<Job?>(null) }

    // ── Focus ──────────────────────────────────────────────────────────────
    val keyboardFocusManager  = remember { TvKeyboardFocusManager() }
    val keyboardFocusRequester = remember { FocusRequester() }
    val resultsFocusRequester  = remember { FocusRequester() }

    // ── Load discover content on first entry (mix of trending + popular) ──
    LaunchedEffect(Unit) {
        try {
            val trending = Modules.catalogRepository.trendingMovies()
            val trendingTv = Modules.catalogRepository.trendingSeries()
            val popular = Modules.catalogRepository.popularMovies()
            val popularTv = Modules.catalogRepository.popularSeries()
            val topRated = Modules.catalogRepository.topRatedMovies()
            val topRatedTv = Modules.catalogRepository.topRatedSeries()
            // Mix and deduplicate by id+type, same as Dart
            val seen = mutableSetOf<String>()
            discoverItems = (
                trending.take(12) + trendingTv.take(12) +
                popular.take(12)  + popularTv.take(12)  +
                topRated.take(12) + topRatedTv.take(12)
            ).filter { item ->
                seen.add("${item.mediaType}:${item.id}")
            }
        } catch (_: Exception) { /* silent — grid just stays empty */ }
    }

    // ── Debounced search ───────────────────────────────────────────────────
    LaunchedEffect(query) {
        debounceJob?.cancel()
        if (query.trim().length < 2) {
            movieResults = emptyList(); seriesResults = emptyList()
            searchError = null; isSearching = false
            return@LaunchedEffect
        }
        debounceJob = scope.launch {
            delay(400)
            if (!isActive) return@launch
            isSearching = true; searchError = null
            try {
                val results = Modules.catalogRepository.search(query.trim())
                movieResults  = results.filter { it.mediaType == "movie" }
                seriesResults = results.filter { it.mediaType == "tv" }
            } catch (e: Exception) {
                searchError = e.message
                movieResults = emptyList(); seriesResults = emptyList()
            } finally {
                isSearching = false
            }
        }
    }

    // ── Focus seed on tab visible ──────────────────────────────────────────
    LaunchedEffect(isVisible) {
        if (!isVisible) return@LaunchedEffect
        repeat(6) { attempt ->
            delay(50L * (attempt + 1))
            val ok = runCatching { keyboardFocusRequester.requestFocus() }
            if (ok.isSuccess) return@LaunchedEffect
        }
    }

    // ── Layout ─────────────────────────────────────────────────────────────
    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(Color(0xF20A0D13), Color(0xE6111620), Color(0xFF050608))
                )
            )
    ) {
        // ── Left panel: keyboard ───────────────────────────────────────────
        Column(
            modifier = Modifier
                .width(360.dp)
                .fillMaxHeight()
                .padding(horizontal = 34.dp, vertical = 24.dp),
        ) {
            Text(
                text = "Search",
                color = Color.White,
                fontSize = 34.sp,
                fontWeight = FontWeight.W800,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = "Find movies and series",
                color = Color.White.copy(alpha = 0.55f),
                fontSize = 15.sp,
            )
            Spacer(Modifier.height(24.dp))

            TvKeyboard(
                onInput  = { text -> query = text },
                onSubmit = { /* searching via debounce */ },
                initialText = query,
                focusManager = keyboardFocusManager,
                focusRequester = keyboardFocusRequester,
                onMoveRight = {
                    keyboardFocusManager.focusOnContent()
                    runCatching { resultsFocusRequester.requestFocus() }
                },
                onMoveLeft = onReturnToSidebar,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Spacer(Modifier.width(24.dp))

        // ── Right panel: results / discover ───────────────────────────────
        val panelKey = "${query.trim()}:$isSearching:${movieResults.size}:${seriesResults.size}"

        AnimatedContent(
            targetState = panelKey,
            transitionSpec = {
                fadeIn(tween(350)) togetherWith fadeOut(tween(180))
            },
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .focusRequester(resultsFocusRequester)
                .focusable()
                .padding(end = 34.dp, top = 24.dp, bottom = 24.dp),
            label = "searchResults",
        ) {
            when {
                isSearching -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = Color(0xFFE50914), strokeWidth = 3.dp)
                }

                searchError != null -> SearchMessage(
                    icon = R.drawable.ic_search,
                    text = "Search unavailable. Please try again."
                )

                query.trim().length >= 2 && movieResults.isEmpty() && seriesResults.isEmpty() ->
                    SearchMessage(
                        icon = R.drawable.ic_search,
                        text = "No matches for \"${query.trim()}\""
                    )

                query.trim().length >= 2 -> {
                    // Search results: Movies section + TV Series section
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 56.dp),
                        verticalArrangement = Arrangement.spacedBy(32.dp),
                    ) {
                        item {
                            Text(
                                text = "Results for \"${query.trim()}\"",
                                color = Color.White,
                                fontSize = 29.sp,
                                fontWeight = FontWeight.W800,
                                modifier = Modifier.padding(bottom = 8.dp),
                            )
                        }
                        if (movieResults.isNotEmpty()) {
                            item {
                                SearchSection(
                                    title = "Movies",
                                    items = movieResults,
                                    navController = navController,
                                )
                            }
                        }
                        if (seriesResults.isNotEmpty()) {
                            item {
                                SearchSection(
                                    title = "TV Series",
                                    items = seriesResults,
                                    navController = navController,
                                )
                            }
                        }
                    }
                }

                else -> {
                    // Discover grid (no query) — same as Dart default state
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 56.dp),
                        verticalArrangement = Arrangement.spacedBy(32.dp),
                    ) {
                        item {
                            Text(
                                text = "Discover",
                                color = Color.White,
                                fontSize = 29.sp,
                                fontWeight = FontWeight.W800,
                                modifier = Modifier.padding(bottom = 8.dp),
                            )
                        }
                        if (discoverItems.isNotEmpty()) {
                            item {
                                SearchSection(
                                    title = null,
                                    items = discoverItems,
                                    navController = navController,
                                )
                            }
                        } else {
                            item {
                                Box(
                                    modifier = Modifier.fillMaxWidth().height(200.dp),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    CircularProgressIndicator(
                                        color = Color(0xFFE50914),
                                        strokeWidth = 2.dp,
                                        modifier = Modifier.size(32.dp),
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

// ─────────────────────────────────────────────────────────────────────────────
// Section: header + grid
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SearchSection(
    title: String?,
    items: List<MediaItem>,
    navController: NavController,
) {
    Column {
        if (title != null) {
            SectionHeader(title)
            Spacer(Modifier.height(12.dp))
        }
        LazyVerticalGrid(
            columns = GridCells.Adaptive(minSize = 120.dp),
            modifier = Modifier.fillMaxWidth().height(
                // Approximate height: rows × card height. Each card is ~190dp.
                // Use a non-scrollable grid inside the parent LazyColumn.
                ((items.size + 4) / 5 * 210 + 20).dp
            ),
            contentPadding = PaddingValues(0.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            userScrollEnabled = false,
        ) {
            items(items, key = { "${it.mediaType}:${it.id}" }) { item ->
                SearchCard(item = item, navController = navController)
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(width = 4.dp, height = 23.dp)
                .background(Color(0xFFE50914), RoundedCornerShape(4.dp))
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = title,
            color = Color.White,
            fontSize = 21.sp,
            fontWeight = FontWeight.W700,
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card — poster + metadata (matches Dart TvContentCard: rating, year, type)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SearchCard(
    item: MediaItem,
    navController: NavController,
) {
    var isFocused by remember { mutableStateOf(false) }
    val isSeries = item.mediaType == "tv"
    val year = item.releaseDate.take(4).toIntOrNull()

    Box(
        modifier = Modifier
            .aspectRatio(0.68f)
            .clip(RoundedCornerShape(10.dp))
            .background(Color(0xFF1A1A2E))
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(10.dp),
            )
            .focusable()
            .onFocusChanged { state -> isFocused = state.hasFocus }
            .onKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown &&
                    (event.key == Key.Enter || event.key == Key.DirectionCenter)
                ) {
                    val route = if (isSeries)
                        Screen.Series.createRoute(item.id.toString())
                    else
                        Screen.Details.createRoute(item.id.toString())
                    navController.navigate(route)
                    true
                } else false
            }
            .clickable {
                val route = if (isSeries)
                    Screen.Series.createRoute(item.id.toString())
                else
                    Screen.Details.createRoute(item.id.toString())
                navController.navigate(route)
            }
    ) {
        // Poster image
        AsyncImage(
            model = item.posterUrl.ifEmpty { item.backdropUrl },
            contentDescription = item.title,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
            placeholder = painterResource(R.drawable.ic_launcher_foreground),
            error = painterResource(R.drawable.ic_launcher_foreground),
        )

        // Gradient overlay at bottom
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.55f)
                .align(Alignment.BottomCenter)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color(0xE6000000))
                    )
                )
        )

        // Metadata overlay
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            // Type badge
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(
                        if (isSeries) Color(0xFF1565C0) else Color(0xFFB71C1C)
                    )
                    .padding(horizontal = 5.dp, vertical = 2.dp),
            ) {
                Text(
                    text = if (isSeries) "TV" else "Movie",
                    color = Color.White,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                )
            }

            // Title
            Text(
                text = item.title,
                color = Color.White,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 14.sp,
            )

            // Rating + year row
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (item.voteAverage > 0) {
                    Text(
                        text = "★ ${String.format("%.1f", item.voteAverage)}",
                        color = Color(0xFFFFD700),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                    )
                }
                if (year != null) {
                    Text(
                        text = "$year",
                        color = Color.White.copy(alpha = 0.6f),
                        fontSize = 10.sp,
                    )
                }
            }
        }

        // Focus glow border
        if (isFocused) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .border(
                        width = 2.dp,
                        color = Color.White.copy(alpha = 0.9f),
                        shape = RoundedCornerShape(10.dp),
                    )
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error message
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SearchMessage(icon: Int, text: String) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Icon(
                painter = painterResource(icon),
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.38f),
                modifier = Modifier.size(58.dp),
            )
            Text(
                text = text,
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 18.sp,
                fontWeight = FontWeight.Normal,
            )
        }
    }
}
