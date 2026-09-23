package com.maxstream.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.Logout
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.cloud.AppSession
import kotlinx.coroutines.launch

/**
 * Desktop settings: account (Firebase sign-in / sign-out + cloud sync status),
 * appearance, and local streaming preferences — the same surface the mobile and
 * TV settings cover.
 */
@Composable
fun SettingsScreen(
    useDarkTheme: Boolean,
    onThemeChange: (Boolean) -> Unit,
) {
    var quality by remember { mutableStateOf("Auto (1080p)") }
    var storageCap by remember { mutableFloatStateOf(4f) }

    Column(Modifier.fillMaxSize().padding(24.dp).verticalScroll(rememberScrollState())) {
        Text(
            "Settings",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(Modifier.height(20.dp))

        SettingRow("Account & cloud sync") {
            AccountCard()
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

/** Sign in / sign up / sign out with cloud sync status. */
@Composable
private fun AccountCard() {
    val scope = rememberCoroutineScope()
    val user = AppSession.user
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    if (user != null) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    if (AppSession.isSignedIn) Icons.Default.CloudDone else Icons.Default.Cloud,
                    null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.width(20.dp),
                )
                Spacer(Modifier.width(10.dp))
                Column {
                    Text(
                        user.email,
                        color = MaterialTheme.colorScheme.onSurface,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                    Text(
                        "Watchlist & progress sync to Firebase",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 12.sp,
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            OutlinedButton(onClick = {
                busy = true
                scope.launch {
                    AppSession.signOut()
                    busy = false
                }
            }) {
                Icon(Icons.Default.Logout, null, modifier = Modifier.width(16.dp))
                Spacer(Modifier.width(6.dp))
                Text("Sign out")
            }
        }
        return
    }

    Column {
        Text(
            "Sign in with your MaxStream account so your watchlist and progress follow you across devices.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 13.sp,
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        if (error != null) {
            Spacer(Modifier.height(8.dp))
            Text(error.orEmpty(), color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
        }
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(10.dp)) {
            Button(
                enabled = !busy,
                onClick = {
                    busy = true; error = null
                    scope.launch {
                        AppSession.signIn(email, password)
                            .onFailure { error = it.message ?: "Sign-in failed." }
                        busy = false
                    }
                },
            ) {
                if (busy) {
                    CircularProgressIndicator(Modifier.width(16.dp).height(16.dp), strokeWidth = 2.dp)
                } else {
                    Icon(Icons.Default.Person, null, modifier = Modifier.width(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Sign in")
                }
            }
            OutlinedButton(
                enabled = !busy,
                onClick = {
                    busy = true; error = null
                    scope.launch {
                        AppSession.signUp(email, password)
                            .onFailure { error = it.message ?: "Sign-up failed." }
                        busy = false
                    }
                },
            ) {
                Text("Create account")
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            "New to MaxStream? Create an account with the same details you use on the phone or TV app.",
            color = MaterialTheme.colorScheme.outline,
            fontSize = 12.sp,
        )
    }
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
