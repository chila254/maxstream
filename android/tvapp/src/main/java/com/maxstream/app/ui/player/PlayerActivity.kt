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
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.MediaCodecSelector
import androidx.media3.exoplayer.RenderersFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.trackselection.TrackSelectionParameters
import androidx.media3.ui.PlayerView
import com.maxstream.app.R
import com.maxstream.app.data.model.Source
import com.maxstream.app.data.model.Subtitle

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
    private var usedSoftwareDecoder = false

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

        val trackSelector = DefaultTrackSelector(this).apply {
            val params = TrackSelectionParameters.Builder(this@PlayerActivity)
                .setPreferredVideoMimeTypes("video/avc", "video/hevc", "video/av1", "video/vp9")
                .setMaxVideoSize(1920, 1080)
                .setExceedVideoConstraintsIfNecessary(true)
                .build()
            setParameters(params)
        }

        val renderersFactory: RenderersFactory = DefaultRenderersFactory(this).apply {
            setEnableDecoderFallback(true)
            if (usedSoftwareDecoder) setMediaCodecSelector(softwareDecoderSelector())
        }

        val httpDataSourceFactory = DefaultHttpDataSource.Factory().apply {
            setUserAgent("Mozilla/5.0 (Linux; Android TV)")
            if (source.headers.isNotEmpty()) setDefaultRequestProperties(source.headers)
        }
        val mediaSourceFactory = DefaultMediaSourceFactory(this@PlayerActivity, httpDataSourceFactory)

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(30_000, 90_000, 3_000, 6_000)
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()

        player = ExoPlayer.Builder(this@PlayerActivity)
            .setRenderersFactory(renderersFactory)
            .setTrackSelector(trackSelector)
            .setMediaSourceFactory(mediaSourceFactory)
            .setLoadControl(loadControl)
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

    private fun mimeFor(subtitle: Subtitle): String =
        if (subtitle.url.endsWith(".vtt", ignoreCase = true)) "text/vtt" else "application/x-subrip"

    private val playerListener = object : androidx.media3.common.Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            if (state == androidx.media3.common.Player.STATE_READY) loading.visibility = View.GONE
        }

        override fun onPlayerError(error: PlaybackException) {
            loading.visibility = View.GONE
            val isDecoderIssue = error.errorCode == PlaybackException.ERROR_CODE_DECODER_INIT_FAILED ||
                error.errorCode == PlaybackException.ERROR_CODE_DECODING_FAILED ||
                error.errorCode == PlaybackException.ERROR_CODE_AUDIO_TRACK_INIT_FAILED
            if (isDecoderIssue && !usedSoftwareDecoder) {
                usedSoftwareDecoder = true
                player?.release()
                player = null
                buildPlayer()
            } else {
                errorView.text = "Playback error: ${error.errorCodeName}\n${error.message}"
                errorView.visibility = View.VISIBLE
            }
        }
    }

    private fun softwareDecoderSelector(): MediaCodecSelector {
        return MediaCodecSelector { mimeType, requiresSecureDecoder, requiresTunnelingDecoder ->
            androidx.media3.common.util.MediaCodecUtil
                .getDecoderInfos(mimeType, requiresSecureDecoder, requiresTunnelingDecoder)
                .sortedBy { info ->
                    when {
                        info.name.startsWith("OMX.google.") -> 0
                        info.name.startsWith("c2.android.") -> 1
                        else -> 2
                    }
                }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        player?.release()
        player = null
    }
}
