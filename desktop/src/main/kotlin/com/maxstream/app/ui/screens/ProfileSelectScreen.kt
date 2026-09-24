package com.maxstream.app.ui.screens

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.maxstream.app.data.cloud.AppSession
import com.maxstream.app.data.cloud.CloudSync
import com.maxstream.app.data.cloud.ProfileStore
import com.maxstream.app.data.cloud.UserProfile
import com.maxstream.app.data.repository.TmdbRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** MaxStream avatar palette — same order as the mobile ProfileAvatar.palette. */
private val AvatarPalette = listOf(
    Color(0xFFE50914), Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF3B82F6),
    Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFFF97316), Color(0xFFA855F7),
)

private val AvatarIcons = listOf(
    Icons.Default.Person, Icons.Default.Movie, Icons.Default.Star, Icons.Default.Add,
)

private const val HeroCycleMs = 5_000L

private data class HeroSlide(
    val url: String,
    val title: String,
    val subtitle: String,
)

/**
 * Who's watching? — mirrors the mobile/TV profile gate: backdrop carousel,
 * centered title + profile grid, and add-profile tile. Selecting a profile
 * activates it, syncs cloud data for that profile, and continues into the shell.
 */
@Composable
fun ProfileSelectScreen(onSelected: () -> Unit) {
    var loading by remember { mutableStateOf(true) }
    val scope = rememberCoroutineScope()
    var heroes by remember { mutableStateOf<List<HeroSlide>>(emptyList()) }
    var heroIndex by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        ProfileStore.refresh()
        loading = false
    }

    LaunchedEffect(Unit) {
        heroes = runCatching {
            val sections = TmdbRepository.homeSections()
            val picked = (sections.firstOrNull { it.title.contains("Trending movies", true) }?.items.orEmpty() +
                sections.firstOrNull { it.title.contains("Trending series", true) }?.items.orEmpty())
                .filter { it.backdropUrl != null }
                .shuffled()
                .take(12)
            picked.map { item ->
                HeroSlide(
                    url = item.backdropUrl.orEmpty(),
                    title = item.title,
                    subtitle = listOf(item.typeLabel, item.displayYear)
                        .filter { it.isNotBlank() }
                        .joinToString("  •  "),
                )
            }.filter { it.url.isNotBlank() }
        }.getOrDefault(emptyList())
    }

    LaunchedEffect(heroes.size) {
        if (heroes.size < 2) return@LaunchedEffect
        while (isActive) {
            delay(HeroCycleMs)
            heroIndex = (heroIndex + 1) % heroes.size
        }
    }

    val currentHero = heroes.getOrNull(heroIndex)

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black),
    ) {
        if (currentHero != null) {
            Crossfade(
                targetState = currentHero,
                animationSpec = tween(800),
                label = "profileHero",
                modifier = Modifier.fillMaxSize(),
            ) { slide ->
                AsyncImage(
                    model = slide.url,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    listOf(
                        Color.Black.copy(alpha = 0.72f),
                        Color.Black.copy(alpha = 0.88f),
                        Color.Black,
                    ),
                ),
            ),
        )

        Column(
            Modifier.fillMaxSize().padding(horizontal = 48.dp, vertical = 36.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Image(
                painter = painterResource("maxstream_logo.png"),
                contentDescription = "MaxStream",
                modifier = Modifier.height(64.dp),
            )
            Spacer(Modifier.height(18.dp))
            Text(
                "Who's watching?",
                color = Color.White,
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "Choose a profile to start streaming",
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 14.sp,
                textAlign = TextAlign.Center,
            )

            Spacer(Modifier.weight(1f))

            if (loading) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
            } else {
                val profiles = ProfileStore.profiles
                val tiles = buildList {
                    profiles.forEach { add(Tile.ProfileTile(it)) }
                    if (profiles.size < ProfileStore.MAX_PROFILES) add(Tile.Add)
                }
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    tiles.chunked(3).forEach { row ->
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(28.dp, Alignment.CenterHorizontally),
                            modifier = Modifier.fillMaxWidth().padding(bottom = 24.dp),
                        ) {
                            row.forEach { tile ->
                                when (tile) {
                                    is Tile.ProfileTile -> ProfileTile(
                                        profile = tile.profile,
                                        onClick = {
                                            ProfileStore.setActive(tile.profile.id)
                                            scope.launch {
                                                if (AppSession.isSignedIn) {
                                                    CloudSync.syncWatchHistory()
                                                    CloudSync.bump()
                                                }
                                                onSelected()
                                            }
                                        },
                                    )
                                    Tile.Add -> AddProfileTile(
                                        onClick = {
                                            scope.launch {
                                                ProfileStore.create(
                                                    name = "Profile ${profiles.size + 1}",
                                                    colorIndex = profiles.size % AvatarPalette.size,
                                                    iconCodePoint = 0xe4ff,
                                                )
                                            }
                                        },
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(Modifier.weight(1f))

                val slide = currentHero
                if (slide != null) {
                    Text(
                        slide.title,
                        color = Color.White,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(0.7f),
                    )
                    if (slide.subtitle.isNotBlank()) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            slide.subtitle,
                            color = Color.White.copy(alpha = 0.65f),
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center,
                        )
                    }
                    Spacer(Modifier.height(14.dp))
                }
                Text(
                    "Click a profile to start watching",
                    color = Color.White.copy(alpha = 0.45f),
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

private sealed interface Tile {
    data class ProfileTile(val profile: UserProfile) : Tile
    data object Add : Tile
}

@Composable
private fun ProfileTile(profile: UserProfile, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val hovered by interaction.collectIsHoveredAsState()
    val color = AvatarPalette[profile.colorIndex.mod(AvatarPalette.size)]
    val icon = AvatarIcons[0]

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .width(130.dp)
            .scale(if (hovered) 1.05f else 1f)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
    ) {
        Box(
            Modifier
                .size(96.dp)
                .clip(CircleShape)
                .background(color)
                .border(
                    3.dp,
                    if (hovered) Color.White else color.copy(alpha = 0.9f),
                    CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = profile.name, tint = Color.White, modifier = Modifier.size(42.dp))
        }
        Spacer(Modifier.height(10.dp))
        Text(
            profile.name,
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
        )
        if (profile.isKids) {
            Spacer(Modifier.height(4.dp))
            Text(
                "KIDS",
                color = Color(0xFF10B981),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .background(Color(0xFF10B981).copy(alpha = 0.18f), RoundedCornerShape(4.dp))
                    .padding(horizontal = 8.dp, vertical = 2.dp),
            )
        }
    }
}

@Composable
private fun AddProfileTile(onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val hovered by interaction.collectIsHoveredAsState()

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .width(130.dp)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
    ) {
        Box(
            Modifier
                .size(96.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.06f))
                .border(2.dp, Color.White.copy(alpha = if (hovered) 0.55f else 0.25f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Default.Add,
                contentDescription = "Add profile",
                tint = Color.White.copy(alpha = 0.55f),
                modifier = Modifier.size(40.dp),
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(
            "Add Profile",
            color = Color.White.copy(alpha = 0.5f),
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
        )
    }
}
