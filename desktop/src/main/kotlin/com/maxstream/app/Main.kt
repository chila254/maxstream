package com.maxstream.app

import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import com.maxstream.app.data.AppPrefs
import com.maxstream.app.data.cloud.AppSession
import com.maxstream.app.data.cloud.ProfileStore
import com.maxstream.app.player.VlcRuntime
import com.maxstream.app.ui.Shell

fun main() {
    // One-time bootstrap, strictly before the first composition. Running these
    // inside application { } would re-execute them on every recomposition
    // (re-reading AppSession could clobber an in-flight token refresh).
    runCatching { VlcRuntime.ensure() }
        .onFailure { e -> System.err.println("VLC runtime init failed (playback will not start): $e") }
    runCatching { AppSession.restore() }
        .onFailure { e -> System.err.println("Session restore failed (signed out): $e") }
    runCatching { ProfileStore.restoreLocal() }
        .onFailure { e -> System.err.println("Profile restore failed: $e") }
    runCatching { AppPrefs.restore() }
        .onFailure { e -> System.err.println("Prefs restore failed (defaults used): $e") }

    application {
        val windowState = rememberWindowState(width = 1320.dp, height = 840.dp)
        Window(
            onCloseRequest = ::exitApplication,
            state = windowState,
            title = "MaxStream",
        ) {
            Shell(windowState = windowState)
        }
    }
}
