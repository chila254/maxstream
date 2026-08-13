package com.maxstream.app.ui.shell

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.maxstream.app.data.local.WatchEntryCompat
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.screens.auth.LoginScreen
import com.maxstream.app.ui.screens.auth.PairingScreen
import com.maxstream.app.ui.screens.details.DetailsScreen
import com.maxstream.app.ui.screens.genre.GenreScreen
import com.maxstream.app.ui.screens.home.HomeScreen
import com.maxstream.app.ui.screens.more.MoreScreen
import com.maxstream.app.ui.screens.player.PlayerScreen
import com.maxstream.app.ui.screens.search.SearchScreen
import com.maxstream.app.ui.screens.series.SeriesListScreen
import com.maxstream.app.ui.screens.series.SeriesScreen
import com.maxstream.app.ui.screens.splash.SplashScreen
import com.maxstream.app.ui.screens.watchlist.WatchlistScreen
import com.maxstream.app.ui.theme.MaxStreamTheme
import com.maxstream.app.ui.tv.TvFocusManager
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WatchEntryCompat.init(applicationContext)

        try {
            setContent {
                MaxStreamTheme {
                    TvAppRoot()
                }
            }
        } catch (t: Throwable) {
            Log.e("MainActivity", "Compose startup failure", t)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root composable
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun TvAppRoot() {
    val appState = rememberTvAppState()

    // ── Focus architecture (mirrors Dart FocusScopeNode pattern) ─────────
    // sidebarFocusRequesters[i] is attached to each sidebar pill item.
    // contentFocusRequester is attached to the content Box AND made focusable,
    // so requestFocus() on it actually lands — the Box then passes focus to
    // its first focusable child via normal Compose focus traversal.
    val sidebarFocusRequesters = remember { List(6) { FocusRequester() } }
    val contentFocusRequester  = remember { FocusRequester() }

    val deepNavController = rememberNavController()

    // Wire TvFocusManager singleton (used by individual screens)
    LaunchedEffect(Unit) {
        TvFocusManager.initialize(
            sidebarFocusRequesters = sidebarFocusRequesters,
            contentFocusRequester  = contentFocusRequester,
        )
    }

    var exitDialogVisible by remember { mutableStateOf(false) }

    // ── Back state machine (Nuvio pattern) ──────────────────────────────
    // root=tab0, sidebar=expanded, content=collapsed.
    // - Back on root + sidebar focused → exit app
    // - Back on root + content focused → open sidebar (expand it)
    // - Back on non-root tab → navigate to home + focus sidebar
    // - Back on details/series (deep nav) → popBackStack
    fun handleBack() {
        // 1. Deep nav screens: popBackStack first
        if (deepNavController.previousBackStackEntry != null) {
            deepNavController.popBackStack()
            return
        }
        // 2. Home tab (root):
        if (appState.selectedTab == 0) {
            if (appState.focusOnSidebar) {
                // Home + sidebar → exit
                exitDialogVisible = true
            } else {
                // Home + content → open sidebar
                appState.updateFocusOnSidebar(true)
            }
            return
        }
        // 3. Non-home tab: always go to home + focus sidebar
        appState.selectTab(0)
        appState.updateFocusOnSidebar(true)
    }

    // ── Focus transfer effect ─────────────────────────────────────────────
    // Mirrors Nuvio's pattern: wait for 2 composition frames before
    // requesting focus, so layout is guaranteed to be complete.
    LaunchedEffect(appState.focusOnSidebar, appState.selectedTab) {
        // Wait 2 frames for layout to settle
        kotlinx.coroutines.delay(50)
        if (appState.focusOnSidebar) {
            runCatching {
                sidebarFocusRequesters.getOrNull(appState.selectedTab)?.requestFocus()
            }
        } else {
            runCatching { contentFocusRequester.requestFocus() }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0F0F0F))
            .onKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown &&
                    (event.key == Key.Back || event.key == Key.Escape)
                ) {
                    handleBack(); true
                } else false
            }
    ) {
        NavHost(
            navController = deepNavController,
            startDestination = Screen.Splash.route,
            enterTransition = { fadeIn(tween(300)) },
            exitTransition  = { fadeOut(tween(180)) },
        ) {
            composable(Screen.Splash.route) {
                SplashScreen(onComplete = {
                    deepNavController.navigate(Screen.Shell.route) {
                        popUpTo(Screen.Splash.route) { inclusive = true }
                    }
                })
            }
            composable(Screen.Login.route) {
                LoginScreen(onLoginSuccess = {
                    deepNavController.navigate(Screen.Shell.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                })
            }
            composable(Screen.Pairing.route) {
                PairingScreen(onComplete = {
                    deepNavController.navigate(Screen.Shell.route) {
                        popUpTo(Screen.Pairing.route) { inclusive = true }
                    }
                })
            }
            composable(Screen.Shell.route) {
                TvShell(
                    appState                = appState,
                    sidebarFocusRequesters  = sidebarFocusRequesters,
                    contentFocusRequester   = contentFocusRequester,
                    deepNavController       = deepNavController,
                )
            }
            composable(Screen.Details.route) { backStackEntry ->
                val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                DetailsScreen(
                    navController    = deepNavController,
                    itemId           = itemId,
                    onReturnToSidebar = {
                        deepNavController.popBackStack()
                        appState.updateFocusOnSidebar(true)
                    },
                )
            }
            composable(Screen.Series.route) { backStackEntry ->
                val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                SeriesScreen(
                    navController    = deepNavController,
                    itemId           = itemId,
                    onReturnToSidebar = {
                        deepNavController.popBackStack()
                        appState.updateFocusOnSidebar(true)
                    },
                )
            }
            composable(Screen.Player.route) { backStackEntry ->
                val itemId    = backStackEntry.arguments?.getString("itemId")    ?: ""
                val mediaType = backStackEntry.arguments?.getString("mediaType") ?: "movie"
                val season    = backStackEntry.arguments?.getString("season")?.toIntOrNull()  ?: 1
                val episode   = backStackEntry.arguments?.getString("episode")?.toIntOrNull() ?: 1
                PlayerScreen(deepNavController, itemId, mediaType, season, episode)
            }
        }

        if (exitDialogVisible) {
            val activity = androidx.compose.ui.platform.LocalContext.current as? android.app.Activity
            ExitDialog(
                onDismiss = { exitDialogVisible = false },
                onConfirm = { exitDialogVisible = false; activity?.finish() },
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell — sidebar + IndexedStack
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun TvShell(
    appState: TvAppState,
    sidebarFocusRequesters: List<FocusRequester>,
    contentFocusRequester: FocusRequester,
    deepNavController: androidx.navigation.NavController,
) {
    Row(modifier = Modifier.fillMaxSize()) {

        // ── Sidebar ────────────────────────────────────────────────────────
        Sidebar(
            selectedIndex   = appState.selectedTab,
            focusRequesters = sidebarFocusRequesters,
            onItemSelected  = { index -> appState.selectTab(index) },
            onReturnToContent = { appState.updateFocusOnSidebar(false) },
            onFocusEntered  = { appState.updateFocusOnSidebar(true) },
            active          = appState.focusOnSidebar,
        )

        // ── Content area ───────────────────────────────────────────────────
        // The contentFocusRequester is attached here AND the box is .focusable()
        // so requestFocus() actually lands on this node. Compose then passes
        // focus down to the first focusable child (the active screen's hero
        // button, keyboard, or card row).
        //
        // When sidebar is expanded, directional keys are blocked so focus
        // doesn't accidentally enter the content area (Nuvio pattern).
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxSize()
                .focusRequester(contentFocusRequester)
                .focusable()
                .onFocusChanged { state ->
                    if (state.hasFocus) appState.updateFocusOnSidebar(false)
                }
                .onKeyEvent { event ->
                    if (event.type == KeyEventType.KeyDown && appState.focusOnSidebar) {
                        when (event.key) {
                            Key.DirectionUp,
                            Key.DirectionDown,
                            Key.DirectionLeft,
                            Key.DirectionRight -> true  // block directional keys
                            else -> false
                        }
                    } else false
                }
        ) {
            TabScreen(visible = appState.selectedTab == 0) {
                HomeScreen(
                    navController     = deepNavController,
                    onReturnToSidebar = { appState.updateFocusOnSidebar(true) },
                    isVisible         = appState.selectedTab == 0,
                )
            }
            TabScreen(visible = appState.selectedTab == 1) {
                SearchScreen(
                    navController     = deepNavController,
                    onReturnToSidebar = { appState.updateFocusOnSidebar(true) },
                    isVisible         = appState.selectedTab == 1,
                )
            }
            TabScreen(visible = appState.selectedTab == 2) {
                GenreScreen(
                    navController     = deepNavController,
                    onReturnToSidebar = { appState.updateFocusOnSidebar(true) },
                    isVisible         = appState.selectedTab == 2,
                )
            }
            TabScreen(visible = appState.selectedTab == 3) {
                SeriesListTab(
                    navController     = deepNavController,
                    onReturnToSidebar = { appState.updateFocusOnSidebar(true) },
                    isVisible         = appState.selectedTab == 3,
                )
            }
            TabScreen(visible = appState.selectedTab == 4) {
                WatchlistScreen(
                    navController     = deepNavController,
                    onReturnToSidebar = { appState.updateFocusOnSidebar(true) },
                    isVisible         = appState.selectedTab == 4,
                )
            }
            TabScreen(visible = appState.selectedTab == 5) {
                MoreScreen(
                    navController     = deepNavController,
                    onReturnToSidebar = { appState.updateFocusOnSidebar(true) },
                    onSignOut = {
                        deepNavController.navigate(Screen.Login.route) {
                            popUpTo(Screen.Shell.route) { inclusive = true }
                        }
                    },
                    isVisible = appState.selectedTab == 5,
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IndexedStack cell
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Keeps the composable alive (for scroll/state preservation) but collapses
 * it to 0×0 and blocks all focus traversal into it when not visible.
 * Mirrors Flutter's IndexedStack + Offstage behaviour.
 */
@Composable
private fun TabScreen(
    visible: Boolean,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = if (visible) {
            Modifier.fillMaxSize()
        } else {
            Modifier
                .size(0.dp)
                .focusProperties { canFocus = false }
        }
    ) {
        content()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Series list tab wrapper
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SeriesListTab(
    navController: androidx.navigation.NavController,
    onReturnToSidebar: () -> Unit,
    isVisible: Boolean,
) {
    SeriesListScreen(
        navController     = navController,
        onReturnToSidebar = onReturnToSidebar,
        isVisible         = isVisible,
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// Exit dialog
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ExitDialog(onDismiss: () -> Unit, onConfirm: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor   = Color(0xFF1E1E1E),
        title = {
            Text("Exit MaxStream?", color = Color.White,
                fontSize = 24.sp, fontWeight = FontWeight.Bold)
        },
        text = {
            Text("Do you want to exit the app?",
                color = Color.White.copy(alpha = 0.7f), fontSize = 18.sp)
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = Color.Gray, fontSize = 18.sp)
            }
        },
        confirmButton = {
            FilledTonalButton(
                onClick = onConfirm,
                colors  = ButtonDefaults.filledTonalButtonColors(
                    containerColor = Color(0xFFE50914),
                    contentColor   = Color.White,
                ),
            ) { Text("Exit", fontSize = 18.sp) }
        },
    )
}
