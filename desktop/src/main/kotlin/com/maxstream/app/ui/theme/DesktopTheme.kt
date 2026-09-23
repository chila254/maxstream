package com.maxstream.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Windows-accent blues (distinct from the TV app's Netflix red and the phone's
// plain dark theme). Light mode is the desktop default; dark follows the OS.
private val LightColors = lightColorScheme(
    primary = Color(0xFF0067C0),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD3E4FF),
    onPrimaryContainer = Color(0xFF001C3E),
    secondary = Color(0xFF0D7A78),
    surface = Color(0xFFF7F9FC),
    surfaceVariant = Color(0xFFE9EDF2),
    onSurface = Color(0xFF1A1C1E),
    outline = Color(0xFF74777F),
    outlineVariant = Color(0xFFC4C7CE),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF9BC8FF),
    onPrimary = Color(0xFF00325C),
    primaryContainer = Color(0xFF00497D),
    onPrimaryContainer = Color(0xFFD3E4FF),
    secondary = Color(0xFF4FD1CD),
    surface = Color(0xFF111417),
    surfaceVariant = Color(0xFF23272C),
    onSurface = Color(0xFFE1E2E6),
    outline = Color(0xFF8A8F98),
    outlineVariant = Color(0xFF444850),
)

@Composable
fun DesktopTheme(
    useDarkTheme: Boolean,
    content: @Composable () -> Unit,
) {
    val dark = useDarkTheme || isSystemInDarkTheme()
    MaterialTheme(
        colorScheme = if (dark) DarkColors else LightColors,
        content = content,
    )
}