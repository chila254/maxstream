package com.maxstream.app.ui.navigation

/** Screens in the desktop shell. Detail is opened inline (overlays the Home
 *  content, with a back button) rather than pushed on a remote-driven stack —
 *  this is a pointer-app, so navigation stays lightweight and click-based. */
sealed interface AppRoute {
    data object Home : AppRoute
    data object Movies : AppRoute
    data object Series : AppRoute
    data object Watchlist : AppRoute
    data object Settings : AppRoute
    data class Detail(val itemId: String, val key: String = itemId) : AppRoute
}