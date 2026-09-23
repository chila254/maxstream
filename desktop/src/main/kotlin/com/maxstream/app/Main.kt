package com.maxstream.app

import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import com.maxstream.app.data.cloud.AppSession
import com.maxstream.app.ui.Shell

fun main() = application {
    AppSession.restore()
    Window(
        onCloseRequest = ::exitApplication,
        state = rememberWindowState(width = 1320.dp, height = 840.dp),
        title = "MaxStream",
    ) {
        Shell()
    }
}