package com.maxstream.app.ui.player

import android.os.Bundle
import android.view.View
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.maxstream.app.R
import com.maxstream.app.data.model.Source

@UnstableApi
class PlayerActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_SOURCE = "extra_source"
    }

    private lateinit var playerView: PlayerView
    private lateinit var loading: ProgressBar
    private lateinit var errorView: TextView
    private lateinit var titleView: TextView
    private lateinit var serverView: TextView

    private lateinit var source: Source
    private var player: ExoPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.tv_player)
        source = Source.fromBundle(intent.getBundleExtra(EXTRA_SOURCE)!!)

        playerView = findViewById(R.id.player_view)
        loading = findViewById(R.id.loading)
        errorView = findViewById(R.id.error)
        titleView = findViewById(R.id.title)
        serverView = findViewById(R.id.server)

        titleView.text = source.server.ifBlank { "MaxStream" }
        serverView.text = if (source.isHls) "HLS • ${source.url}" else source.url

        buildPlayer()
    }

    private fun buildPlayer() {
        loading.visibility = View.VISIBLE
        errorView.visibility = View.GONE

        player = ExoPlayer.Builder(this)
            .build()
            .also { exo ->
                exo.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(C.USAGE_MEDIA)
                        .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                        .build(),
                    true,
                )
                exo.setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT)
                exo.playWhenReady = true
                exo.setMediaItem(buildMediaItem())
                exo.addListener(playerListener)
                playerView.player = exo
                exo.prepare()
            }
    }

    private fun buildMediaItem(): MediaItem {
        val builder = MediaItem.Builder().setUri(source.url)
        if (source.subtitles.isNotEmpty()) {
            builder.setSubtitleConfigurations(
                source.subtitles.map { subtitle ->
                    MediaItem.SubtitleConfiguration.Builder(android.net.Uri.parse(subtitle.url))
                        .setMimeType(mimeFor(subtitle))
                        .setLanguage("en")
                        .setLabel(subtitle.label)
                        .build()
                },
            )
        }
        return builder.build()
    }

    private fun mimeFor(subtitle: com.maxstream.app.data.model.Subtitle): String =
        if (subtitle.url.endsWith(".vtt", ignoreCase = true)) "text/vtt" else "application/x-subrip"

    private val playerListener = object : androidx.media3.common.Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            if (state == androidx.media3.common.Player.STATE_READY) loading.visibility = View.GONE
        }

        override fun onPlayerError(error: PlaybackException) {
            loading.visibility = View.GONE
            errorView.text = "Playback error: ${error.errorCodeName}\n${error.message}"
            errorView.visibility = View.VISIBLE
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        player?.release()
        player = null
    }
}
