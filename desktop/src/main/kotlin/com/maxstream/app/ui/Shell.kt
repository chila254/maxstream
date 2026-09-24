package com.maxstream.app.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.LiveTv
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.cloud.AppSession
import com.maxstream.app.data.cloud.CloudSync
import com.maxstream.app.data.model.PlayRequest
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

private val topLevels = listOf<AppRoute>(
    AppRoute.Home,
    AppRoute.Movies(),
    AppRoute.Series(),
    AppRoute.Watchlist,
    AppRoute.Settings,
)

@Composable
fun Shell() {
    // Navigation history: last entry is the current route. Top-level sidebar
    // selections reset the stack; detail/player push so Back returns.
    var backStack by remember { mutableStateOf(listOf<AppRoute>(AppRoute.Home)) }
    val route = backStack.last()
    var query by remember { mutableStateOf("") }
    // Dark is the MaxStream default; Settings can force light.
    var darkOverride by remember { mutableStateOf(true) }

    val useDark = darkOverride

    fun push(next: AppRoute) {
        if (next != route) backStack = backStack + next
    }

    fun replaceRoot(next: AppRoute) {
        backStack = listOf(next)
    }

    fun back() {
        if (backStack.size > 1) backStack = backStack.dropLast(1)
    }

    // Pull cloud watch history whenever the signed-in state changes.
    LaunchedEffect(AppSession.isSignedIn) {
        if (AppSession.isSignedIn) {
            CloudSync.syncWatchHistory()
        }
    }

    DesktopTheme(useDarkTheme = useDark) {
        // Escape / browser-style Back anywhere except the root screen.
        Box(
            Modifier
                .fillMaxSize()
                .onKeyEvent { event ->
                    if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                    when (event.key) {
                        Key.Escape -> {
                            if (backStack.size > 1) { back(); true } else false
                        }
                        else -> false
                    }
                },
        ) {
            if (route is AppRoute.Player) {
                val player = route as AppRoute.Player
                PlayerScreen(
                    request = player.request,
                    repository = repository,
                    onBack = { back() },
                )
                return@Box
            }
            Row(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.surface)) {
                NavRail(
                    current = route,
                    onSelectRoot = { replaceRoot(it) },
                    useDarkTheme = useDark,
                    onToggleTheme = { darkOverride = it },
                )
                Column(Modifier.weight(1f).fillMaxHeight()) {
                    TitleBar(
                        route = route,
                        canGoBack = backStack.size > 1,
                        onBack = { back() },
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
                                onOpen = { push(AppRoute.Detail(it.id, it.mediaType, it.id)) },
                                onPlay = { m ->
                                    push(AppRoute.Player(PlayRequest(m.id, m.mediaType, m.title)))
                                },
                                onSeeAllMovies = { section -> push(AppRoute.Movies(section)) },
                                onSeeAllSeries = { section -> push(AppRoute.Series(section)) },
                            )
                            is AppRoute.Movies -> MoviesScreen(
                                repository = repository,
                                initialSection = target.initialSection,
                                onOpen = { push(AppRoute.Detail(it.id, it.mediaType, it.id)) },
                            )
                            is AppRoute.Series -> SeriesScreen(
                                repository = repository,
                                initialSection = target.initialSection,
                                onOpen = { push(AppRoute.Detail(it.id, it.mediaType, it.id)) },
                            )
                            is AppRoute.Watchlist -> WatchlistScreen(
                                repository = repository,
                                isSignedIn = AppSession.isSignedIn,
                                onOpen = { push(AppRoute.Detail(it.id, it.mediaType, it.id)) },
                            )
                            is AppRoute.Settings -> SettingsScreen(
                                useDarkTheme = useDark,
                                onThemeChange = { darkOverride = it },
                            )
                            is AppRoute.Detail -> DetailsScreen(
                                itemId = target.itemId,
                                mediaType = target.mediaType,
                                repository = repository,
                                onBack = { back() },
                                onPlay = { req: PlayRequest ->
                                    push(AppRoute.Player(req))
                                },
                            )
                            is AppRoute.Player -> Unit
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left navigation rail — collapsible (icon-only ↔ expanded), click-driven
// ─────────────────────────────────────────────────────────────────────────────

private data class RailItem(
    val label: String,
    val icon: ImageVector,
    val route: AppRoute,
)

@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
private fun NavRail(
    current: AppRoute,
    onSelectRoot: (AppRoute) -> Unit,
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
    // Hover expands labels; chevron can pin the expanded state open.
    var pinnedExpanded by remember { mutableStateOf(false) }
    var railHovered by remember { mutableStateOf(false) }
    val expanded = pinnedExpanded || railHovered

    val railWidth by animateDpAsState(
        targetValue = if (expanded) 232.dp else 76.dp,
        animationSpec = tween(durationMillis = 180, easing = FastOutSlowInEasing),
        label = "railWidth",
    )

    val selectedRoute = when (current) {
        is AppRoute.Detail -> AppRoute.Home
        else -> current
    }
    val user = AppSession.user

    Column(
        Modifier
            .width(railWidth)
            .fillMaxHeight()
            .onPointerEvent(PointerEventType.Enter) { railHovered = true }
            .onPointerEvent(PointerEventType.Exit) { railHovered = false }
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(vertical = 12.dp),
    ) {
        // Header: centered mark when collapsed; logo + title + pin when open.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = if (expanded) Arrangement.Start else Arrangement.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = if (expanded) 12.dp else 0.dp, vertical = 8.dp),
        ) {
            // app_icon = installed-app mark (M only); maxstream_logo = wordmark splash.
            Image(
                painter = painterResource("app_icon.png"),
                contentDescription = "MaxStream",
                modifier = Modifier
                    .size(40.dp)
                    .clickable { pinnedExpanded = !pinnedExpanded },
            )
            if (expanded) {
                Spacer(Modifier.width(10.dp))
                Text(
                    "MaxStream",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                IconButton(
                    onClick = { pinnedExpanded = false },
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                        contentDescription = "Collapse sidebar",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        Spacer(Modifier.height(8.dp))

        items.forEach { item ->
            val selected = selectedRoute == item.route
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = if (expanded) Arrangement.Start else Arrangement.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 10.dp)
                    .background(
                        if (selected) MaterialTheme.colorScheme.primaryContainer
                        else Color.Transparent,
                        RoundedCornerShape(8.dp),
                    )
                    .clickable { onSelectRoot(item.route) }
                    .then(
                        if (expanded) Modifier.padding(horizontal = 12.dp, vertical = 10.dp)
                        else Modifier.padding(vertical = 12.dp),
                    ),
            ) {
                Icon(
                    item.icon,
                    contentDescription = item.label,
                    tint = if (selected) MaterialTheme.colorScheme.onPrimaryContainer
                           else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(22.dp),
                )
                if (expanded) {
                    Spacer(Modifier.width(12.dp))
                    Text(
                        item.label,
                        color = if (selected) MaterialTheme.colorScheme.onPrimaryContainer
                                else MaterialTheme.colorScheme.onSurface,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                        fontSize = 14.sp,
                        maxLines = 1,
                    )
                }
            }
        }

        Spacer(Modifier.weight(1f))

        // Footer: profile chip (centered when collapsed) + theme toggle when open
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = if (expanded) Arrangement.Start else Arrangement.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = if (expanded) 12.dp else 0.dp, vertical = 8.dp),
        ) {
            Box(
                Modifier
                    .size(30.dp)
                    .background(MaterialTheme.colorScheme.secondary, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.Person, null, tint = Color.White, modifier = Modifier.size(18.dp))
            }
            if (expanded) {
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
                        overflow = TextOverflow.Ellipsis,
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
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun TitleBar(
    route: AppRoute,
    canGoBack: Boolean,
    onBack: () -> Unit,
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
            .padding(horizontal = 8.dp),
    ) {
        if (canGoBack) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(start = if (canGoBack) 0.dp else 8.dp),
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
