package com.maxstream.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.repository.MediaRepository

/** Desktop detail pane: poster on the left, information panel on the right —
 *  a split layout rather than the TV's full-bleed cinematic backdrop. */
@Composable
fun DetailsScreen(
    itemId: String,
    repository: MediaRepository,
    onBack: () -> Unit,
) {
    val item by produceState<MediaItem?>(null, itemId, repository) {
        value = repository.byId(itemId)
    }

    Column(Modifier.fillMaxSize().padding(20.dp)) {
        IconButton(onClick = onBack) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
                tint = MaterialTheme.colorScheme.onSurface,
            )
        }

        val current = item
        if (current == null) {
            Spacer(Modifier.height(20.dp))
            Text(
                "Title not found.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            return@Column
        }

        Row(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(top = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            Box(
                Modifier
                    .width(280.dp)
                    .aspectRatio(0.7f)
                    .background(posterBrush(current), RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    current.title.first().toString(),
                    fontSize = 64.sp,
                    fontWeight = FontWeight.Bold,
                    color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.85f),
                )
            }

            Column(Modifier.weight(1f)) {
                Text(
                    current.title,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(Modifier.height(6.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Star, null, tint = androidx.compose.ui.graphics.Color(0xFFF5C518), modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "%.1f".format(current.rating) + "  •  " +
                            (listOf(current.typeLabel, current.displayYear) + current.genres)
                                .filter { it.isNotBlank() }
                                .joinToString("  •  "),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 14.sp,
                    )
                }

                Spacer(Modifier.height(18.dp))
                Text(
                    current.overview,
                    color = MaterialTheme.colorScheme.onSurface,
                    lineHeight = 22.sp,
                    fontSize = 15.sp,
                    maxLines = 8,
                    overflow = TextOverflow.Ellipsis,
                )

                Spacer(Modifier.height(24.dp))
                TextButton(
                    onClick = { /* play — wires to the playback engine in the next iteration */ },
                    modifier = Modifier.background(MaterialTheme.colorScheme.primary, RoundedCornerShape(8.dp)),
                ) {
                    Icon(Icons.Default.PlayArrow, null, tint = MaterialTheme.colorScheme.onPrimary)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        if (current.mediaType == "tv") "Watch now" else "Play",
                        color = MaterialTheme.colorScheme.onPrimary,
                        fontWeight = FontWeight.SemiBold,
                    )
                }

                if (current.genres.isNotEmpty()) {
                    Spacer(Modifier.height(26.dp))
                    Text(
                        "Genres",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        current.genres.forEach { genre ->
                            Box(
                                Modifier.background(
                                    MaterialTheme.colorScheme.surfaceVariant,
                                    RoundedCornerShape(20.dp),
                                ).padding(horizontal = 14.dp, vertical = 6.dp),
                            ) {
                                Text(
                                    genre,
                                    fontSize = 13.sp,
                                    color = MaterialTheme.colorScheme.onSurface,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}