package com.maxstream.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Shared empty / error state used by Watchlist, search, Home, and catalog
 * screens so every "nothing here" surface looks the same.
 */
@Composable
fun EmptyState(
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.widthIn(max = 420.dp).padding(24.dp),
        ) {
            if (icon != null) {
                Icon(
                    icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.outline,
                    modifier = Modifier.size(48.dp),
                )
                Spacer(Modifier.height(14.dp))
            }
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                message,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                lineHeight = 18.sp,
            )
        }
    }
}

/** Pulsing placeholder block for Home / grid skeletons. */
@Composable
fun SkeletonBox(
    width: androidx.compose.ui.unit.Dp,
    height: androidx.compose.ui.unit.Dp,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier
            .width(width)
            .height(height)
            .background(MaterialTheme.colorScheme.surfaceVariant, MaterialTheme.shapes.small),
    )
}

/** Full-width skeleton rail used while Home sections load. */
@Composable
fun SkeletonRail(modifier: Modifier = Modifier) {
    Column(modifier) {
        SkeletonBox(width = 160.dp, height = 18.dp)
        Spacer(Modifier.height(12.dp))
        androidx.compose.foundation.layout.Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            repeat(6) {
                SkeletonBox(width = 132.dp, height = 196.dp)
            }
        }
    }
}
