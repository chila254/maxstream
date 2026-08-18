package com.maxstream.app.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage

// Uniform poster card size, matching the Dart TvContentCard (width 130 / height 190).
private val CardWidth = 130.dp
private val CardHeight = 190.dp
private val CardCornerRadius = 10.dp

/**
 * TV content card (poster + title + optional overlays).
 *
 * Fixes applied:
 * - Single focus state path: `onFocusChanged` is the canonical source of truth;
 *   the external [isFocused] param drives scale animation only.
 * - No double LaunchedEffect(isFocused) calling onFocusChanged — that was
 *   causing duplicate callbacks on every recomposition.
 * - focusable() + clickable() in the right order so D-pad Enter triggers onClick.
 */
@Composable
fun ContentCard(
    posterUrl: String,
    title: String,
    modifier: Modifier = Modifier,
    isFocused: Boolean = false,
    progress: Float? = null,
    rating: Double? = null,
    contentTypeLabel: String? = null,
    year: Int? = null,
    onClick: () -> Unit = {},
    onFocusChanged: (Boolean) -> Unit = {},
    onKeyEvent: (KeyEvent) -> Boolean = { false },
    focusRequester: FocusRequester? = null,
) {
    val cardHeightPx = with(LocalDensity.current) { CardHeight.toPx() }

    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.02f else 1f,
        animationSpec = tween(durationMillis = 180, easing = FastOutSlowInEasing),
        label = "cardScale",
    )

    Box(
        modifier = modifier
            .padding(horizontal = 7.dp)
            .scale(scale)
            // D-pad navigation: arrow keys handled here so parents can wire
            // cross-row / sidebar moves (mirrors Dart's card onKeyEvent).
            .onKeyEvent(onKeyEvent)
            // External programmatic focus (row navigator) must be registered
            // before the card is made focusable below.
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            // Focus must be registered BEFORE clickable so the D-pad Enter key
            // fires the click callback correctly.
            .onFocusChanged { state -> onFocusChanged(state.hasFocus) }
            .focusable()
            .clickable(onClick = onClick),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            // ── Poster ──────────────────────────────────────────────────────
            Box(
                modifier = Modifier
                    .width(CardWidth)
                    .height(CardHeight)
                    .clip(RoundedCornerShape(CardCornerRadius))
                    .border(
                        width = if (isFocused) 2.dp else 0.dp,
                        color = if (isFocused) Color.White else Color.Transparent,
                        shape = RoundedCornerShape(CardCornerRadius),
                    ),
            ) {
                AsyncImage(
                    model = posterUrl,
                    contentDescription = title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )

                // Bottom gradient scrim
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Transparent,
                                    Color.Transparent,
                                    Color.Black.copy(alpha = 0.55f),
                                ),
                                startY = 0f,
                                endY = cardHeightPx,
                            )
                        )
                )

                // Progress bar
                if (progress != null) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .fillMaxWidth()
                            .height(4.dp)
                            .padding(horizontal = 7.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .clip(RoundedCornerShape(2.dp))
                                .background(Color(0xFF333333))
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(progress.coerceIn(0f, 1f))
                                .fillMaxSize()
                                .clip(RoundedCornerShape(2.dp))
                                .background(Color(0xFFE50914))
                        )
                    }
                }

                // Rating badge
                if (rating != null && rating > 0) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(top = 6.dp, end = 6.dp),
                    ) {
                        Text(
                            text = String.format("%.1f", rating),
                            color = Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier
                                .background(Color.Black.copy(alpha = 0.6f), RoundedCornerShape(4.dp))
                                .padding(horizontal = 4.dp, vertical = 2.dp),
                        )
                    }
                }
            }

            // ── Title ────────────────────────────────────────────────────────
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 6.dp)
                    .height(42.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = title,
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}
