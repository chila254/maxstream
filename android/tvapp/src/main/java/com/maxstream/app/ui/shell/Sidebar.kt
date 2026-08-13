package com.maxstream.app.ui.shell

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandHorizontally
import androidx.compose.animation.shrinkHorizontally
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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.R
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.tv.TvFocusManager

data class SidebarSection(
    val screen: Screen,
    val labelRes: Int,
    val iconRes: Int,
)

@Composable
fun Sidebar(
    sections: List<SidebarSection>,
    selectedIndex: Int,
    onSectionSelected: (Int) -> Unit,
    onExpandedChanged: (Boolean) -> Unit,
    onReturnToContent: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var focusedIndex by remember { mutableStateOf(selectedIndex) }
    val isExpanded = remember { mutableStateOf(false) }

    LaunchedEffect(focusedIndex) {
        if (focusedIndex >= 0) {
            isExpanded.value = true
            TvFocusManager.onSidebarItemFocused()
            onExpandedChanged(true)
        }
    }

    LaunchedEffect(Unit) {
        snapshotFlow { focusedIndex }
            .collect { index ->
                if (index < 0) {
                    isExpanded.value = false
                    TvFocusManager.onSidebarItemUnfocused()
                    onExpandedChanged(false)
                }
            }
    }

    val targetWidth = if (isExpanded.value) 220.dp else 76.dp

    Box(
        modifier = modifier
            .width(targetWidth)
            .fillMaxHeight()
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color(0xFF1A1A1A), Color(0xFF111111))
                )
            )
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = 0.09f),
                shape = RoundedCornerShape(0.dp)
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(vertical = 28.dp, horizontal = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.Black),
                contentAlignment = Alignment.Center
            ) {
                androidx.compose.material3.Text(
                    text = "M",
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(28.dp))

            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                sections.forEachIndexed { index, section ->
                    val isSelected = index == selectedIndex
                    val isFocused = index == focusedIndex

                    SidebarPillItem(
                        iconRes = section.iconRes,
                        label = stringResource(id = section.labelRes),
                        isSelected = isSelected,
                        isFocused = isFocused,
                        expanded = isExpanded.value,
                        onClick = {
                            onSectionSelected(index)
                            onReturnToContent()
                        },
                        onFocusIn = { focusedIndex = index },
                        onFocusOut = {
                            if (focusedIndex == index) {
                                focusedIndex = -1
                            }
                        },
                        modifier = Modifier.animateContentSize()
                    )
                }
            }
        }
    }
}

@Composable
private fun SidebarPillItem(
    iconRes: Int,
    label: String,
    isSelected: Boolean,
    isFocused: Boolean,
    expanded: Boolean,
    onClick: () -> Unit,
    onFocusIn: () -> Unit,
    onFocusOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val itemScale = remember { Animatable(1f) }
    val targetScale = if (isFocused) 1.05f else 1f

    LaunchedEffect(isFocused) {
        itemScale.animateTo(
            targetValue = targetScale,
            animationSpec = tween(durationMillis = 200, easing = FastOutSlowInEasing)
        )
    }

    val bgColor = when {
        isSelected -> Color(0x38FFFFFF)
        isFocused -> Color(0x14FFFFFF)
        else -> Color.Transparent
    }

    val borderColor = if (isFocused) Color(0x30FFFFFF) else Color.Transparent

    val iconTint = when {
        isSelected || isFocused -> Color.White
        else -> Color(0xFF999999)
    }

    val iconBgColor = if (isSelected) Color(0x28FFFFFF) else Color(0xFF222222)

    val labelColor = when {
        isSelected || isFocused -> Color.White
        else -> Color(0xFF999999)
    }

    Row(
        modifier = modifier
            .scale(itemScale.value)
            .clip(RoundedCornerShape(28.dp))
            .background(color = bgColor)
            .border(
                width = if (isFocused) 1.5.dp else 0.dp,
                color = borderColor,
                shape = RoundedCornerShape(28.dp)
            )
            .onFocusChanged { focusState ->
                if (focusState.hasFocus) onFocusIn() else onFocusOut()
            }
            .focusProperties { canFocus = expanded }
            .clickable(
                onClick = onClick,
                indication = null
            )
            .padding(
                horizontal = if (expanded) 14.dp else 0.dp,
                vertical = 10.dp
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(iconBgColor),
            contentAlignment = Alignment.Center
        ) {
            androidx.compose.material3.Icon(
                painter = painterResource(id = iconRes),
                contentDescription = label,
                tint = iconTint,
                modifier = Modifier.size(18.dp)
            )
        }

        if (expanded) {
            Spacer(modifier = Modifier.width(12.dp))

            AnimatedVisibility(
                visible = expanded,
                enter = expandHorizontally(
                    animationSpec = tween(durationMillis = 380, easing = FastOutSlowInEasing)
                ),
                exit = shrinkHorizontally(
                    animationSpec = tween(durationMillis = 380, easing = FastOutSlowInEasing)
                )
            ) {
                androidx.compose.material3.Text(
                    text = label,
                    color = labelColor,
                    fontSize = 14.sp,
                    fontWeight = if (isSelected) FontWeight.W600 else FontWeight.W400,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(end = 4.dp)
                )
            }
        }
    }
}
