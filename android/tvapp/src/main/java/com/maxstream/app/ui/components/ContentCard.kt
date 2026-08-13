package com.maxstream.app.ui.components

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusable
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.maxstream.app.ui.theme.OnSurface

private val CardWidth = 130.dp
private val CardHeight = 190.dp
private val CardCornerRadius = 10.dp

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
) {
    val scale = remember { Animatable(1f) }
    val targetScale = if (isFocused) 1.02f else 1f
    val cardHeightPx = with(LocalDensity.current) { CardHeight.toPx() }
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(isFocused) {
        scale.animateTo(
            targetValue = targetScale,
            animationSpec = tween(durationMillis = 180, easing = FastOutSlowInEasing)
        )
    }

    LaunchedEffect(isFocused) {
        onFocusChanged(isFocused)
    }

    Box(
        modifier = modifier
            .padding(horizontal = 7.dp)
            .scale(scale.value)
            .animateContentSize()
            .focusRequester(focusRequester)
            .focusable()
            .onFocusChanged { focusState ->
                onFocusChanged(focusState.hasFocus)
            }
            .clickable(onClick = onClick)
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(
                modifier = Modifier
                    .height(CardHeight)
                    .clip(RoundedCornerShape(CardCornerRadius))
                    .border(
                        width = if (isFocused) 2.dp else 0.dp,
                        color = if (isFocused) Color.White else Color.Transparent,
                        shape = RoundedCornerShape(CardCornerRadius)
                    )
            ) {
                AsyncImage(
                    model = posterUrl,
                    contentDescription = title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Transparent,
                                    Color.Transparent,
                                    Color.Black.copy(alpha = 0.55f)
                                ),
                                startY = 0f,
                                endY = cardHeightPx
                            )
                        )
                )

                if (progress != null) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .fillMaxWidth()
                            .height(4.dp)
                            .padding(horizontal = 7.dp)
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

                if (rating != null && rating > 0) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(top = 6.dp, end = 6.dp)
                    ) {
                        androidx.compose.material3.Text(
                            text = String.format("%.1f", rating),
                            color = Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier
                                .background(
                                    Color.Black.copy(alpha = 0.6f),
                                    RoundedCornerShape(4.dp)
                                )
                                .padding(horizontal = 4.dp, vertical = 2.dp)
                        )
                    }
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 6.dp)
                    .height(42.dp),
                verticalArrangement = Arrangement.Center
            ) {
                androidx.compose.material3.Text(
                    text = title,
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}
