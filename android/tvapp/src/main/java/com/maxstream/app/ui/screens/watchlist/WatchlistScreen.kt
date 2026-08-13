package com.maxstream.app.ui.screens.watchlist

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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.navigation.NavController
import com.maxstream.app.R
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background

@Composable
fun WatchlistScreen(navController: NavController, onReturnToSidebar: () -> Unit = {}) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var watchlist by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var selectedTab by remember { mutableStateOf(0) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    val tabs = listOf("All", "Movies", "TV Shows")

    LaunchedEffect(Unit) {
        try {
            watchlist = com.maxstream.app.data.local.WatchlistRepository.getAll(context)
        } catch (e: Exception) {
            error = e.message
        } finally {
            loading = false
        }
    }

    val filtered = when (selectedTab) {
        1 -> watchlist.filter { it.mediaType == "movie" }
        2 -> watchlist.filter { it.mediaType == "tv" }
        else -> watchlist
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
        } else if (watchlist.isEmpty()) {
            Column(
                modifier = Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(text = "Your watchlist is empty", color = Color.White)
                Spacer(modifier = Modifier.height(16.dp))
                TextButton(onClick = { navController.navigate(Screen.Home.route) }) {
                    Text("Browse content")
                }
            }
        } else {
            Column(modifier = Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 48.dp, horizontal = 48.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    tabs.forEachIndexed { index, tab ->
                        val isFocused = index == selectedTab
                        val focusRequester = remember { FocusRequester() }
                        TextButton(
                            onClick = { selectedTab = index },
                            modifier = Modifier
                                .focusRequester(focusRequester)
                                .onFocusChanged { focusState ->
                                    if (focusState.hasFocus) {
                                        selectedTab = index
                                    }
                                }
                        ) {
                            Text(
                                text = tab,
                                color = if (isFocused) Color.Black else Color.White,
                                fontSize = 16.sp,
                                fontWeight = if (isFocused) FontWeight.Bold else FontWeight.Normal
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                if (filtered.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(text = "No items in this tab", color = Color.White)
                    }
                } else {
                    LazyRow(
                        state = rememberLazyListState(),
                        contentPadding = PaddingValues(horizontal = 48.dp, vertical = 24.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(filtered) { item ->
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
                                modifier = Modifier
                                    .focusRequester(remember { FocusRequester() })
                                    .height(180.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}
