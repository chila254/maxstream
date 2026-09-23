package com.maxstream.app.player

import uk.co.caprica.vlcj.player.component.EmbeddedMediaPlayerComponent

/**
 * Thin wrapper around the vlcj 4.x embedded player so the UI layer never touches
 * libVLC types directly. All methods must be called from the AWT/UI thread.
 */
class PlayerController(remembered: EmbeddedMediaPlayerComponent = EmbeddedMediaPlayerComponent()) {

    val component: EmbeddedMediaPlayerComponent = remembered

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

    fun setSubtitleFile(path: String) {
        runCatching { component.mediaPlayer().subpictures().setSubTitleFile(java.io.File(path)) }
    }

    fun togglePlayPause() {
        if (isPlaying) pause() else playControl()
    }

    fun release() {
        runCatching { stop() }
        runCatching { component.release() }
    }
}