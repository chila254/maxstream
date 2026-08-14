package com.maxstream.app.ui.screens.search

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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.compose.runtime.mutableIntStateOf
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
import androidx.compose.ui.input.key.onKeyEvent
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
import com.maxstream.app.ui.tv.GridDesc
import com.maxstream.app.ui.tv.GridNavState
import com.maxstream.app.ui.tv.TvKeyboardFocusManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

private const val COLUMNS = 5

// ─────────────────────────────────────────────────────────────────────────────
// SearchScreen
// Matches Dart TvSearchScreen:
//  - Left panel: keyboard
//  - Right panel: "Discover" grid when no query (trending + popular mix)
//                 "Movies" + "TV Series" sections when searching
//  - D-pad: RIGHT from keyboard's last key → first result card
//           LEFT on first column / UP on first row → back to keyboard
//           ESC/Back from a card → sidebar
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun SearchScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit = {},
    isVisible: Boolean = true,
    focusKey: Int = 0,
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
    val gridNav = remember { GridNavState(COLUMNS) }
    val resultsListState = rememberLazyListState()

    val showingResults =
        query.trim().length >= 2 && !isSearching &&
        (movieResults.isNotEmpty() || seriesResults.isNotEmpty())

    // Ordered grid sections of the right panel — must mirror the LazyColumn items.
    val grids = remember(showingResults, movieResults.size, seriesResults.size, discoverItems.size) {
        if (showingResults) {
            buildList {
                // LazyColumn items: 0 = "Results for" header, then one grid per
                // non-empty section. Section index = item index inside the column.
                var index = 1
                if (movieResults.isNotEmpty()) add(GridDesc("search:movies", movieResults.size, sectionIndex = index++))
                if (seriesResults.isNotEmpty()) add(GridDesc("search:series", seriesResults.size, sectionIndex = index++))
            }
        } else {
            buildList {
                if (discoverItems.isNotEmpty()) add(GridDesc("search:discover", discoverItems.size, sectionIndex = 1))
            }
        }
    }
    gridNav.setGrids(grids)
    gridNav.clearMissingGrids()

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

    // ── Focus seed on tab visible / focus returns from the sidebar ─────────
    // Re-seeds the keyboard so navigation never parks on the invisible box
    // when returning to the same tab.
    LaunchedEffect(isVisible, focusKey) {
        if (!isVisible) return@LaunchedEffect
        repeat(6) { attempt ->
            delay(50L * (attempt + 1))
            val ok = runCatching { keyboardFocusRequester.requestFocus() }
            if (ok.isSuccess) return@LaunchedEffect
        }
    }

    fun returnToKeyboard() {
        keyboardFocusManager.activateKeyboard()
        runCatching { keyboardFocusRequester.requestFocus() }
    }

    fun moveToResults() {
        keyboardFocusManager.focusOnContent()
        val first = gridNav.grids.firstOrNull { it.count > 0 }
        if (first != null) gridNav.focusFirstCard(first.id, resultsListState, scope)
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
                onMoveRight = { moveToResults() },
                onMoveLeft = onReturnToSidebar,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Spacer(Modifier.width(24.dp))

        // ── Right panel: results / discover ───────────────────────────────
        LazyColumn(
            state = resultsListState,
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(end = 34.dp, top = 24.dp, bottom = 24.dp),
            contentPadding = PaddingValues(bottom = 56.dp),
            verticalArrangement = Arrangement.spacedBy(32.dp),
        ) {
            when {
                isSearching -> item {
                    Box(Modifier.fillMaxWidth().height(280.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Color(0xFFE50914), strokeWidth = 3.dp)
                    }
                }

                searchError != null -> item {
                    SearchMessage(
                        icon = R.drawable.ic_search,
                        text = "Search unavailable. Please try again."
                    )
                }

                query.trim().length >= 2 && movieResults.isEmpty() && seriesResults.isEmpty() ->
                    item {
                        SearchMessage(
                            icon = R.drawable.ic_search,
                            text = "No matches for \"${query.trim()}\""
                        )
                    }

                query.trim().length >= 2 -> {
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
                                gridId = "search:movies",
                                sectionIndex = 1,
                                gridNav = gridNav,
                                outerListState = resultsListState,
                                navController = navController,
                                onReturnToKeyboard = { returnToKeyboard() },
                                onReturnToSidebar = onReturnToSidebar,
                            )
                        }
                    }
                    if (seriesResults.isNotEmpty()) {
                        item {
                            SearchSection(
                                title = "TV Series",
                                items = seriesResults,
                                gridId = "search:series",
                                sectionIndex = 2,
                                gridNav = gridNav,
                                outerListState = resultsListState,
                                navController = navController,
                                onReturnToKeyboard = { returnToKeyboard() },
                                onReturnToSidebar = onReturnToSidebar,
                            )
                        }
                    }
                }

                else -> {
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
                                gridId = "search:discover",
                                sectionIndex = 1,
                                gridNav = gridNav,
                                outerListState = resultsListState,
                                navController = navController,
                                onReturnToKeyboard = { returnToKeyboard() },
                                onReturnToSidebar = onReturnToSidebar,
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

// ─────────────────────────────────────────────────────────────────────────────
// Section: header + grid
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SearchSection(
    title: String?,
    items: List<MediaItem>,
    gridId: String,
    sectionIndex: Int,
    gridNav: GridNavState,
    outerListState: LazyListState,
    navController: NavController,
    onReturnToKeyboard: () -> Unit,
    onReturnToSidebar: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var focusedIndex by remember { mutableIntStateOf(-1) }

    Column {
        if (title != null) {
            SectionHeader(title)
            Spacer(Modifier.height(12.dp))
        }
        LazyVerticalGrid(
            columns = GridCells.Fixed(COLUMNS),
            modifier = Modifier.fillMaxWidth().height(
                // Approximate height: rows × card height. Each card is ~190dp.
                // Non-scrollable grid nested in the parent LazyColumn (all items composed).
                ((items.size + COLUMNS - 1) / COLUMNS * 210 + 20).dp
            ),
            contentPadding = PaddingValues(0.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            userScrollEnabled = false,
        ) {
            items(
                count = items.size,
                key = { index -> "${itemKey(items[index])}" },
            ) { index ->
                val item = items[index]
                SearchCard(
                    item = item,
                    navController = navController,
                    isFocused = focusedIndex == index,
                    focusRequester = gridNav.requester(gridId, index),
                    onFocusChanged = { focused ->
                        if (focused) focusedIndex = index
                        else if (focusedIndex == index) focusedIndex = -1
                    },
                    onKeyEvent = { event ->
                        gridNav.onCardKey(
                            gridId = gridId,
                            index = index,
                            event = event,
                            outerListState = outerListState,
                            scope = scope,
                            onReturnToKeyboard = onReturnToKeyboard,
                            onReturnToSidebar = onReturnToSidebar,
                        )
                    },
                )
            }
        }
    }
}

private fun itemKey(item: MediaItem) = "${item.mediaType}:${item.id}"

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
    isFocused: Boolean,
    focusRequester: FocusRequester,
    onFocusChanged: (Boolean) -> Unit,
    onKeyEvent: (androidx.compose.ui.input.key.KeyEvent) -> Boolean,
) {
    val isSeries = item.mediaType == "tv"
    val year = item.releaseDate.take(4).toIntOrNull()

    Box(
        modifier = Modifier
            .width(130.dp)
            .height(190.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Color(0xFF1A1A2E))
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(10.dp),
            )
            .focusRequester(focusRequester)
            .focusable()
            .onFocusChanged { state -> onFocusChanged(state.hasFocus) }
            .onKeyEvent(onKeyEvent)
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
    Box(
        modifier = Modifier.fillMaxWidth().height(280.dp),
        contentAlignment = Alignment.Center,
    ) {
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