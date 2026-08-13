package com.maxstream.app.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun TvContentFocusCard(
    child: @Composable () -> Unit,
    isFocused: Boolean,
    onTap: () -> Unit,
    animationDuration: Long = 300,
    scale: Float = 1.1f,
    showShadow: Boolean = true,
    shadowColor: Color = Color.White.copy(alpha = 0.4f),
    modifier: Modifier = Modifier,
) {
    val animatedScale by animateFloatAsState(
        targetValue = if (isFocused) scale else 1f,
        animationSpec = tween(durationMillis = animationDuration.toInt(), easing = FastOutSlowInEasing)
    )
    val animatedElevation by animateFloatAsState(
        targetValue = if (isFocused && showShadow) 20f else 0f,
        animationSpec = tween(durationMillis = animationDuration.toInt(), easing = FastOutSlowInEasing)
    )

    Box(
        modifier = modifier
            .graphicsLayer {
                scaleX = animatedScale
                scaleY = animatedScale
                shadowElevation = animatedElevation
                shape = RoundedCornerShape(12.dp)
                clip = true
            }
            .clickable(onClick = onTap)
    ) {
        child()
    }
}

@Composable
fun TvFocusButton(
    child: @Composable () -> Unit,
    isFocused: Boolean,
    onTap: (() -> Unit)? = null,
    borderRadius: Dp = 8.dp,
    borderWidth: Dp = 3.dp,
    padding: androidx.compose.foundation.layout.PaddingValues = androidx.compose.foundation.layout.PaddingValues(),
    enabled: Boolean = true,
    enabledBorderColor: Color = Color.Transparent,
    disabledBorderColor: Color = Color.Gray.copy(alpha = 0.5f),
    focusedBorderColor: Color = Color.White,
    pressedBgColor: Color = Color.White.copy(alpha = 0.2f),
    modifier: Modifier = Modifier,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val focusProgress by animateFloatAsState(
        targetValue = if (isFocused) 1f else 0f,
        animationSpec = tween(durationMillis = 250, easing = FastOutSlowInEasing)
    )

    val borderColor = if (!enabled) {
        disabledBorderColor
    } else {
        lerp(enabledBorderColor, focusedBorderColor, focusProgress)
    }

    val bgAlpha = if (isPressed) 0.2f else (0.05f * focusProgress)

    Box(
        modifier = modifier
            .border(width = borderWidth, color = borderColor, shape = RoundedCornerShape(borderRadius))
            .background(
                color = if (isPressed) pressedBgColor else Color.White.copy(alpha = bgAlpha),
                shape = RoundedCornerShape(borderRadius)
            )
            .then(
                if (isFocused) {
                    Modifier.graphicsLayer {
                        shadowElevation = 10 * focusProgress
                        shape = RoundedCornerShape(borderRadius)
                        clip = true
                    }
                } else Modifier
            )
            .padding(padding)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                onClick = { onTap?.invoke() }
            )
    ) {
        Box(
            modifier = Modifier
                .alpha(if (enabled) 1f else 0.6f)
                .padding(padding)
        ) {
            child()
        }
    }
}

@Composable
fun TvMenuItem(
    child: @Composable () -> Unit,
    isFocused: Boolean,
    onTap: () -> Unit,
    useScale: Boolean = false,
    scale: Float = 1.05f,
    showGlow: Boolean = true,
    glowColor: Color = Color.White.copy(alpha = 0.4f),
    modifier: Modifier = Modifier,
) {
    val glowProgress by animateFloatAsState(
        targetValue = if (isFocused) 1f else 0f,
        animationSpec = tween(durationMillis = 250, easing = FastOutSlowInEasing)
    )
    val scaleValue by animateFloatAsState(
        targetValue = if (isFocused) scale else 1f,
        animationSpec = tween(durationMillis = 250, easing = FastOutSlowInEasing)
    )

    Box(
        modifier = modifier
            .graphicsLayer {
                scaleX = if (useScale) scaleValue else 1f
                scaleY = if (useScale) scaleValue else 1f
            }
            .border(
                width = if (isFocused) 3.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(8.dp)
            )
            .then(
                if (isFocused && showGlow) {
                    Modifier.graphicsLayer {
                        shadowElevation = 8f * glowProgress
                        shape = RoundedCornerShape(8.dp)
                        clip = false
                    }
                } else Modifier
            )
            .clickable(onClick = onTap)
    ) {
        child()
    }
}
