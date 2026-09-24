package com.maxstream.app

import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import com.maxstream.app.data.cloud.AppSession
import com.maxstream.app.data.cloud.ProfileStore
import com.maxstream.app.player.VlcRuntime
import com.maxstream.app.ui.Shell

fun main() = application {
    // Extract the bundled VLC runtime (once) before any player is created.
    runCatching { VlcRuntime.ensure() }
    AppSession.restore()
    ProfileStore.restoreLocal()
    Window(
        onCloseRequest = ::exitApplication,
        state = rememberWindowState(width = 1320.dp, height = 840.dp),
        title = "MaxStream",
    ) {
        Shell()
    }
}