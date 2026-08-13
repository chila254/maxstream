package com.maxstream.app.ui.navigation

sealed class Screen(val route: String) {
    data object Splash : Screen("splash")
    data object Login : Screen("login")
    data object Pairing : Screen("pairing")
    data object Home : Screen("home")
    data object Search : Screen("search")
    data object Genre : Screen("genre")
    data object Series : Screen("series")
    data object Watchlist : Screen("watchlist")
    data object More : Screen("more")
    data object Details : Screen("details/{itemId}") {
        fun createRoute(itemId: String) = "details/$itemId"
    }
    data object Player : Screen("player/{sourceJson}") {
        fun createRoute(sourceJson: String) = "player/$sourceJson"
    }
}
