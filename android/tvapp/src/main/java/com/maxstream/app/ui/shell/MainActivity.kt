package com.maxstream.app.ui.shell

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.maxstream.app.R
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
import com.maxstream.app.ui.shell.Sidebar
import com.maxstream.app.ui.shell.SidebarSection

class MainActivity : ComponentActivity() {
    private val tag = "MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            setContent {
                MaxStreamTheme {
                    val navController = rememberNavController()
                    val navBackStackEntry by navController.currentBackStackEntryAsState()
                    val currentRoute = navBackStackEntry?.destination?.route ?: Screen.Splash.route
                    val isRootScreen = currentRoute in listOf(
                        Screen.Splash.route,
                        Screen.Login.route,
                        Screen.Pairing.route,
                        Screen.Home.route,
                        Screen.Search.route,
                        Screen.Genre.route,
                        Screen.Series.route,
                        Screen.Watchlist.route,
                        Screen.More.route,
                    )
                    var selectedIndex by remember { mutableStateOf(0) }
                    var sidebarExpanded by remember { mutableStateOf(false) }

                    val sections = listOf(
                        SidebarSection(Screen.Home, R.string.home, R.drawable.ic_home),
                        SidebarSection(Screen.Search, R.string.search, R.drawable.ic_search),
                        SidebarSection(Screen.Genre, R.string.genre, R.drawable.ic_genre),
                        SidebarSection(Screen.Series, R.string.series, R.drawable.ic_series),
                        SidebarSection(Screen.Watchlist, R.string.watchlist, R.drawable.ic_watchlist),
                        SidebarSection(Screen.More, R.string.more, R.drawable.ic_more),
                    )

                    Column(modifier = Modifier.fillMaxSize()) {
                        if (isRootScreen) {
                            Row(modifier = Modifier.fillMaxSize()) {
                                Sidebar(
                                    sections = sections,
                                    selectedIndex = selectedIndex,
                                    onSectionSelected = { index ->
                                        selectedIndex = index
                                        val route = sections[index].screen.route
                                        navController.navigate(route) {
                                            popUpTo(navController.graph.startDestinationId) {
                                                inclusive = true
                                            }
                                            launchSingleTop = true
                                        }
                                    },
                                    onExpandedChanged = { expanded ->
                                        sidebarExpanded = expanded
                                    },
                                    onReturnToContent = {
                                        navController.currentBackStackEntry
                                    },
                                    modifier = Modifier.width(if (sidebarExpanded) 220.dp else 76.dp)
                                )
                                NavHost(
                                    navController = navController,
                                    startDestination = Screen.Home.route,
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxHeight()
                                        .background(MaterialTheme.colorScheme.background)
                                ) {
                                    composable(Screen.Splash.route) { SplashScreen(navController) }
                                    composable(Screen.Login.route) { LoginScreen(navController) }
                                    composable(Screen.Pairing.route) { PairingScreen(navController) }
                                    composable(Screen.Home.route) {
                                        HomeScreen(
                                            navController = navController,
                                            onReturnToSidebar = {
                                                navController.popBackStack()
                                            }
                                        )
                                    }
                                    composable(Screen.Search.route) { SearchScreen(navController) }
                                    composable(Screen.Genre.route) { GenreScreen(navController) }
                                    composable(Screen.Series.route) { backStackEntry ->
                                        val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                                        SeriesScreen(navController, itemId)
                                    }
                                    composable(Screen.Watchlist.route) { WatchlistScreen(navController) }
                                    composable(Screen.More.route) { MoreScreen(navController) }
                                    composable(Screen.Details.route) { backStackEntry ->
                                        val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                                        DetailsScreen(navController, itemId)
                                    }
                                    composable(Screen.Player.route) { backStackEntry ->
                                        val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                                        val mediaType = backStackEntry.arguments?.getString("mediaType") ?: "movie"
                                        PlayerScreen(navController, itemId, mediaType)
                                    }
                                }
                            }
                        } else {
                            NavHost(
                                navController = navController,
                                startDestination = Screen.Home.route,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(MaterialTheme.colorScheme.background)
                            ) {
                                composable(Screen.Splash.route) { SplashScreen(navController) }
                                composable(Screen.Login.route) { LoginScreen(navController) }
                                composable(Screen.Pairing.route) { PairingScreen(navController) }
                                composable(Screen.Home.route) { HomeScreen(navController, onReturnToSidebar = { }) }
                                composable(Screen.Search.route) { SearchScreen(navController) }
                                composable(Screen.Genre.route) { GenreScreen(navController) }
                                composable(Screen.Series.route) { backStackEntry ->
                                    val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                                    SeriesScreen(navController, itemId)
                                }
                                composable(Screen.Watchlist.route) { WatchlistScreen(navController) }
                                composable(Screen.More.route) { MoreScreen(navController) }
                                composable(Screen.Details.route) { backStackEntry ->
                                    val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                                    DetailsScreen(navController, itemId)
                                }
                                composable(Screen.Player.route) { backStackEntry ->
                                    val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
                                    val mediaType = backStackEntry.arguments?.getString("mediaType") ?: "movie"
                                    PlayerScreen(navController, itemId, mediaType)
                                }
                            }
                        }
                    }
                }
            }
        } catch (t: Throwable) {
            Log.e(tag, "Compose startup failure", t)
        }
    }
}
