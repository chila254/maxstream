package com.maxstream.app.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.repository.MediaRepository

private val PosterPalette = listOf(
    Brush.linearGradient(listOf(Color(0xFF0E5A8A), Color(0xFF082D47))),
    Brush.linearGradient(listOf(Color(0xFF7A0E3E), Color(0xFF35041B))),
    Brush.linearGradient(listOf(Color(0xFF0E6E63), Color(0xFF042E29))),
    Brush.linearGradient(listOf(Color(0xFF5B3FA8), Color(0xFF241452))),
    Brush.linearGradient(listOf(Color(0xFFA8520E), Color(0xFF462103))),
)

internal fun posterBrush(item: MediaItem): Brush =
    PosterPalette[item.id.hashCode().mod(PosterPalette.size)]

@Composable
fun HomeScreen(
    repository: MediaRepository,
    query: String,
    onOpen: (MediaItem) -> Unit,
) {
    val all by produceState<List<MediaItem>>(emptyList(), repository) {
        value = repository.home()
    }
    val matches by produceState<List<MediaItem>>(emptyList(), all, query) {
        value = if (query.isBlank()) all else repository.search(query)
    }
    val continueWatching by produceState<List<MediaItem>>(emptyList(), all) {
        value = repository.continueWatching()
    }

    if (query.isNotBlank()) {
        Column(Modifier.fillMaxSize().padding(20.dp)) {
            Text(
                if (matches.isEmpty()) "No results for \"$query\""
                else "Results for \"$query\" (${matches.size})",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.height(12.dp))
            MediaGrid(matches, onOpen = onOpen)
        }
        return
    }

    Column(Modifier.fillMaxSize()) {
        LazyRow(
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            item {
                val hero = all.firstOrNull()
                if (hero != null) HeroCard(hero, onclick = { onOpen(hero) })
            }
        }

        if (continueWatching.isNotEmpty()) {
            SectionHeader("Continue watching")
            LazyRow(
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                items(continueWatching, key = { it.id }) { item ->
                    MediaCard(item, width = 220.dp, showProgress = true, onClick = { onOpen(item) })
                }
            }
            Spacer(Modifier.height(22.dp))
        }

        val trending = if (all.size > 4) all else all
        SectionHeader("Trending now")
        MediaGrid(trending, onOpen = onOpen)
    }
}

@Composable
fun CatalogScreen(
    mediaType: String,
    title: String,
    repository: MediaRepository,
    onOpen: (MediaItem) -> Unit,
) {
    val all by produceState<List<MediaItem>>(emptyList(), repository) {
        value = repository.home()
    }
    val filtered = remember(all) {
        when (mediaType) {
            "movie" -> all.filter { it.mediaType == "movie" }
            "tv" -> all.filter { it.mediaType == "tv" }
            else -> all
        }
    }
    Column(Modifier.fillMaxSize().padding(20.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            "${filtered.size} titles",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(16.dp))
        MediaGrid(filtered, onOpen = onOpen)
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.padding(start = 20.dp, end = 20.dp, bottom = 10.dp),
    )
}

@Composable
private fun MediaGrid(
    items: List<MediaItem>,
    onOpen: (MediaItem) -> Unit,
) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(190.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = 20.dp, end = 20.dp, top = 4.dp, bottom = 24.dp,
        ),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        items(items, key = { it.id }) { item ->
            MediaCard(item, width = 190.dp, onClick = { onOpen(item) })
        }
    }
}

@Composable
private fun HeroCard(item: MediaItem, onclick: () -> Unit) {
    val width = 600.dp
    val height = (width * 0.5f)
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.primaryContainer,
        tonalElevation = 2.dp,
        modifier = Modifier.width(width).height(height + 20.dp),
    ) {
        Box(Modifier.fillMaxSize().clickable { onclick() }) {
            Box(
                Modifier.matchParentSize().background(
                    Brush.horizontalGradient(
                        listOf(
                            MaterialTheme.colorScheme.primaryContainer,
                            MaterialTheme.colorScheme.surfaceVariant,
                        ),
                    ),
                ),
            )
            Column(
                Modifier.align(Alignment.BottomStart).padding(20.dp).fillMaxWidth(),
            ) {
                Text(
                    "FEATURED",
                    fontSize = 11.sp,
                    letterSpacing = 2.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    item.title,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    "${item.typeLabel}  •  ${item.rating}★",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 13.sp,
                )
                Spacer(Modifier.height(14.dp))
                Row {
                    TextButton(
                        onClick = onclick,
                        modifier = Modifier.background(
                            MaterialTheme.colorScheme.primary,
                            RoundedCornerShape(8.dp),
                        ),
                    ) {
                        Icon(Icons.Default.PlayArrow, null, tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Play", color = MaterialTheme.colorScheme.onPrimary, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

@Composable
fun MediaCard(
    item: MediaItem,
    width: Dp,
    showProgress: Boolean = false,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val hovered by interaction.collectIsHoveredAsState()
    val shape = RoundedCornerShape(10.dp)

    Column(
        Modifier
            .width(width)
            .scale(if (hovered) 1.03f else 1f)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(0.7f)
                .clip(shape)
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, shape)
                .background(posterBrush(item)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                item.title.first().toString(),
                fontSize = 42.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White.copy(alpha = 0.85f),
            )
            Box(
                Modifier.align(Alignment.TopStart).padding(8.dp)
                    .background(Color.Black.copy(alpha = 0.35f), RoundedCornerShape(6.dp))
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Star, null, tint = Color(0xFFF5C518), modifier = Modifier.size(12.dp))
                    Spacer(Modifier.width(3.dp))
                    Text(
                        "%.1f".format(item.rating),
                        color = Color.White,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            if (hovered) {
                Box(
                    Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.25f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Default.PlayArrow,
                        contentDescription = "Play ${item.title}",
                        tint = Color.White,
                        modifier = Modifier.size(44.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            item.title,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.Medium,
            fontSize = 14.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.height(2.dp))
        Text(
            buildList {
                add(item.typeLabel)
                add(item.displayYear)
                addAll(item.genres.take(2))
            }.joinToString("  •  "),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 12.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (showProgress) {
            Spacer(Modifier.height(8.dp))
            Box(
                Modifier.width(width).height(4.dp)
                    .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(2.dp)),
            ) {
                Box(
                    Modifier.fillMaxWidth(item.progress.coerceIn(0f, 1f)).height(4.dp)
                        .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(2.dp)),
                )
            }
        }
    }
}