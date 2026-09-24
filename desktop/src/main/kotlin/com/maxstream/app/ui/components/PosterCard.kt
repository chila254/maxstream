package com.maxstream.app.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.maxstream.app.data.model.HomeSection
import com.maxstream.app.data.model.MediaItem
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

val PosterPalette = listOf(
    Brush.linearGradient(listOf(Color(0xFF0E5A8A), Color(0xFF082D47))),
    Brush.linearGradient(listOf(Color(0xFF7A0E3E), Color(0xFF35041B))),
    Brush.linearGradient(listOf(Color(0xFF0E6E63), Color(0xFF042E29))),
    Brush.linearGradient(listOf(Color(0xFF5B3FA8), Color(0xFF241452))),
    Brush.linearGradient(listOf(Color(0xFFA8520E), Color(0xFF462103))),
)

internal fun posterBrush(item: MediaItem): Brush =
    PosterPalette[item.id.hashCode().mod(PosterPalette.size)]

/** Poster card for grids and rails. Animated hover lift + type/quality badge. */
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
    val scale by animateFloatAsState(
        targetValue = if (hovered) 1.06f else 1f,
        animationSpec = tween(durationMillis = 180),
        label = "posterScale",
    )
    val elevationDp by animateFloatAsState(
        targetValue = if (hovered) 10f else 0f,
        animationSpec = tween(durationMillis = 180),
        label = "posterElevation",
    )

    Column(
        Modifier
            .width(width)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(if (landscape) 16f / 9f else 0.7f)
                .shadow(elevation = elevationDp.dp, shape = shape, clip = false)
                .clip(shape)
                .border(
                    width = if (hovered) 2.dp else 1.dp,
                    color = if (hovered) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.outlineVariant,
                    shape = shape,
                )
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
            // Type badge (MOVIE / SERIES) — top-right pill.
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp)
                    .background(
                        if (item.mediaType == "tv") Color(0xFF6366F1).copy(alpha = 0.92f)
                        else Color.Black.copy(alpha = 0.65f),
                        RoundedCornerShape(4.dp),
                    )
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            ) {
                Text(
                    if (item.mediaType == "tv") "SERIES" else "MOVIE",
                    color = Color.White,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.6.sp,
                )
            }
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
                    Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.3f)),
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

/**
 * Horizontal rail: "See all" header, edge fade, and hover arrow paging —
 * the same interaction pattern as the mobile/TV rails.
 */
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
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
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    var hovered by remember { mutableStateOf(false) }

    Column {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 8.dp),
        ) {
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            if (hovered) {
                IconButton(
                    onClick = {
                        scope.launch { listState.animateScrollBy(-360f) }
                    },
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                        contentDescription = "Scroll left",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                IconButton(
                    onClick = {
                        scope.launch { listState.animateScrollBy(360f) }
                    },
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = "Scroll right",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (onSeeAll != null) {
                TextButton(onClick = onSeeAll) {
                    Text("See all", color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        Box(
            Modifier
                .fillMaxWidth()
                .onPointerEvent(PointerEventType.Enter) { hovered = true }
                .onPointerEvent(PointerEventType.Exit) { hovered = false },
        ) {
            LazyRow(
                state = listState,
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
    val scale by animateFloatAsState(
        targetValue = if (hovered) 1.015f else 1f,
        animationSpec = tween(200),
        label = "heroScale",
    )

    Box(
        Modifier
            .fillMaxWidth()
            .height(260.dp)
            .padding(horizontal = 20.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            },
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .shadow(if (hovered) 14.dp else 4.dp, shape, clip = false)
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


