package com.maxstream.app.ui.screens.profile

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Brush
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.RocketLaunch
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.maxstream.app.core.Constants
import com.maxstream.app.data.local.ProfileData
import com.maxstream.app.data.local.ProfileScope
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.remote.TmdbApi
import com.maxstream.app.data.repository.ProfileRepository
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.theme.Primary

private const val HERO_CYCLE_MS = 5000L
private const val HERO_CROSSFADE_MS = 800

/**
 * TV profile selection screen — Netflix-style with auto-rotating hero background
 * showing trending movies and series. Profile cards overlay on top with a dark
 * gradient. Auto-skips if only one profile exists.
 */
@Composable
fun ProfileSelectScreen(
    onProfileSelected: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val tmdb = remember { TmdbApi() }

    var profiles by remember { mutableStateOf(emptyList<ProfileData>()) }
    var isLoading by remember { mutableStateOf(true) }
    var focusedIndex by remember { mutableIntStateOf(-1) }
    var deleteTarget by remember { mutableStateOf<ProfileData?>(null) }

    // Hero carousel state
    var heroItems by remember { mutableStateOf(emptyList<MediaItem>()) }
    var heroIndex by remember { mutableIntStateOf(0) }
    var heroVisible by remember { mutableStateOf(true) }

    // Load profiles from cloud
    LaunchedEffect(Unit) {
        val cloudProfiles = ProfileRepository.pullProfiles(context)
        profiles = cloudProfiles

        // Auto-select if single profile
        if (cloudProfiles.size == 1) {
            ProfileScope.setActiveProfileId(context, cloudProfiles.first().id)
            onProfileSelected()
            return@LaunchedEffect
        }

        // Auto-select if only cached profile
        if (ProfileScope.autoSelectIfSingle(context)) {
            onProfileSelected()
            return@LaunchedEffect
        }

        isLoading = false
    }

    // Fetch hero content in background
    LaunchedEffect(Unit) {
        try {
            val trending = tmdb.trendingMovies()
            val onAir = tmdb.onTheAirSeries()
            val combined = (trending + onAir)
                .filter { !it.backdropPath.isNullOrBlank() }
                .shuffled()
                .take(10)
            heroItems = combined
        } catch (_: Exception) {}
    }

    // Auto-cycle hero items
    LaunchedEffect(heroItems.size) {
        if (heroItems.size < 2) return@LaunchedEffect
        while (true) {
            delay(HERO_CYCLE_MS)
            // Crossfade: fade out, swap, fade in
            heroVisible = false
            delay(HERO_CROSSFADE_MS.toLong())
            heroIndex = (heroIndex + 1) % heroItems.size
            heroVisible = true
        }
    }

    val heroAlpha by animateFloatAsState(
        targetValue = if (heroVisible) 1f else 0f,
        animationSpec = tween(durationMillis = HERO_CROSSFADE_MS, easing = LinearEasing),
        label = "hero_fade",
    )

    Box(
        modifier = Modifier.fillMaxSize().background(Color.Black),
    ) {
        // Hero background image
        if (heroItems.isNotEmpty()) {
            val item = heroItems[heroIndex % heroItems.size]
            val backdropUrl = "${Constants.TMDB_IMAGE_BASE}/w1280${item.backdropPath}"
            AsyncImage(
                model = backdropUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .alpha(heroAlpha),
            )
        }

        // Dark gradient overlay for readability
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Black.copy(alpha = 0.3f),
                            Color.Black.copy(alpha = 0.7f),
                            Color.Black.copy(alpha = 0.95f),
                        ),
                    ),
                ),
        )

        // Content on top
        if (isLoading) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.Center,
            ) {
                CircularProgressIndicator(color = Primary, strokeWidth = 3.dp)
                Spacer(Modifier.height(16.dp))
                Text(
                    "Loading profiles...",
                    color = Color.White.copy(alpha = 0.6f),
                    fontSize = 16.sp,
                )
            }
        } else {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 60.dp),
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = "Who's watching?",
                    color = Color.White,
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Bold,
                )

                Spacer(Modifier.height(48.dp))

                // Profile grid — 3 columns max, D-pad navigable
                val columns = profiles.size.coerceAtMost(3).coerceAtLeast(1)
                val rows = if (profiles.isEmpty()) 0 else (profiles.size + columns - 1) / columns

                for (row in 0 until rows) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(32.dp, Alignment.CenterHorizontally),
                        modifier = Modifier.padding(bottom = 24.dp),
                    ) {
                        for (col in 0 until columns) {
                            val index = row * columns + col
                            if (index < profiles.size) {
                                ProfileCard(
                                    profile = profiles[index],
                                    isFocused = focusedIndex == index,
                                    onFocused = { focusedIndex = index },
                                    onClick = {
                                        ProfileScope.setActiveProfileId(context, profiles[index].id)
                                        onProfileSelected()
                                    },
                                    onDelete = { deleteTarget = profiles[index] },
                                )
                            } else {
                                Spacer(Modifier.size(120.dp))
                            }
                        }
                    }
                }

                Spacer(Modifier.height(24.dp))

                Text(
                    text = "Press OK to select a profile",
                    color = Color.White.copy(alpha = 0.4f),
                    fontSize = 14.sp,
                )
            }
        }
    }

    // Delete confirmation dialog
    deleteTarget?.let { target ->
        AlertDialog(
            onDismissRequest = { deleteTarget = null },
            title = { Text("Delete ${target.name}?", color = Color.White) },
            text = { Text("This will remove the profile and its watch progress.", color = Color.White.copy(alpha = 0.7f)) },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        ProfileRepository.deleteProfile(context, target.id)
                        profiles = ProfileScope.getCachedProfiles(context)
                        deleteTarget = null
                    }
                }) {
                    Text("Delete", color = Color(0xFFE50914))
                }
            },
            dismissButton = {
                TextButton(onClick = { deleteTarget = null }) {
                    Text("Cancel", color = Color.White)
                }
            },
            containerColor = Color(0xFF1C1C1E),
        )
    }
}

