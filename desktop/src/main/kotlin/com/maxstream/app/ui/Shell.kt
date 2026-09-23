package com.maxstream.app.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.LiveTv
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.cloud.AppSession
import com.maxstream.app.data.cloud.CloudSync
import com.maxstream.app.data.model.PlayRequest
import com.maxstream.app.data.repository.MovieSection
import com.maxstream.app.data.repository.SeriesSection
import com.maxstream.app.data.repository.TmdbRepository
import com.maxstream.app.ui.navigation.AppRoute
import com.maxstream.app.ui.screens.DetailsScreen
import com.maxstream.app.ui.screens.HomeScreen
import com.maxstream.app.ui.screens.MoviesScreen
import com.maxstream.app.ui.screens.PlayerScreen
import com.maxstream.app.ui.screens.SeriesScreen
import com.maxstream.app.ui.screens.SettingsScreen
import com.maxstream.app.ui.screens.WatchlistScreen
import com.maxstream.app.ui.theme.DesktopTheme

private val repository = TmdbRepository

@Composable
fun Shell() {
    var route by remember { mutableStateOf<AppRoute>(AppRoute.Home) }
    var playerBackTo by remember { mutableStateOf<AppRoute>(AppRoute.Home) }
    var query by remember { mutableStateOf("") }
    // null = follow the OS; explicit true/false = user override (Settings).
    var darkOverride by remember { mutableStateOf<Boolean?>(null) }

    val useDark = darkOverride ?: false

    // Pull cloud watch history whenever the signed-in state changes.
    LaunchedEffect(AppSession.isSignedIn) {
        if (AppSession.isSignedIn) {
            CloudSync.syncWatchHistory()
        }
    }

    DesktopTheme(useDarkTheme = useDark) {
        if (route is AppRoute.Player) {
            val player = route as AppRoute.Player
            PlayerScreen(
                request = player.request,
                repository = repository,
                onBack = { route = playerBackTo },
            )
            return@DesktopTheme
        }
        Row(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.surface)) {
            NavRail(
                current = route,
                onSelect = { route = it },
                useDarkTheme = useDark,
                onToggleTheme = { darkOverride = it },
            )
            Column(Modifier.weight(1f).fillMaxHeight()) {
                TitleBar(
                    route = route,
                    query = query,
                    onQueryChange = { query = it },
                )
                Spacer(Modifier.height(1.dp).fillMaxWidth().background(MaterialTheme.colorScheme.outlineVariant))
                AnimatedContent(
                    targetState = route,
                    transitionSpec = { fadeIn() togetherWith fadeOut() },
                    label = "routeContent",
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                ) { target ->
                    when (target) {
                        is AppRoute.Home -> HomeScreen(
                            repository = repository,
                            query = query,
                            onOpen = { route = AppRoute.Detail(it.id, it.mediaType, it.id) },
                            onPlay = { m ->
                                playerBackTo = route
                                route = AppRoute.Player(PlayRequest(m.id, m.mediaType, m.title))
                            },
                            onSeeAllMovies = { section -> route = AppRoute.Movies(section) },
                            onSeeAllSeries = { section -> route = AppRoute.Series(section) },
                        )
                        is AppRoute.Movies -> MoviesScreen(
                            repository = repository,
                            initialSection = target.initialSection,
                            onOpen = { route = AppRoute.Detail(it.id, it.mediaType, it.id) },
                        )
                        is AppRoute.Series -> SeriesScreen(
                            repository = repository,
                            initialSection = target.initialSection,
                            onOpen = { route = AppRoute.Detail(it.id, it.mediaType, it.id) },
                        )
                        is AppRoute.Watchlist -> WatchlistScreen(
                            repository = repository,
                            isSignedIn = AppSession.isSignedIn,
                            onOpen = { route = AppRoute.Detail(it.id, it.mediaType, it.id) },
                        )
                        is AppRoute.Settings -> SettingsScreen(
                            useDarkTheme = useDark,
                            onThemeChange = { darkOverride = it },
                        )
                        is AppRoute.Detail -> DetailsScreen(
                            itemId = target.itemId,
                            mediaType = target.mediaType,
                            repository = repository,
                            onBack = { route = AppRoute.Home },
                            onPlay = { req: PlayRequest ->
                                playerBackTo = route
                                route = AppRoute.Player(req)
                            },
                        )
                        is AppRoute.Player -> Unit
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left navigation rail — click-driven, Windows-flat (not the TV remote model)
// ─────────────────────────────────────────────────────────────────────────────

private data class RailItem(
    val label: String,
    val icon: ImageVector,
    val route: AppRoute,
)

@Composable
private fun NavRail(
    current: AppRoute,
    onSelect: (AppRoute) -> Unit,
    useDarkTheme: Boolean,
    onToggleTheme: (Boolean) -> Unit,
) {
    val items = listOf(
        RailItem("Home", Icons.Default.Home, AppRoute.Home),
        RailItem("Movies", Icons.Default.Movie, AppRoute.Movies()),
        RailItem("Series", Icons.Default.LiveTv, AppRoute.Series()),
        RailItem("Watchlist", Icons.Default.Bookmark, AppRoute.Watchlist),
        RailItem("Settings", Icons.Default.Settings, AppRoute.Settings),
    )
    val selectedRoute = when (current) {
        is AppRoute.Detail -> AppRoute.Home
        else -> current
    }
    val user = AppSession.user

    Column(
        Modifier
            .width(232.dp)
            .fillMaxHeight()
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(vertical = 12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Box(
                Modifier
                    .size(32.dp)
                    .background(
                        Brush.linearGradient(listOf(MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.secondary)),
                        RoundedCornerShape(8.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.PlayArrow, null, tint = Color.White, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(10.dp))
            Text(
                "MaxStream",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }

        Spacer(Modifier.height(16.dp))

        items.forEach { item ->
            val selected = selectedRoute == item.route
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 10.dp)
                    .background(
                        if (selected) MaterialTheme.colorScheme.primaryContainer
                        else Color.Transparent,
                        RoundedCornerShape(8.dp),
                    )
                    .clickable { onSelect(item.route) }
                    .padding(horizontal = 12.dp, vertical = 10.dp),
            ) {
                Icon(
                    item.icon,
                    contentDescription = item.label,
                    tint = if (selected) MaterialTheme.colorScheme.onPrimaryContainer
                           else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(Modifier.width(12.dp))
                Text(
                    item.label,
                    color = if (selected) MaterialTheme.colorScheme.onPrimaryContainer
                            else MaterialTheme.colorScheme.onSurface,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    fontSize = 14.sp,
                )
            }
        }

        Spacer(Modifier.weight(1f))

        // Footer: profile chip + theme quick toggle
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Box(
                Modifier
                    .size(30.dp)
                    .background(MaterialTheme.colorScheme.secondary, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.Person, null, tint = Color.White, modifier = Modifier.size(18.dp))
            }
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    if (user != null) "You" else "Guest",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                )
                Text(
                    if (user != null) user.email else "Not signed in",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
            IconButton(onClick = { onToggleTheme(!useDarkTheme) }) {
                val icon = if (useDarkTheme) Icons.Default.LightMode else Icons.Default.DarkMode
                Icon(icon, contentDescription = "Toggle theme",
                    tint = MaterialTheme.colorScheme.onSurface)
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun TitleBar(
    route: AppRoute,
    query: String,
    onQueryChange: (String) -> Unit,
) {
    val title = when (route) {
        is AppRoute.Home -> "Home"
        is AppRoute.Movies -> "Movies"
        is AppRoute.Series -> "Series"
        is AppRoute.Watchlist -> "Watchlist"
        is AppRoute.Settings -> "Settings"
        is AppRoute.Detail -> "Details"
        is AppRoute.Player -> "Player"
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().height(52.dp).background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 16.dp),
    ) {
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(Modifier.weight(1f))
        if (route == AppRoute.Home) {
            OutlinedTextField(
                value = query,
                onValueChange = onQueryChange,
                placeholder = { Text("Search titles, genres…", color = MaterialTheme.colorScheme.outline) },
                leadingIcon = { Icon(Icons.Default.Search, null) },
                singleLine = true,
                shape = RoundedCornerShape(8.dp),
                textStyle = MaterialTheme.typography.bodyMedium,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surface,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                ),
                modifier = Modifier.width(300.dp).height(38.dp),
            )
        }
    }
}