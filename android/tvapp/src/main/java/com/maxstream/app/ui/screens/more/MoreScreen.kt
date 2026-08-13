package com.maxstream.app.ui.screens.more

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
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.maxstream.app.R
import com.maxstream.app.data.local.SessionManager
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background

private data class MoreMenuItem(val label: String, val isDestructive: Boolean = false)

private val MENU_ITEMS = listOf(
    MoreMenuItem("Help & Support"),
    MoreMenuItem("About MaxStream"),
    MoreMenuItem("Join Community"),
    MoreMenuItem("Sign Out", isDestructive = true),
)

@Composable
fun MoreScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit = {},
    onSignOut: () -> Unit = {},
    isVisible: Boolean = true,
) {
    val context = LocalContext.current
    var userName  by remember { mutableStateOf("MaxStream User") }
    var userEmail by remember { mutableStateOf("") }

    // One FocusRequester per menu item so we can navigate and seed focus precisely
    val focusRequesters = remember { List(MENU_ITEMS.size) { FocusRequester() } }
    var focusedIndex by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        val email = SessionManager.email(context)
        if (email.isNotBlank()) {
            userName  = email.substringBefore("@").replaceFirstChar { it.uppercase() }
            userEmail = email
        }
    }

    // Seed focus on first menu item when tab becomes visible
    LaunchedEffect(isVisible) {
        if (!isVisible) return@LaunchedEffect
        kotlinx.coroutines.delay(80)
        runCatching { focusRequesters[0].requestFocus() }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
    ) {
        // ── Profile section ────────────────────────────────────────────────
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 56.dp)
                .padding(horizontal = 48.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF222222)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = userName.take(1).uppercase(),
                    color = Color.White,
                    fontSize = 38.sp,
                    fontWeight = FontWeight.Bold,
                )
            }

            Spacer(Modifier.height(16.dp))
            Text(text = userName, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
            if (userEmail.isNotBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(text = userEmail, color = Color(0xFFB3B3B3), fontSize = 14.sp)
            }
        }

        Spacer(Modifier.height(40.dp))

        // ── Menu items ─────────────────────────────────────────────────────
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 48.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MENU_ITEMS.forEachIndexed { index, item ->
                MoreMenuRow(
                    label = item.label,
                    isDestructive = item.isDestructive,
                    isFocused = focusedIndex == index,
                    focusRequester = focusRequesters[index],
                    onFocused = { focusedIndex = index },
                    onMoveUp = {
                        if (index > 0) focusRequesters[index - 1].requestFocus()
                        else onReturnToSidebar()
                    },
                    onMoveDown = {
                        if (index < MENU_ITEMS.lastIndex) focusRequesters[index + 1].requestFocus()
                    },
                    onMoveLeft = { onReturnToSidebar() },
                    onClick = {
                        when (index) {
                            3 -> { // Sign Out
                                SessionManager.signOut(context)
                                onSignOut()
                            }
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun MoreMenuRow(
    label: String,
    isDestructive: Boolean,
    isFocused: Boolean,
    focusRequester: FocusRequester,
    onFocused: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onMoveLeft: () -> Unit,
    onClick: () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.02f else 1f,
        animationSpec = tween(200, easing = FastOutSlowInEasing),
        label = "menuRowScale",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .scale(scale)
            .clip(RoundedCornerShape(12.dp))
            .background(if (isFocused) Color(0xFF2A2A2A) else Color(0xFF1A1A1A))
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White.copy(alpha = 0.3f) else Color.Transparent,
                shape = RoundedCornerShape(12.dp),
            )
            .focusRequester(focusRequester)
            .focusable()
            .onFocusChanged { state -> if (state.hasFocus) onFocused() }
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionUp   -> { onMoveUp(); true }
                    Key.DirectionDown -> { onMoveDown(); true }
                    Key.DirectionLeft -> { onMoveLeft(); true }
                    Key.Enter, Key.DirectionCenter -> { onClick(); true }
                    else -> false
                }
            }
            .clickable(onClick = onClick)
            .padding(horizontal = 24.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            color = if (isDestructive) Color(0xFFCF6679) else Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Medium,
        )
        Icon(
            painter = painterResource(R.drawable.ic_more),
            contentDescription = null,
            tint = if (isDestructive) Color(0xFFCF6679).copy(alpha = 0.6f) else Color.Gray,
            modifier = Modifier.size(20.dp),
        )
    }
}
