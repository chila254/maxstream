package com.maxstream.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
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

@Composable
fun MaxStreamNavHost(startDestination: String = Screen.Splash.route) {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = startDestination) {
        composable(Screen.Splash.route) { SplashScreen(navController) }
        composable(Screen.Login.route) { LoginScreen(navController) }
        composable(Screen.Pairing.route) { PairingScreen(navController) }
        composable(Screen.Home.route) { HomeScreen(navController) }
        composable(Screen.Search.route) { SearchScreen(navController) }
        composable(Screen.Genre.route) { GenreScreen(navController) }
        composable(Screen.Series.route) { SeriesScreen(navController) }
        composable(Screen.Watchlist.route) { WatchlistScreen(navController) }
        composable(Screen.More.route) { MoreScreen(navController) }
        composable(Screen.Details.route) { backStackEntry ->
            val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
            DetailsScreen(navController, itemId)
        }
        composable(Screen.Player.route) { backStackEntry ->
            val sourceJson = backStackEntry.arguments?.getString("sourceJson") ?: ""
            PlayerScreen(navController, sourceJson)
        }
    }
}
