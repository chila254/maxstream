package com.maxstream.app.player

import uk.co.caprica.vlcj.player.component.EmbeddedMediaPlayerComponent

/**
 * Thin wrapper around the vlcj 4.x embedded player so the UI layer never touches
 * libVLC types directly. All methods must be called from the AWT/UI thread.
 */
class PlayerController(remembered: EmbeddedMediaPlayerComponent = EmbeddedMediaPlayerComponent()) {

    val component: EmbeddedMediaPlayerComponent = remembered

    init {
        // Keep AWT/VLC surfaces from stealing Compose keyboard focus so the
        // overlay can receive Space/Backspace/F/Esc while video plays.
        runCatching {
            fun unfocus(c: java.awt.Component) {
                c.isFocusable = false
                if (c is java.awt.Container) {
                    c.components.forEach { unfocus(it) }
                }
            }
            unfocus(component)
        }
    }

    fun play(url: String, referer: String?, userAgent: String?, origin: String?) {
        val opts = mutableListOf<String>()
        if (!referer.isNullOrBlank()) opts.add(":http-referrer=$referer")
        if (!userAgent.isNullOrBlank()) opts.add(":http-user-agent=$userAgent")
        if (!origin.isNullOrBlank()) opts.add(":http-origin=$origin")
        component.mediaPlayer().media().play(url, *opts.toTypedArray())
    }

    val isPlaying: Boolean
        get() = component.mediaPlayer().status().isPlaying

    fun time(): Long = component.mediaPlayer().status().time()
    fun length(): Long = component.mediaPlayer().status().length()

    fun playControl() = component.mediaPlayer().controls().play()
    fun pause() = component.mediaPlayer().controls().pause()
    fun stop() = component.mediaPlayer().controls().stop()
    fun setTime(ms: Long) = component.mediaPlayer().controls().setTime(ms)
    fun setPosition(frac: Float) = component.mediaPlayer().controls().setPosition(frac)

    fun setVolume(pct: Int) = component.mediaPlayer().audio().setVolume(pct.coerceIn(0, 100))
    fun setMute(muted: Boolean) = component.mediaPlayer().audio().setMute(muted)

    /** Audio ES tracks VLC currently exposes (id + display name), or empty. */
    fun audioTrackDescriptions(): List<Pair<Int, String>> = runCatching {
        component.mediaPlayer().audio().trackDescriptions().map { it.id() to it.description() }
    }.getOrDefault(emptyList())

    /** Currently selected audio track id (-1/0 = automatic/default). */
    fun currentAudioTrack(): Int = runCatching {
        component.mediaPlayer().audio().track()
    }.getOrDefault(-1)

    /** Selects an audio track by VLC id; no-op when unknown. */
    fun selectAudioTrack(id: Int) {
        runCatching { component.mediaPlayer().audio().setTrack(id) }
    }

    fun setSubtitleFile(path: String) {
        runCatching { component.mediaPlayer().subpictures().setSubTitleFile(java.io.File(path)) }
    }

    /** Turns subtitles off by selecting the "Disabled" SPU track (id -1 / description). */
    fun disableSubtitles() {
        runCatching {
            val api = component.mediaPlayer().subpictures()
            val disabled = api.trackDescriptions().firstOrNull { t ->
                t.description()?.equals("Disabled", ignoreCase = true) == true ||
                    t.description()?.equals("Disable", ignoreCase = true) == true
            }
            api.setTrack(disabled?.id() ?: -1)
        }
    }

    fun togglePlayPause() {
        if (isPlaying) pause() else playControl()
    }

    fun release() {
        runCatching { stop() }
        runCatching { component.release() }
    }
}
