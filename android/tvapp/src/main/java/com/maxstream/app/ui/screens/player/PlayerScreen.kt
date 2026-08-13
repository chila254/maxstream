package com.maxstream.app.ui.screens.player

import android.view.View
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.navigation.NavController
import com.maxstream.app.di.Modules
import kotlinx.coroutines.launch

@Composable
fun PlayerScreen(navController: NavController, itemId: String, mediaType: String) {
    val context = LocalContext.current
    var exoPlayer by remember { mutableStateOf<ExoPlayer?>(null) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    val coroutineScope = rememberCoroutineScope()

    DisposableEffect(itemId, mediaType) {
        loading = true
        error = null
        coroutineScope.launch {
            try {
                val isMovie = mediaType == "movie"
                val source = Modules.streamRepository(context).resolve(
                    tmdbId = itemId,
                    isMovie = isMovie,
                    season = 1,
                    episode = 1,
                    title = ""
                )
                if (source != null) {
                    val player = ExoPlayer.Builder(context).build().apply {
                        setMediaItem(androidx.media3.common.MediaItem.fromUri(android.net.Uri.parse(source.url)))
                        prepare()
                        playWhenReady = true
                    }
                    exoPlayer = player
                } else {
                    error = "No stream found"
                }
            } catch (e: Exception) {
                error = e.message
            } finally {
                loading = false
            }
        }

        onDispose {
            exoPlayer?.release()
            exoPlayer = null
        }
    }

    if (loading) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(com.maxstream.app.ui.theme.Background),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = com.maxstream.app.ui.theme.Primary)
        }
    } else if (error != null) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(com.maxstream.app.ui.theme.Background),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(text = "Error: $error", color = Color(0xFFCF6679))
                Spacer(modifier = Modifier.height(16.dp))
                Button(onClick = { navController.popBackStack() }) {
                    Text("Back")
                }
            }
        }
    } else {
        AndroidView(factory = { ctx ->
            PlayerView(ctx).also { view ->
                view.player = exoPlayer
                view.useController = true
            }
        })
    }
}
