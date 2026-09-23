package com.maxstream.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.repository.MediaRepository
import com.maxstream.app.data.repository.MovieSection
import com.maxstream.app.data.repository.SeriesSection

/**
 * Movies screen with section tabs (Popular / Top rated / Upcoming) matching the
 * mobile/TV build — a tabbed browse grid instead of a flat "all movies" list.
 */
@Composable
fun MoviesScreen(
    repository: MediaRepository,
    initialSection: MovieSection = MovieSection.POPULAR,
    onOpen: (MediaItem) -> Unit,
) {
    SectionScreen(
        title = "Movies",
        subtitleProvider = { "Browse the movietmdb catalog" },
        tabs = MovieSection.entries.map { TabSpec(it.display, it.name) },
        initialTab = initialSection.name,
        load = { tabName -> repository.movies(MovieSection.valueOf(tabName)) },
        onOpen = onOpen,
    )
}

@Composable
fun SeriesScreen(
    repository: MediaRepository,
    initialSection: SeriesSection = SeriesSection.POPULAR,
    onOpen: (MediaItem) -> Unit,
) {
    SectionScreen(
        title = "Series",
        subtitleProvider = { "Browse the series catalog" },
        tabs = SeriesSection.entries.map { TabSpec(it.display, it.name) },
        initialTab = initialSection.name,
        load = { tabName -> repository.series(SeriesSection.valueOf(tabName)) },
        onOpen = onOpen,
    )
}

/** Watchlist backed by Firebase cloud sync (signed out: explains + empty). */
@Composable
fun WatchlistScreen(
    repository: MediaRepository,
    isSignedIn: Boolean,
    onOpen: (MediaItem) -> Unit,
) {
    val items by produceState<List<MediaItem>>(emptyList(), repository, isSignedIn) {
        value = repository.watchlist()
    }

    Column(Modifier.fillMaxSize().padding(20.dp)) {
        Text(
            "Watchlist",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            if (isSignedIn) "Synced to your account" else "Sign in to sync your watchlist across devices",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(16.dp))

        if (items.isEmpty()) {
            Box(
                Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.widthIn(max = 380.dp)) {
                    Icon(
                        Icons.Default.Bookmark,
                        null,
                        tint = MaterialTheme.colorScheme.outline,
                        modifier = Modifier.padding(bottom = 12.dp),
                    )
                    Text(
                        if (isSignedIn) "Nothing on your watchlist yet."
                        else "Sign in with your email, then add titles from any details page.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 14.sp,
                    )
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "Titles you save here are available on the phone and TV app too.",
                        color = MaterialTheme.colorScheme.outline,
                        fontSize = 12.sp,
                    )
                }
            }
        } else {
            MediaBrowserGrid(items, onOpen = onOpen)
        }
    }
}

private data class TabSpec(val display: String, val key: String)

@Composable
private fun SectionScreen(
    title: String,
    subtitleProvider: (String) -> String,
    tabs: List<TabSpec>,
    initialTab: String,
    load: suspend (tabName: String) -> List<MediaItem>,
    onOpen: (MediaItem) -> Unit,
) {
    var selectedTab by remember { mutableIntStateOf(tabs.indexOfFirst { it.key == initialTab }.coerceAtLeast(0)) }

    val items by produceState<List<MediaItem>>(emptyList(), selectedTab, tabs) {
        value = load(tabs.getOrNull(selectedTab)?.key ?: tabs.first().key)
    }

    Column(Modifier.fillMaxSize().padding(20.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            subtitleProvider(tabs.getOrNull(selectedTab)?.display ?: ""),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(Modifier.height(14.dp))

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.horizontalScroll(rememberScrollState()),
        ) {
            tabs.forEachIndexed { index, tab ->
                val selectedItem = index == selectedTab
                Box(
                    Modifier
                        .background(
                            if (selectedItem) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.surfaceVariant,
                            RoundedCornerShape(20.dp),
                        )
                        .padding(horizontal = 16.dp, vertical = 7.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        tab.display,
                        color = if (selectedItem) MaterialTheme.colorScheme.onPrimary
                                else MaterialTheme.colorScheme.onSurface,
                        fontWeight = if (selectedItem) FontWeight.SemiBold else FontWeight.Normal,
                        fontSize = 13.sp,
                        modifier = Modifier.clickableNoRipple { selectedTab = index },
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        MediaBrowserGrid(items, onOpen = onOpen)
    }
}

private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier =
    this.then(
        Modifier.clickable(indication = null, interactionSource = androidx.compose.foundation.interaction.MutableInteractionSource()) { onClick() },
    )