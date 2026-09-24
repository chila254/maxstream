package com.maxstream.app.ui.components

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.maxstream.app.data.model.MediaItem
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

/**
 * Full-bleed rotating hero (port of mobile lib/widgets/hero_banner.dart):
 * Crossfade carousel over trending backdrops, left+bottom gradients, title,
 * metadata row, overview, Play / More info actions, and page dots. Auto-advances
 * every 6s like the phone app.
 */
@Composable
fun RotatingHero(
    items: List<MediaItem>,
    onPlay: (MediaItem) -> Unit,
    onOpen: (MediaItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    if (items.isEmpty()) return
    var index by remember { mutableIntStateOf(0) }
    val current = items[index.coerceIn(0, items.lastIndex)]

    LaunchedEffect(items.size) {
        if (items.size < 2) return@LaunchedEffect
        while (isActive) {
            delay(6_000L)
            index = (index + 1) % items.size
        }
    }

    val interaction = remember { MutableInteractionSource() }
    val hovered by interaction.collectIsHoveredAsState()

    Box(
        modifier
            .fillMaxWidth()
            .height(340.dp),
    ) {
        Crossfade(
            targetState = current,
            animationSpec = tween(700),
            label = "heroCrossfade",
            modifier = Modifier.fillMaxSize(),
        ) { slide ->
            Box(Modifier.fillMaxSize().background(posterBrush(slide))) {
                slide.backdropUrl?.let { url ->
                    AsyncImage(
                        model = url,
                        contentDescription = slide.title,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
        }
        // Left wash for text legibility (mobile hero horizontal gradient).
        Box(
            Modifier.fillMaxSize().background(
                Brush.horizontalGradient(
                    listOf(
                        Color.Black.copy(alpha = 0.72f),
                        Color.Black.copy(alpha = 0.15f),
                        Color.Transparent,
                    ),
                ),
            ),
        )
        // Bottom wash.
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    listOf(
                        Color.Transparent,
                        Color.Transparent,
                        Color.Black.copy(alpha = 0.85f),
                    ),
                ),
            ),
        )

        Column(
            Modifier
                .align(Alignment.BottomStart)
                .padding(start = 24.dp, end = 24.dp, bottom = 42.dp)
                .fillMaxWidth(0.62f),
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
                current.title,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (current.rating > 0.0) {
                    Icon(Icons.Default.Star, null, tint = Color(0xFFF5C518), modifier = Modifier.size(15.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(
                        "%.1f".format(current.rating),
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.width(12.dp))
                }
                if (current.displayYear.isNotBlank()) {
                    Text(current.displayYear, color = Color.White.copy(alpha = 0.8f), fontSize = 13.sp)
                    Spacer(Modifier.width(12.dp))
                }
                Box(
                    Modifier
                        .background(
                            if (current.mediaType == "tv") MaterialTheme.colorScheme.primary
                            else Color(0xFF2563EB),
                            RoundedCornerShape(4.dp),
                        )
                        .padding(horizontal = 7.dp, vertical = 2.dp),
                ) {
                    Text(
                        if (current.mediaType == "tv") "TV" else "MOVIE",
                        color = Color.White,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
            if (current.overview.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(
                    current.overview,
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                val playInteraction = remember { MutableInteractionSource() }
                val playHovered by playInteraction.collectIsHoveredAsState()
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(
                            if (playHovered) MaterialTheme.colorScheme.primary.copy(alpha = 0.88f)
                            else MaterialTheme.colorScheme.primary,
                        )
                        .clickable(interactionSource = playInteraction, indication = null) { onPlay(current) }
                        .padding(horizontal = 18.dp, vertical = 10.dp),
                ) {
                    Icon(
                        Icons.Default.PlayArrow,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(20.dp),
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        if (current.mediaType == "tv") "Play S1:E1" else "Play",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                    )
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.Black.copy(alpha = 0.45f))
                        .clickable(interactionSource = interaction, indication = null) { onOpen(current) }
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                ) {
                    Icon(
                        Icons.Default.Info,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text("More info", color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                }
            }
        }

        // Page indicators (bottom-center, like mobile).
        Row(
            horizontalArrangement = Arrangement.Center,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 14.dp)
                .fillMaxWidth(),
        ) {
            items.forEachIndexed { i, _ ->
                val active = i == index
                Box(
                    Modifier
                        .padding(horizontal = 3.dp)
                        .width(if (active) 22.dp else 7.dp)
                        .height(7.dp)
                        .background(
                            if (active) MaterialTheme.colorScheme.primary
                            else Color.White.copy(alpha = 0.35f),
                            RoundedCornerShape(4.dp),
                        )
                        .clickable { index = i },
                )
            }
        }
    }
}
