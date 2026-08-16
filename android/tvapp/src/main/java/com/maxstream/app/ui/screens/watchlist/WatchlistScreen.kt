package com.maxstream.app.ui.screens.watchlist

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.maxstream.app.R
import com.maxstream.app.data.local.WatchlistRepository
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.theme.Primary
import com.maxstream.app.ui.tv.GridDesc
import com.maxstream.app.ui.tv.GridNavState
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val TABS = listOf("All", "Movies", "TV Shows")
private const val COLUMNS = 5
private const val GRID_ID = "watchlist:grid"

// ─────────────────────────────────────────────────────────────────────────────
// WatchlistScreen (Tab 5)
//
// Matches Dart TvWatchlistScreen:
//  - Header + tab chips (All / Movies / TV Shows)
//  - 5-column poster grid
//  - D-pad: LEFT on first tab → sidebar, DOWN on a tab → grid,
//           UP/LEFT/ESC from a grid card → tabs, Enter → details
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun WatchlistScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit = {},
    isVisible: Boolean = true,
    focusKey: Int = 0,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var watchlist    by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var selectedTab  by remember { mutableIntStateOf(0) }
    var loading      by remember { mutableStateOf(true) }
    var error        by remember { mutableStateOf<String?>(null) }

    val tabFocusRequesters = remember { List(TABS.size) { FocusRequester() } }
    val gridNav = remember { GridNavState(COLUMNS) }
    val gridState = rememberLazyGridState()

    LaunchedEffect(Unit) {
        try {
            // Pull the phone's watchlist into local storage so the TV shows the
            // same saved titles as the phone (same account).
            runCatching { com.maxstream.app.data.repository.CloudSyncRepository.pullToDevice(context) }
            watchlist = WatchlistRepository.getAll(context)
        } catch (e: Exception) {
            error = e.message
        } finally {
            loading = false
        }
    }

    // Re-pull + reload whenever the tab becomes visible again (e.g. returning
    // from details after toggling the watchlist, or from the sidebar).
    LaunchedEffect(isVisible, focusKey) {
        if (!isVisible) return@LaunchedEffect
        runCatching { com.maxstream.app.data.repository.CloudSyncRepository.pullToDevice(context) }
        watchlist = runCatching { WatchlistRepository.getAll(context) }.getOrDefault(watchlist)
    }

    val filtered = when (selectedTab) {
        1    -> watchlist.filter { it.mediaType == "movie" }
        2    -> watchlist.filter { it.mediaType == "tv" }
        else -> watchlist
    }

    // Keep the navigator in sync with the visible grid.
    val grids = remember(filtered.size) {
        if (filtered.isNotEmpty()) listOf(GridDesc(GRID_ID, filtered.size))
        else emptyList()
    }
    gridNav.setGrids(grids)
    gridNav.clearMissingGrids()
    LaunchedEffect(filtered.size) {
        if (filtered.isNotEmpty()) gridNav.registerGrid(GRID_ID, gridState)
    }
    DisposableEffect(Unit) {
        onDispose { gridNav.unregisterGrid(GRID_ID) }
    }

    // Seed focus when the tab becomes visible, or re-seed when focus returns
    // from the sidebar (focusKey bump). Restores the grid if a card was
    // focused, otherwise the selected tab chip. First attempt is immediate.
    LaunchedEffect(isVisible, loading, focusKey) {
        if (!isVisible || loading) return@LaunchedEffect
        if (gridNav.activeGridId == GRID_ID && filtered.isNotEmpty()) {
            gridNav.focusFirstCard(GRID_ID, null, scope)
            return@LaunchedEffect
        }
        var attempt = 0
        while (attempt < 6) {
            if (attempt > 0) delay(50L * attempt)
            // requestFocus() throws while the node is unattached, so retry on
            // exception until the tab chip is composed (isSuccess == no throw).
            val ok = runCatching { tabFocusRequesters[selectedTab].requestFocus() }.isSuccess
            if (ok) return@LaunchedEffect
            attempt++
        }
    }

    fun focusTab(index: Int) {
        val target = index.coerceIn(0, TABS.lastIndex)
        // Forget the grid was focused: activeGridId was never cleared when focus
        // moved back to the tabs, so the next re-seed wrongly restored the grid
        // instead of the tab row the user actually left from.
        gridNav.clearActiveGrid()
        runCatching { tabFocusRequesters[target].requestFocus() }
    }

    fun focusGrid() {
        if (filtered.isNotEmpty()) gridNav.focusFirstCard(GRID_ID, null, scope)
    }

    fun onTabKey(index: Int, event: KeyEvent): Boolean {
        if (event.type != KeyEventType.KeyDown) return false
        return when (event.key) {
            Key.DirectionLeft -> {
                if (index == 0) onReturnToSidebar() else focusTab(index - 1)
                true
            }
            Key.DirectionRight -> {
                if (index < TABS.lastIndex) focusTab(index + 1)
                true
            }
            Key.DirectionDown -> { focusGrid(); true }
            Key.DirectionUp -> true
            Key.Back, Key.Escape -> { onReturnToSidebar(); true }
            Key.Enter, Key.DirectionCenter -> { selectedTab = index; true }
            else -> false
        }
    }

    fun onCardKey(index: Int, event: KeyEvent): Boolean = gridNav.onCardKey(
        gridId = GRID_ID,
        index = index,
        event = event,
        outerListState = null,
        scope = scope,
        onReturnToKeyboard = { focusTab(selectedTab) },
        onReturnToSidebar = { focusTab(selectedTab) },
    )

    Box(modifier = Modifier.fillMaxSize().background(Background)) {
        // Header + tab chips are ALWAYS composed (matches Dart) so the tabs
        // stay reachable even when the list is empty or loading.
        Column(modifier = Modifier.fillMaxSize()) {
            Text(
                text = "My Watchlist",
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.ExtraBold,
                modifier = Modifier
                    .padding(top = 48.dp)
                    .padding(horizontal = 48.dp),
            )

            Spacer(Modifier.height(20.dp))

            // ── Tab chips ─────────────────────────────────────────────
            Row(
                modifier = Modifier.padding(horizontal = 48.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TABS.forEachIndexed { index, label ->
                    WatchlistTabChip(
                        label = label,
                        isSelected = index == selectedTab,
                        focusRequester = tabFocusRequesters[index],
                        onSelect = { selectedTab = index },
                        onKeyEvent = { onTabKey(index, it) },
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            // ── Content ───────────────────────────────────────────────
            when {
                loading -> Box(
                    Modifier.fillMaxWidth().weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(color = Primary)
                }

                error != null -> Box(
                    Modifier.fillMaxWidth().weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Error: $error",
                        color = Color(0xFFCF6679),
                    )
                }

                watchlist.isEmpty() -> Box(
                    Modifier.fillMaxWidth().weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Your watchlist is empty", color = Color.White, fontSize = 18.sp)
                        Spacer(Modifier.height(16.dp))
                        Text(
                            "Browse content to add items",
                            color = Color.White.copy(alpha = 0.5f),
                            fontSize = 14.sp,
                        )
                    }
                }

                filtered.isEmpty() -> Box(
                    Modifier.fillMaxWidth().weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "No items in this category",
                        color = Color.White.copy(alpha = 0.6f),
                    )
                }

                else -> {
                    var focusedIndex by remember { mutableIntStateOf(-1) }

                    LazyVerticalGrid(
                        state = gridState,
                        columns = GridCells.Fixed(COLUMNS),
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            start = 48.dp, end = 48.dp, bottom = 56.dp
                        ),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        items(
                            count = filtered.size,
                            key = { index -> "${filtered[index].mediaType}:${filtered[index].id}" },
                        ) { index ->
                            val item = filtered[index]
                            WatchlistCard(
                                item = item,
                                isFocused = focusedIndex == index,
                                focusRequester = gridNav.requester(GRID_ID, index),
                                onFocusChanged = { focused ->
                                    if (focused) focusedIndex = index
                                    else if (focusedIndex == index) focusedIndex = -1
                                },
                                onKeyEvent = { onCardKey(index, it) },
                                onClick = {
                                    navController.navigate(Screen.Details.createRoute(item.id.toString(), item.mediaType))
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun WatchlistTabChip(
    label: String,
    isSelected: Boolean,
    focusRequester: FocusRequester,
    onSelect: () -> Unit,
    onKeyEvent: (KeyEvent) -> Boolean,
) {
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
            .onFocusChanged { state -> isFocused = state.hasFocus }
            .onKeyEvent(onKeyEvent)
            .clickable(onClick = onSelect)
            .padding(horizontal = 22.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = if (isSelected || isFocused) Color.White else Color.White.copy(alpha = 0.65f),
            fontSize = 15.sp,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid card (poster + rating + type badge) — matches Search/Genre card style
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun WatchlistCard(
    item: MediaItem,
    isFocused: Boolean,
    focusRequester: FocusRequester,
    onFocusChanged: (Boolean) -> Unit,
    onKeyEvent: (KeyEvent) -> Boolean,
    onClick: () -> Unit,
) {
    val isSeries = item.mediaType == "tv"
    val year = item.releaseDate.take(4).toIntOrNull()

    Box(
        modifier = Modifier
            .width(130.dp)
            .height(190.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Color(0xFF1A1A1E))
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(10.dp),
            )
            .focusRequester(focusRequester)
            .onFocusChanged { state -> onFocusChanged(state.hasFocus) }
            .onKeyEvent(onKeyEvent)
            .clickable(onClick = onClick),
    ) {
        AsyncImage(
            model = item.posterUrl.ifEmpty { item.backdropUrl },
            contentDescription = item.title,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
            placeholder = painterResource(R.drawable.ic_launcher_foreground),
            error = painterResource(R.drawable.ic_launcher_foreground),
        )
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
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(if (isSeries) Color(0xFF1565C0) else Color(0xFFB71C1C))
                    .padding(horizontal = 5.dp, vertical = 2.dp),
            ) {
                Text(
                    text = if (isSeries) "TV" else "Movie",
                    color = Color.White,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
            Text(
                text = item.title,
                color = Color.White,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 14.sp,
            )
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
        if (isFocused) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .border(2.dp, Color.White.copy(alpha = 0.9f), RoundedCornerShape(10.dp))
            )
        }
    }
}