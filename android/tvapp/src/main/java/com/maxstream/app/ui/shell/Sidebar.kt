package com.maxstream.app.ui.shell

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.R

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

private data class NavEntry(val labelRes: Int, val iconRes: Int)

private val NAV_ENTRIES = listOf(
    NavEntry(R.string.home,      R.drawable.ic_home),
    NavEntry(R.string.search,    R.drawable.ic_search),
    NavEntry(R.string.genre,     R.drawable.ic_genre),
    NavEntry(R.string.series,    R.drawable.ic_series),
    NavEntry(R.string.watchlist, R.drawable.ic_watchlist),
    NavEntry(R.string.more,      R.drawable.ic_more),
)

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Left sidebar navigation.
 *
 * Architecture notes (fixes applied vs previous version):
 * - Width animation is owned entirely here — no parent passing a width modifier.
 * - [focusRequesters] are created by MainActivity and shared so external code
 *   (back state machine) can programmatically focus a sidebar item.
 * - `canFocus` is NEVER set to false — items are always focusable; only the
 *   visual label is shown/hidden based on [_focusedIndex].
 * - A single LaunchedEffect(focusedIndex) drives expand/collapse (no Unit bug).
 * - Key handler: ↑↓ move within sidebar, →/Enter selects and moves to content,
 *   ← is swallowed (no-op — already on the left edge), Back/Escape bubbles up
 *   to the shell's state machine.
 */
@Composable
fun Sidebar(
    selectedIndex: Int,
    focusRequesters: List<FocusRequester>,
    onItemSelected: (Int) -> Unit,
    onReturnToContent: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // ── Local focus state ──────────────────────────────────────────────────
    // -1 = no sidebar item focused (sidebar collapsed)
    var focusedIndex by remember { mutableStateOf(-1) }
    var isExpanded by remember { mutableStateOf(false) }

    // Single effect — expand when any item is focused, collapse when none is.
    LaunchedEffect(focusedIndex) {
        isExpanded = focusedIndex >= 0
    }

    // ── Width animation ────────────────────────────────────────────────────
    val sidebarWidth by animateDpAsState(
        targetValue = if (isExpanded) 220.dp else 76.dp,
        animationSpec = tween(durationMillis = 380, easing = FastOutSlowInEasing),
        label = "sidebarWidth",
    )

    Box(
        modifier = modifier
            .width(sidebarWidth)
            .fillMaxHeight()
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color(0xFF1A1A1A), Color(0xFF111111))
                )
            )
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = 0.09f),
                shape = RoundedCornerShape(0.dp),
            ),
        contentAlignment = Alignment.Center,
    ) {
        // Logo pinned at top
        Box(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 24.dp)
                .size(40.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "M",
                color = Color(0xFFE50914),
                fontSize = 20.sp,
                fontWeight = FontWeight.Black,
            )
        }

        // Nav items — vertically centered in the full sidebar height
        Column(
            modifier = Modifier.padding(horizontal = 10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            NAV_ENTRIES.forEachIndexed { index, entry ->
                SidebarPillItem(
                    labelRes = entry.labelRes,
                    iconRes = entry.iconRes,
                    isSelected = index == selectedIndex,
                    isFocused = index == focusedIndex,
                    isExpanded = isExpanded,
                    focusRequester = focusRequesters[index],
                    onFocusChanged = { hasFocus ->
                        if (hasFocus) focusedIndex = index
                        else if (focusedIndex == index) focusedIndex = -1
                    },
                    onSelect = {
                        onItemSelected(index)
                        runCatching { onReturnToContent() }
                    },
                    onMoveUp = {
                        if (index > 0) runCatching { focusRequesters[index - 1].requestFocus() }
                    },
                    onMoveDown = {
                        if (index < NAV_ENTRIES.lastIndex) runCatching { focusRequesters[index + 1].requestFocus() }
                    },
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill item
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SidebarPillItem(
    labelRes: Int,
    iconRes: Int,
    isSelected: Boolean,
    isFocused: Boolean,
    isExpanded: Boolean,
    focusRequester: FocusRequester,
    onFocusChanged: (Boolean) -> Unit,
    onSelect: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.05f else 1f,
        animationSpec = tween(200, easing = FastOutSlowInEasing),
        label = "pillScale",
    )

    val bgColor = when {
        isSelected -> Color(0x38FFFFFF)
        isFocused  -> Color(0x14FFFFFF)
        else       -> Color.Transparent
    }
    val borderColor = if (isFocused) Color(0x30FFFFFF) else Color.Transparent
    val iconTint = if (isSelected || isFocused) Color.White else Color(0xFF999999)
    val iconBg   = if (isSelected) Color(0x28FFFFFF) else Color(0xFF222222)
    val labelColor = if (isSelected || isFocused) Color.White else Color(0xFF999999)

    Row(
        modifier = Modifier
            .scale(scale)
            .clip(RoundedCornerShape(28.dp))
            .background(bgColor)
            .border(
                width = if (isFocused) 1.5.dp else 0.dp,
                color = borderColor,
                shape = RoundedCornerShape(28.dp),
            )
            .focusRequester(focusRequester)
            // ← IMPORTANT: canFocus is never false. Collapsing the label is
            //   purely visual — items must always be reachable by D-pad.
            .focusable()
            .onFocusChanged { state -> onFocusChanged(state.hasFocus) }
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionUp   -> { onMoveUp();  true }
                    Key.DirectionDown -> { onMoveDown(); true }
                    // Right arrow OR Enter/Select → select item and move to content
                    Key.DirectionRight,
                    Key.Enter,
                    Key.DirectionCenter -> { onSelect(); true }
                    // Left is already at the left edge — swallow so the system
                    // doesn't try to route to non-existent items further left.
                    Key.DirectionLeft -> true
                    // Back/Escape intentionally NOT handled here — let it bubble
                    // to the shell's onKeyEvent so the back state machine runs.
                    else -> false
                }
            }
            .clickable { runCatching { onSelect() } }
            .padding(
                horizontal = if (isExpanded) 12.dp else 0.dp,
                vertical = 10.dp,
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = if (isExpanded) Arrangement.Start else Arrangement.Center,
    ) {
        // Icon circle
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(iconBg),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painterResource(iconRes),
                contentDescription = null,
                tint = iconTint,
                modifier = Modifier.size(18.dp),
            )
        }

        // Label — always composed but width-animated so it slides in/out
        val labelWidth by animateDpAsState(
            targetValue = if (isExpanded) 140.dp else 0.dp,
            animationSpec = tween(durationMillis = 380, easing = FastOutSlowInEasing),
            label = "labelWidth",
        )
        if (labelWidth > 0.dp) {
            Spacer(modifier = Modifier.width(12.dp))
            Box(modifier = Modifier.width(labelWidth)) {
                Text(
                    text = androidx.compose.ui.res.stringResource(labelRes),
                    color = labelColor,
                    fontSize = 14.sp,
                    fontWeight = if (isSelected) FontWeight.W600 else FontWeight.W400,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}
