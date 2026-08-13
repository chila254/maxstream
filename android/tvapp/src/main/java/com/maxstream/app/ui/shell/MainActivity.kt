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
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.focus.focusRequester
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
// Root composable — owns the IndexedStack shell and back state machine
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun TvAppRoot() {
    val appState = rememberTvAppState()

    // One FocusRequester per sidebar item + one for the content region.
    // These are the same nodes Sidebar and each screen attach themselves to.
    val sidebarFocusRequesters = remember { List(6) { FocusRequester() } }
    val contentFocusRequester = remember { FocusRequester() }

    // Deep-nav controller: only used for Details / Player / Splash / Login.
    // Tab screens are rendered via IndexedStack and are never "navigated to".
    val deepNavController = rememberNavController()

    // Wire TvFocusManager so screens can call focusSidebar() / focusContent()
    LaunchedEffect(Unit) {
        TvFocusManager.initialize(
            sidebarFocusRequesters = sidebarFocusRequesters,
            contentFocusRequester = contentFocusRequester,
        )
    }

    // ── Exit dialog state ──────────────────────────────────────────────────
    var exitDialogVisible by remember { mutableStateOf(false) }

    // ── Back state machine (mirrors Dart _handleSystemBack) ───────────────
    // Priority: deep nav pop → sidebar-while-content → home-while-sidebar → exit dialog
    fun handleBack() {
        if (deepNavController.previousBackStackEntry != null) {
            deepNavController.popBackStack()
            return
        }
        if (appState.selectedTab != 0) {
            if (appState.focusOnSidebar) {
                // Second back on sidebar: go to Home tab, focus content
                appState.selectTab(0)
                appState.setFocusOnSidebar(false)
            } else {
                // First back on content: move focus to sidebar
                appState.setFocusOnSidebar(true)
            }
            return
        }
        // Already on Home tab
        exitDialogVisible = true
    }

    // Shell-level key handler — only intercepts Back/Escape that bubbled all
    // the way up (i.e. nothing deeper consumed it).
    val shellKeyHandler: (androidx.compose.ui.input.key.KeyEvent) -> Boolean = { event ->
        if (event.type == KeyEventType.KeyDown &&
            (event.key == Key.Back ||
                    event.key == Key.Escape ||
                    event.key == Key.NavigateBack)
        ) {
            handleBack()
            true
        } else false
    }

    // ── Focus transfer side-effects ────────────────────────────────────────
    // Every time focusOnSidebar or selectedTab changes, move hardware focus.
    LaunchedEffect(appState.focusOnSidebar, appState.selectedTab) {
        delay(50) // One frame — content composables need to attach their nodes first
        if (appState.focusOnSidebar) {
            runCatching {
                sidebarFocusRequesters.getOrNull(appState.selectedTab)?.requestFocus()
            }
        } else {
            runCatching { contentFocusRequester.requestFocus() }
        }
    }

    // ── Layout ─────────────────────────────────────────────────────────────
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0F0F0F))
            .onKeyEvent { event ->
                shellKeyHandler(event)
            }
    ) {
        // The root NavHost handles Splash, Login, Pairing, Details, Player.
        // It starts at Splash; once auth is done it navigates to the shell.
        NavHost(
            navController = deepNavController,
            startDestination = Screen.Splash.route,
            enterTransition = { fadeIn(tween(300)) },
            exitTransition = { fadeOut(tween(180)) },
        ) {
            composable(Screen.Splash.route) {
                SplashScreen(
                    onComplete = {
                        deepNavController.navigate(Screen.Shell.route) {
                            popUpTo(Screen.Splash.route) { inclusive = true }
                        }
                    }
                )
            }
            composable(Screen.Login.route) {
                LoginScreen(
                    onLoginSuccess = {
                        deepNavController.navigate(Screen.Shell.route) {
                            popUpTo(Screen.Login.route) { inclusive = true }
                        }
                    }
                )
            }
            composable(Screen.Pairing.route) {
                PairingScreen(
                    onComplete = {
                        deepNavController.navigate(Screen.Shell.route) {
                            popUpTo(Screen.Pairing.route) { inclusive = true }
                        }
                    }
                )
            }
            // The shell itself — sidebar + IndexedStack
            composable(Screen.Shell.route) {
                TvShell(
                    appState = appState,
                    sidebarFocusRequesters = sidebarFocusRequesters,
                    contentFocusRequester = contentFocusRequester,
                    deepNavController = deepNavController,
                )
            }
            composable(Screen.Details.route) { backStackEntry ->
                val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                DetailsScreen(
                    navController = deepNavController,
                    itemId = itemId,
                    onReturnToSidebar = {
                        deepNavController.popBackStack()
                        appState.setFocusOnSidebar(true)
                    },
                )
            }
            composable(Screen.Series.route) { backStackEntry ->
                val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                SeriesScreen(
                    navController = deepNavController,
                    itemId = itemId,
                    onReturnToSidebar = {
                        deepNavController.popBackStack()
                        appState.setFocusOnSidebar(true)
                    },
                )
            }
            composable(Screen.Player.route) { backStackEntry ->
                val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                val mediaType = backStackEntry.arguments?.getString("mediaType") ?: "movie"
                val season = backStackEntry.arguments?.getString("season")?.toIntOrNull() ?: 1
                val episode = backStackEntry.arguments?.getString("episode")?.toIntOrNull() ?: 1
                PlayerScreen(deepNavController, itemId, mediaType, season, episode)
            }
        }

        // Exit confirmation dialog
        if (exitDialogVisible) {
            val activity = androidx.compose.ui.platform.LocalContext.current as? android.app.Activity
            ExitDialog(
                onDismiss = { exitDialogVisible = false },
                onConfirm = {
                    exitDialogVisible = false
                    activity?.finish()
                }
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell — sidebar + IndexedStack content area (mirrors Dart _buildRootShell)
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
            selectedIndex = appState.selectedTab,
            focusRequesters = sidebarFocusRequesters,
            onItemSelected = { index ->
                appState.selectTab(index)
                // Focus will transfer to content via the LaunchedEffect in TvAppRoot
            },
            onReturnToContent = {
                appState.setFocusOnSidebar(false)
            },
        )

        // ── Content — IndexedStack (all screens stay alive) ────────────────
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxSize()
                .focusRequester(contentFocusRequester)
        ) {
            // Each screen is composed at all times; only the selected one fills
            // its space. The unselected ones collapse to 0×0 so focus inside
            // them cannot be accidentally reached by D-pad traversal.
            TabScreen(visible = appState.selectedTab == 0) {
                HomeScreen(
                    navController = deepNavController,
                    onReturnToSidebar = { appState.setFocusOnSidebar(true) },
                    isVisible = appState.selectedTab == 0,
                )
            }
            TabScreen(visible = appState.selectedTab == 1) {
                SearchScreen(
                    navController = deepNavController,
                    onReturnToSidebar = { appState.setFocusOnSidebar(true) },
                    isVisible = appState.selectedTab == 1,
                )
            }
            TabScreen(visible = appState.selectedTab == 2) {
                GenreScreen(
                    navController = deepNavController,
                    onReturnToSidebar = { appState.setFocusOnSidebar(true) },
                    isVisible = appState.selectedTab == 2,
                )
            }
            TabScreen(visible = appState.selectedTab == 3) {
                // Tab index 3 is the Series LIST screen (not a single series detail)
                SeriesListTab(
                    navController = deepNavController,
                    onReturnToSidebar = { appState.setFocusOnSidebar(true) },
                    isVisible = appState.selectedTab == 3,
                )
            }
            TabScreen(visible = appState.selectedTab == 4) {
                WatchlistScreen(
                    navController = deepNavController,
                    onReturnToSidebar = { appState.setFocusOnSidebar(true) },
                    isVisible = appState.selectedTab == 4,
                )
            }
            TabScreen(visible = appState.selectedTab == 5) {
                MoreScreen(
                    navController = deepNavController,
                    onReturnToSidebar = { appState.setFocusOnSidebar(true) },
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

/**
 * IndexedStack cell: fills when [visible], collapses to 0×0 when not.
 * Collapsing (rather than removing) keeps the composable alive so its state
 * (scroll position, loaded data) is preserved across tab switches — identical
 * to Flutter's IndexedStack behaviour.
 */
@Composable
private fun TabScreen(
    visible: Boolean,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = if (visible) Modifier.fillMaxSize()
        else Modifier.size(0.dp)
    ) {
        content()
    }
}

// Thin wrapper so the "series list" tab doesn't conflict with the deep-nav
// SeriesScreen (which shows a single series).  In Dart this was TvSeriesListScreen.
@Composable
private fun SeriesListTab(
    navController: androidx.navigation.NavController,
    onReturnToSidebar: () -> Unit,
    isVisible: Boolean,
) {
    // Reuse GenreScreen filtered to TV, or a dedicated SeriesListScreen if you
    // have one.  For now we forward to GenreScreen with TV pre-selected.
    GenreScreen(
        navController = navController,
        onReturnToSidebar = onReturnToSidebar,
        isVisible = isVisible,
        initialMediaType = "tv",
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// Exit dialog
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ExitDialog(
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1E1E1E),
        title = {
            Text(
                text = "Exit MaxStream?",
                color = Color.White,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
            )
        },
        text = {
            Text(
                text = "Do you want to exit the app?",
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 18.sp,
            )
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = Color.Gray, fontSize = 18.sp)
            }
        },
        confirmButton = {
            FilledTonalButton(
                onClick = onConfirm,
                colors = ButtonDefaults.filledTonalButtonColors(
                    containerColor = Color(0xFFE50914),
                    contentColor = Color.White,
                ),
            ) {
                Text("Exit", fontSize = 18.sp)
            }
        },
    )
}
