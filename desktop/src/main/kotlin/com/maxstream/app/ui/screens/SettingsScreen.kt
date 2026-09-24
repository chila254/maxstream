package com.maxstream.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.cloud.AppSession
import com.maxstream.app.ui.components.ScrollableColumn

/**
 * Desktop settings: appearance + local streaming preferences. Sign-in/out lives
 * on the launch auth screen (matching mobile), not here.
 */
@Composable
fun SettingsScreen(
    useDarkTheme: Boolean,
    onThemeChange: (Boolean) -> Unit,
) {
    var quality by remember { mutableStateOf("Auto (1080p)") }
    var storageCap by remember { mutableFloatStateOf(4f) }

    ScrollableColumn(contentPadding = PaddingValues(24.dp)) {
        Text(
            "Settings",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(Modifier.height(20.dp))

        SettingRow("Account") {
            AccountStatus()
        }

        Spacer(Modifier.height(16.dp))

        SettingRow("Appearance") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    if (useDarkTheme) Icons.Default.DarkMode else Icons.Default.LightMode,
                    null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.width(20.dp),
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    "Dark theme",
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.width(200.dp),
                )
                Switch(checked = useDarkTheme, onCheckedChange = onThemeChange)
            }
        }

        Spacer(Modifier.height(16.dp))

        SettingRow("Streaming") {
            var menuOpen by remember { mutableStateOf(false) }
            Column {
                Text(
                    "Default quality",
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.width(200.dp),
                )
                Spacer(Modifier.height(6.dp))
                OutlinedButton(onClick = { menuOpen = true }) {
                    Text(quality, color = MaterialTheme.colorScheme.onSurface)
                }
                DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                    listOf("Auto (1080p)", "720p", "1080p", "4K").forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option, color = MaterialTheme.colorScheme.onSurface) },
                            onClick = { quality = option; menuOpen = false },
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        SettingRow("Storage") {
            Column(Modifier.fillMaxWidth()) {
                Text(
                    "Offline cache cap: ${storageCap.toInt()} GB",
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Slider(
                    value = storageCap,
                    onValueChange = { storageCap = it },
                    valueRange = 1f..16f,
                )
            }
        }
    }
}

/** Read-only signed-in status — auth UI lives on the launch screens. */
@Composable
private fun AccountStatus() {
    val user = AppSession.user
    val profile = com.maxstream.app.data.cloud.ProfileStore.activeProfile

    if (user != null) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Default.CloudDone,
                null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.width(20.dp),
            )
            Spacer(Modifier.width(10.dp))
            Column {
                Text(
                    profile?.name ?: user.email,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
                Text(
                    if (profile != null && profile.name != user.email) user.email
                    else "Watchlist & progress sync to Firebase",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = 12.sp,
                )
            }
        }
        return
    }

    Text(
        "Sign in from the launch screen to sync your watchlist and progress across devices.",
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        fontSize = 13.sp,
    )
}

@Composable
private fun SettingRow(
    title: String,
    content: @Composable () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(10.dp))
            .padding(16.dp),
    ) {
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(Modifier.height(12.dp))
        content()
    }
}
