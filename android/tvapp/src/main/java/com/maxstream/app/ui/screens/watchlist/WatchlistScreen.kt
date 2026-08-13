package com.maxstream.app.ui.screens.watchlist

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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.maxstream.app.data.local.WatchlistRepository
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.theme.Primary

private val TABS = listOf("All", "Movies", "TV Shows")

@Composable
fun WatchlistScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit = {},
    isVisible: Boolean = true,
) {
    val context = LocalContext.current

    var watchlist    by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var selectedTab  by remember { mutableIntStateOf(0) }
    var loading      by remember { mutableStateOf(true) }
    var error        by remember { mutableStateOf<String?>(null) }

    // One FocusRequester per tab chip so we can seed the first one
    val tabFocusRequesters = remember { List(TABS.size) { FocusRequester() } }

    LaunchedEffect(Unit) {
        try {
            watchlist = WatchlistRepository.getAll(context)
        } catch (e: Exception) {
            error = e.message
        } finally {
            loading = false
        }
    }

    // Seed focus on first tab chip when visible
    LaunchedEffect(isVisible, loading) {
        if (!isVisible || loading) return@LaunchedEffect
        repeat(6) { attempt ->
            kotlinx.coroutines.delay(50L * (attempt + 1))
            val ok = runCatching { tabFocusRequesters[0].requestFocus() }
            if (ok.isSuccess) return@LaunchedEffect
        }
    }

    val filtered = when (selectedTab) {
        1    -> watchlist.filter { it.mediaType == "movie" }
        2    -> watchlist.filter { it.mediaType == "tv" }
        else -> watchlist
    }

    Box(modifier = Modifier.fillMaxSize().background(Background)) {
        when {
            loading -> CircularProgressIndicator(
                color = Primary,
                modifier = Modifier.align(Alignment.Center),
            )
            error != null -> Text(
                text = "Error: $error",
                color = Color(0xFFCF6679),
                modifier = Modifier.align(Alignment.Center),
            )
            watchlist.isEmpty() -> Column(
                modifier = Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("Your watchlist is empty", color = Color.White, fontSize = 18.sp)
                Spacer(Modifier.height(16.dp))
                Text(
                    "Browse content to add items",
                    color = Color.White.copy(alpha = 0.5f),
                    fontSize = 14.sp,
                )
            }
            else -> Column(modifier = Modifier.fillMaxSize()) {
                // ── Header ────────────────────────────────────────────────
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
                            onMoveLeft = {
                                if (index == 0) onReturnToSidebar()
                                else tabFocusRequesters[index - 1].requestFocus()
                            },
                            onMoveRight = {
                                if (index < TABS.lastIndex) tabFocusRequesters[index + 1].requestFocus()
                            },
                        )
                    }
                }

                Spacer(Modifier.height(24.dp))

                // ── Content ───────────────────────────────────────────────
                if (filtered.isEmpty()) {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("No items in this category", color = Color.White.copy(alpha = 0.6f))
                    }
                } else {
                    var focusedIndex by remember { mutableIntStateOf(-1) }

                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 48.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier
                            .fillMaxSize()
                            .onKeyEvent { event ->
                                if (event.type == KeyEventType.KeyDown &&
                                    event.key == Key.DirectionLeft &&
                                    focusedIndex <= 0) {
                                    onReturnToSidebar(); true
                                } else false
                            },
                    ) {
                        items(filtered) { item ->
                            val idx = filtered.indexOf(item)
                            ContentCard(
                                posterUrl = item.posterUrl,
                                title = item.title,
                                rating = item.voteAverage.takeIf { it > 0 },
                                isFocused = focusedIndex == idx,
                                onFocusChanged = { focused ->
                                    if (focused) focusedIndex = idx
                                    else if (focusedIndex == idx) focusedIndex = -1
                                },
                                onClick = {
                                    val route = if (item.mediaType == "tv")
                                        Screen.Series.createRoute(item.id.toString())
                                    else
                                        Screen.Details.createRoute(item.id.toString())
                                    navController.navigate(route)
                                },
                                modifier = Modifier.height(200.dp),
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
    onMoveLeft: () -> Unit,
    onMoveRight: () -> Unit,
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
            .focusable()
            .onFocusChanged { state -> isFocused = state.hasFocus }
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionLeft  -> { onMoveLeft(); true }
                    Key.DirectionRight -> { onMoveRight(); true }
                    Key.Enter, Key.DirectionCenter -> { onSelect(); true }
                    else -> false
                }
            }
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
