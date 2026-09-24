package com.maxstream.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// MaxStream brand palette — matches the TV app (Netflix-red primary, white
// on-primary) so the desktop client feels like the same product. Dark is the
// signature look; light keeps readable surfaces for the Settings toggle.
private val MaxRed = Color(0xFFE50914)
private val MaxRedDark = Color(0xFFB00710)
private val MaxCoral = Color(0xFFFF5A5F)

private val LightColors = lightColorScheme(
    primary = MaxRed,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFDAD6),
    onPrimaryContainer = Color(0xFF410002),
    secondary = MaxCoral,
    onSecondary = Color.Black,
    secondaryContainer = Color(0xFFFFDAD6),
    onSecondaryContainer = Color(0xFF410002),
    tertiary = Color(0xFF7A5900),
    background = Color(0xFFFFFBFF),
    onBackground = Color(0xFF201A1A),
    surface = Color(0xFFFFFBFF),
    onSurface = Color(0xFF201A1A),
    surfaceVariant = Color(0xFFF5DDDA),
    onSurfaceVariant = Color(0xFF534341),
    outline = Color(0xFF857370),
    outlineVariant = Color(0xFFD8C2BF),
    error = Color(0xFFCF6679),
)

private val DarkColors = darkColorScheme(
    primary = MaxRed,
    onPrimary = Color.White,
    primaryContainer = MaxRedDark,
    onPrimaryContainer = Color(0xFFFFDAD6),
    secondary = MaxCoral,
    onSecondary = Color.Black,
    secondaryContainer = Color(0xFF8C3D3F),
    onSecondaryContainer = Color(0xFFFFDAD6),
    tertiary = Color(0xFFF5C242),
    background = Color(0xFF0D0D0F),
    onBackground = Color(0xFFFFFFFF),
    surface = Color(0xFF1A1A1E),
    onSurface = Color.White,
    surfaceVariant = Color(0xFF1E1E1E),
    onSurfaceVariant = Color(0xFFB3B3B3),
    outline = Color(0xFF74777F),
    outlineVariant = Color(0xFF444850),
    error = Color(0xFFCF6679),
)

@Composable
fun DesktopTheme(
    useDarkTheme: Boolean,
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (useDarkTheme) DarkColors else LightColors,
        content = content,
    )
}
