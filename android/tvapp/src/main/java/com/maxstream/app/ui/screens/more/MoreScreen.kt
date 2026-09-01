package com.maxstream.app.ui.screens.more

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import kotlinx.coroutines.delay

private data class MoreMenuItem(val label: String, val isDestructive: Boolean = false)

private val MENU_ITEMS = listOf(
    MoreMenuItem("Help & Support"),
    MoreMenuItem("About MaxStream"),
    MoreMenuItem("Join Community"),
    MoreMenuItem("Sign Out", isDestructive = true),
)

private const val COMMUNITY_URL = "https://t.me/maxstream254"

// ─────────────────────────────────────────────────────────────────────────────
// MoreScreen (Tab 6)
//
// Mirrors Dart TvMoreScreen:
//  - Help & Support / About MaxStream → AlertDialogs
//  - Join Community → external browser (t.me/maxstream254)
//  - Sign Out → confirmation dialog, then SessionManager.signOut + onSignOut()
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun MoreScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit = {},
    onSignOut: () -> Unit = {},
    isVisible: Boolean = true,
    focusKey: Int = 0,
    restoreFocusKey: Int = 0,
) {
    val context = LocalContext.current
    var userName  by remember { mutableStateOf("MaxStream User") }
    var userEmail by remember { mutableStateOf("") }

    var showHelpDialog     by remember { mutableStateOf(false) }
    var showAboutDialog    by remember { mutableStateOf(false) }
    var showSignOutConfirm by remember { mutableStateOf(false) }

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

    // Seed focus on menu item when tab becomes visible, or re-seed the
    // previously focused item when focus returns from the sidebar (focusKey bump).
    LaunchedEffect(isVisible, focusKey) {
        if (!isVisible) return@LaunchedEffect
        val index = focusedIndex.coerceIn(0, MENU_ITEMS.lastIndex)
        var attempt = 0
        while (attempt < 6) {
            if (attempt > 0) delay(50L * attempt)
            val ok = runCatching { focusRequesters[index].requestFocus() }
            if (ok.isSuccess) return@LaunchedEffect
            attempt++
        }
    }

    // Deep-nav return: details/player overlay popped. Restore the previously
    // focused menu item (the shell — and its FocusRequesters — never left
    // composition, so the requesters are still valid).
    LaunchedEffect(isVisible, restoreFocusKey, focusedIndex) {
        if (!isVisible || restoreFocusKey <= 0) return@LaunchedEffect
        val index = focusedIndex.coerceIn(0, MENU_ITEMS.lastIndex)
        runCatching { focusRequesters[index].requestFocus() }
    }

    // Restore focus to the previously focused menu row after a dialog closes.
    // Compose dialogs run in their own window, so dismissing one leaves the
    // menu without focus until a direction key is pressed again.
    LaunchedEffect(showHelpDialog, showAboutDialog, showSignOutConfirm) {
        if (showHelpDialog || showAboutDialog || showSignOutConfirm || !isVisible) return@LaunchedEffect
        delay(80)
        val index = focusedIndex.coerceIn(0, MENU_ITEMS.lastIndex)
        runCatching { focusRequesters[index].requestFocus() }
    }

    fun launchCommunity() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(COMMUNITY_URL))
        runCatching { context.startActivity(intent) }
    }

    fun handleSelect(index: Int) {
        when (index) {
            0 -> showHelpDialog = true
            1 -> showAboutDialog = true
            2 -> launchCommunity()
            3 -> showSignOutConfirm = true
        }
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
                    onKeyEvent = { event ->
                        if (event.type == KeyEventType.KeyDown &&
                            (event.key == Key.Back || event.key == Key.Escape)
                        ) {
                            onReturnToSidebar(); true
                        } else false
                    },
                    onClick = { handleSelect(index) },
                )
            }
        }
    }

    // ── Dialogs ────────────────────────────────────────────────────────────
    if (showHelpDialog) {
        AlertDialog(
            onDismissRequest = { showHelpDialog = false },
            containerColor   = Color(0xFF1E1E1E),
            title = {
                Text(
                    text = "Help & Support",
                    color = Color.White,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                )
            },
            text = {
                Text(
                    text = "For help and support, please join our community or contact us through the app.",
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 18.sp,
                )
            },
            confirmButton = {
                TextButton(onClick = { showHelpDialog = false }) {
                    Text("OK", color = Color(0xFFE50914), fontSize = 18.sp)
                }
            },
        )
    }

    val tvVersion = remember {
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.6.0"
        }.getOrDefault("1.6.0")
    }
    if (showAboutDialog) {
        AlertDialog(
            onDismissRequest = { showAboutDialog = false },
            containerColor   = Color(0xFF1E1E1E),
            title = {
                Text(
                    text = "About MaxStream",
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                )
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "MaxStream Tv v$tvVersion",
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = "A modern movie and TV discovery app powered by The Movie Database (TMDb).",
                        color = Color.White.copy(alpha = 0.85f),
                        fontSize = 16.sp,
                    )
                    Text(
                        text = "Discover, explore, and manage your watchlist with ease.",
                        color = Color.Gray,
                        fontSize = 16.sp,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = { showAboutDialog = false }) {
                    Text("OK", color = Color(0xFFE50914), fontSize = 16.sp)
                }
            },
        )
    }

    if (showSignOutConfirm) {
        AlertDialog(
            onDismissRequest = { showSignOutConfirm = false },
            containerColor   = Color(0xFF1E1E1E),
            title = {
                Text(
                    text = "Sign Out",
                    color = Color.White,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                )
            },
            text = {
                Text(
                    text = "Are you sure you want to sign out?",
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 18.sp,
                )
            },
            dismissButton = {
                TextButton(onClick = { showSignOutConfirm = false }) {
                    Text("Cancel", color = Color.Gray, fontSize = 18.sp)
                }
            },
            confirmButton = {
                FilledTonalButton(
                    onClick = {
                        showSignOutConfirm = false
                        SessionManager.signOut(context)
                        onSignOut()
                    },
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = Color(0xFFE50914),
                        contentColor   = Color.White,
                    ),
                ) {
                    Text("Sign Out", color = Color.White, fontSize = 18.sp)
                }
            },
        )
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
    onKeyEvent: (androidx.compose.ui.input.key.KeyEvent) -> Boolean = { false },
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
            .onFocusChanged { state -> if (state.hasFocus) onFocused() }
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionUp   -> { onMoveUp(); true }
                    Key.DirectionDown -> { onMoveDown(); true }
                    Key.DirectionLeft -> { onMoveLeft(); true }
                    Key.Enter, Key.DirectionCenter -> { onClick(); true }
                    else -> onKeyEvent(event)
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
