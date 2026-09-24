package com.maxstream.app.ui.components

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.maxstream.app.data.model.HomeSection
import com.maxstream.app.data.model.MediaItem

val PosterPalette = listOf(
    Brush.linearGradient(listOf(Color(0xFF0E5A8A), Color(0xFF082D47))),
    Brush.linearGradient(listOf(Color(0xFF7A0E3E), Color(0xFF35041B))),
    Brush.linearGradient(listOf(Color(0xFF0E6E63), Color(0xFF042E29))),
    Brush.linearGradient(listOf(Color(0xFF5B3FA8), Color(0xFF241452))),
    Brush.linearGradient(listOf(Color(0xFFA8520E), Color(0xFF462103))),
)

internal fun posterBrush(item: MediaItem): Brush =
    PosterPalette[item.id.hashCode().mod(PosterPalette.size)]

/** Poster card for grids and rails. Fades in the TMDB poster over a gradient. */
@Composable
fun PosterCard(
    item: MediaItem,
    width: Dp,
    showProgress: Boolean = false,
    landscape: Boolean = false,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val hovered by interaction.collectIsHoveredAsState()
    val shape = RoundedCornerShape(8.dp)
    val showRating = item.rating > 0.0

    Column(
        Modifier
            .width(width)
            .scale(if (hovered) 1.04f else 1f)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(if (landscape) 16f / 9f else 0.7f)
                .clip(shape)
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, shape)
                .background(posterBrush(item)),
            contentAlignment = Alignment.Center,
        ) {
            val imageUrl = if (landscape) item.backdropUrl ?: item.posterUrl else item.posterUrl
            imageUrl?.let { url ->
                AsyncImage(
                    model = url,
                    contentDescription = item.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } ?: Text(
                item.title.firstOrNull()?.toString().orEmpty(),
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White.copy(alpha = 0.85f),
            )
            if (showRating) {
                Box(
                    Modifier.align(Alignment.TopStart).padding(8.dp)
                        .background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(6.dp))
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
            }
            if (item.progress > 0f) {
                Box(
                    Modifier.align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .height(3.dp)
                        .background(Color.Black.copy(alpha = 0.45f)),
                ) {
                    Box(
                        Modifier.fillMaxWidth(item.progress.coerceIn(0f, 1f)).height(3.dp)
                            .background(MaterialTheme.colorScheme.primary),
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
                        modifier = Modifier.size(40.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(
            item.title,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.Medium,
            fontSize = 13.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.height(2.dp))
        Text(
            buildList {
                add(item.typeLabel)
                add(item.displayYear)
                addAll(item.genres.take(2))
            }.filter { it.isNotBlank() }.joinToString("  •  "),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 11.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (showProgress && !landscape) {
            Spacer(Modifier.height(6.dp))
            Box(
                Modifier.width(width).height(3.dp)
                    .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(2.dp)),
            ) {
                Box(
                    Modifier.fillMaxWidth(item.progress.coerceIn(0f, 1f)).height(3.dp)
                        .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(2.dp)),
                )
            }
        }
    }
}

/** Horizontal rail: optional "See all" header + scrolling posters. */
@Composable
fun SectionRail(
    title: String,
    items: List<MediaItem>,
    onOpen: (MediaItem) -> Unit,
    onSeeAll: (() -> Unit)? = null,
    showProgress: Boolean = false,
    itemKeys: List<String>? = null,
) {
    if (items.isEmpty()) return
    Column {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 16.dp),
        ) {
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            if (onSeeAll != null) {
                TextButton(onClick = onSeeAll) {
                    Text("See all", color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        LazyRow(
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(
                items = items.indices.toList(),
                key = { i ->
                    itemKeys?.getOrNull(i)
                        ?: "${items[i].mediaType}:${items[i].id}"
                },
            ) { i ->
                val item = items[i]
                PosterCard(
                    item = item,
                    width = if (showProgress) 220.dp else 132.dp,
                    showProgress = false,
                    landscape = showProgress,
                    onClick = { onOpen(item) },
                )
            }
        }
        Spacer(Modifier.height(10.dp))
    }
}

/** Billboard-style hero using the item's backdrop as a wash. */
@Composable
fun HeroCard(
    item: MediaItem,
    onPlay: () -> Unit,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val interaction = remember { MutableInteractionSource() }
    val hovered by interaction.collectIsHoveredAsState()
    val shape = RoundedCornerShape(16.dp)

    Box(
        Modifier
            .fillMaxWidth()
            .height(260.dp)
            .padding(horizontal = 20.dp)
            .scale(if (hovered) 1.01f else 1f),
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .clip(shape)
                .clickable(interactionSource = interaction, indication = null, onClick = onOpen)
                .background(posterBrush(item)),
        ) {
            item.backdropUrl?.let { url ->
                AsyncImage(
                    model = url,
                    contentDescription = item.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.matchParentSize(),
                )
            }
            Box(
                Modifier.matchParentSize()
                    .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.55f)))),
            )
            Column(
                Modifier.align(Alignment.BottomStart).padding(22.dp).fillMaxWidth(),
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
                    color = Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    if (item.rating > 0.0) {
                        "${item.typeLabel}  •  %.1f  •  %s".format(item.rating, item.displayYear)
                    } else {
                        listOf(item.typeLabel, item.displayYear).filter { it.isNotBlank() }.joinToString("  •  ")
                    },
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 13.sp,
                )
                Spacer(Modifier.height(14.dp))
                Row {
                    TextButton(
                        onClick = onPlay,
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