@Composable
private fun ProfileCard(
    profile: ProfileData,
    isFocused: Boolean,
    onFocused: () -> Unit,
    onClick: () -> Unit,
    onDelete: () -> Unit = {},
) {
    val focusRequester = remember { FocusRequester() }
    val colors = ProfileColors[profile.colorIndex % ProfileColors.size]
    val icon = profileIconFor(profile.iconCodePoint)
    var showDeleteHint by remember { mutableStateOf(false) }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .focusRequester(focusRequester)
            .onFocusChanged {
                if (it.hasFocus) {
                    onFocused()
                    showDeleteHint = false
                }
            }
            .focusable()
            .onKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown) {
                    when (event.key) {
                        Key.DirectionCenter -> { onClick(); true }
                        Key.Menu -> { onDelete(); true }
                        else -> false
                    }
                } else false
            }
            .padding(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(100.dp)
                .clip(CircleShape)
                .background(colors)
                .border(
                    width = if (isFocused) 3.dp else 0.dp,
                    color = if (isFocused) Color.White else Color.Transparent,
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = profile.name,
                tint = Color.White,
                modifier = Modifier.size(44.dp),
            )
        }

        Spacer(Modifier.height(8.dp))

        Text(
            text = profile.name,
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = if (isFocused) FontWeight.Bold else FontWeight.Normal,
            textAlign = TextAlign.Center,
            maxLines = 1,
            modifier = Modifier.width(120.dp),
        )

        if (profile.isKids) {
            Spacer(Modifier.height(4.dp))
            Text(
                text = "KIDS",
                color = Color(0xFF10B981),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        if (isFocused) {
            Spacer(Modifier.height(4.dp))
            Text(
                text = "MENU to delete",
                color = Color.White.copy(alpha = 0.35f),
                fontSize = 10.sp,
            )
        }
    }
}

/** Material 3 color palette — matches Flutter ProfileAvatar.palette */
private val ProfileColors = listOf(
    Color(0xFFE50914), // Red
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFFEF4444), // Rose
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFFA855F7), // Purple
)

/** Map Flutter icon codePoints to Compose Material Icons (same icons, cross-platform). */
private fun profileIconFor(codePoint: Int): ImageVector = when (codePoint) {
    0xe4ff -> Icons.Filled.Person            // person
    0xe038 -> Icons.Filled.Movie             // movie
    0xe30f -> Icons.Filled.SportsEsports     // sports_esports
    0xe301 -> Icons.Filled.MusicNote         // music_note
    0xe838 -> Icons.Filled.Star              // star
    0xe558 -> Icons.Filled.RocketLaunch      // rocket_launch
    0xe06d -> Icons.Filled.AutoAwesome       // auto_awesome
    0xe91a -> Icons.Filled.Pets              // pets
    0xe3a8 -> Icons.Filled.Brush             // brush
    0xe0e3 -> Icons.Filled.Psychology        // psychology
    0xe0ca -> Icons.Filled.Public            // public
    0xe537 -> Icons.Filled.Bolt              // bolt
    else -> Icons.Filled.Person              // fallback
}
