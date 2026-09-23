package com.maxstream.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.repository.MediaRepository
import com.maxstream.app.data.repository.MovieSection
import com.maxstream.app.data.repository.SeriesSection
import com.maxstream.app.ui.components.HeroCard
import com.maxstream.app.ui.components.PosterCard
import com.maxstream.app.ui.components.SectionRail

/**
 * Desktop home: hero billboard up top, then named rails (trending, popular,
 * top rated) exactly like the mobile/TV home — and search results in place of
 * the rails while a query is typed.
 */
@Composable
fun HomeScreen(
    repository: MediaRepository,
    query: String,
    onOpen: (MediaItem) -> Unit,
    onPlay: (MediaItem) -> Unit,
    onSeeAllMovies: (MovieSection) -> Unit,
    onSeeAllSeries: (SeriesSection) -> Unit,
) {
    val sections by produceState<List<com.maxstream.app.data.model.HomeSection>>(emptyList(), repository) {
        value = repository.homeSections()
    }
    val continueWatching by produceState<List<com.maxstream.app.data.model.ContinueWatch>>(emptyList(), repository) {
        value = repository.continueWatching()
    }
    val matches by produceState<List<MediaItem>>(emptyList(), query, sections) {
        value = if (query.isBlank()) emptyList() else repository.search(query)
    }

    if (query.isNotBlank()) {
        Column(Modifier.fillMaxSize().padding(20.dp)) {
            Text(
                if (matches.isEmpty()) "No results for \"$query\""
                else "Results for \"$query\" (${matches.size})",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(bottom = 12.dp),
            )
            MediaBrowserGrid(matches, onOpen = onOpen)
        }
        return
    }

    val hero = sections.firstOrNull()?.items?.firstOrNull()

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        if (hero != null) {
            Spacer(Modifier.height(14.dp))
            HeroCard(
                item = hero,
                onPlay = { onPlay(hero) },
                onOpen = { onOpen(hero) },
            )
            Spacer(Modifier.height(18.dp))
        }

        if (continueWatching.isNotEmpty()) {
            SectionRail(
                title = "Continue watching",
                items = continueWatching.map { SectionedContinue(it) },
                onOpen = { onOpen(it) },
                showProgress = true,
            )
        }

        sections.forEach { section ->
            val seeAllMovies = when (section.title) {
                "Trending movies" -> MovieSection.POPULAR
                "Popular movies" -> MovieSection.POPULAR
                "Top rated" -> MovieSection.TOP_RATED
                else -> null
            }
            val seeAllSeries = when (section.title) {
                "Trending series" -> SeriesSection.POPULAR
                "Popular series" -> SeriesSection.POPULAR
                else -> null
            }
            SectionRail(
                title = section.title,
                items = section.items,
                onOpen = onOpen,
                onSeeAll = when {
                    seeAllMovies != null -> { { onSeeAllMovies(seeAllMovies) } }
                    seeAllSeries != null -> { { onSeeAllSeries(seeAllSeries) } }
                    else -> null
                },
            )
        }
        Spacer(Modifier.height(16.dp))
    }
}

private fun SectionedContinue(c: com.maxstream.app.data.model.ContinueWatch): MediaItem =
    c.item.copy(progress = c.progress)

/** Shared poster grid used by search + catalog screens. */
@Composable
fun MediaBrowserGrid(
    items: List<MediaItem>,
    onOpen: (MediaItem) -> Unit,
) {
    if (items.isEmpty()) return
    LazyVerticalGrid(
        columns = GridCells.Adaptive(190.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        items(items, key = { it.id }) { item ->
            PosterCard(item, width = 190.dp, onClick = { onOpen(item) })
        }
    }
}

/** Shared horizontal poster row for home/rail content. */
@Composable
fun MediaRow(
    items: List<MediaItem>,
    onOpen: (MediaItem) -> Unit,
) {
    LazyRow(
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        items(items, key = { it.id }) { item ->
            PosterCard(item, width = 160.dp, onClick = { onOpen(item) })
        }
    }
}