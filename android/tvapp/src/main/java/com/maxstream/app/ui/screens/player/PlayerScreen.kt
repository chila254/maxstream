package com.maxstream.app.ui.screens.player

import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.navigation.NavController

@Composable
fun PlayerScreen(navController: NavController, sourceJson: String) {
    val context = LocalContext.current
    var exoPlayer by remember { mutableStateOf<ExoPlayer?>(null) }
    val source = try {
        com.google.gson.Gson().fromJson(java.net.URLDecoder.decode(sourceJson, "UTF-8"), com.maxstream.app.data.model.Source::class.java)
    } catch (e: Exception) { null }

    DisposableEffect(source?.url) {
        val player = ExoPlayer.Builder(context).build().apply {
            source?.url?.let { url ->
                setMediaItem(androidx.media3.common.MediaItem.fromUri(android.net.Uri.parse(url)))
                prepare()
                playWhenReady = true
            }
        }
        exoPlayer = player
        onDispose { player.release() }
    }

    AndroidView(factory = { ctx ->
        PlayerView(ctx).also { view ->
            view.player = exoPlayer
            view.useController = true
        }
    })
}
