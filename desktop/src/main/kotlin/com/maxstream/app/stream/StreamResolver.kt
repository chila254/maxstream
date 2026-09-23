package com.maxstream.app.stream

import android.content.Context
import com.maxstream.app.StreamExtractor

/**
 * The desktop client's view of the shared stream extractor. Everything here is
 * plain JVM code: the Android API surface used by the TV extractor is absorbed
 * by the compatibility shim under desktop/src/.../android so the extractor,
 * goodstream handler and salsa crypto all run unchanged on Windows.
 *
 * Note: the desktop JVM has no embedded browser engine, so WebView-based
 * extractors are reported as low-RAM and skipped (same guard as cheap TV
 * boxes). HTTP-based extractors (VidLink via the worker + XSalsa20 secretbox,
 * VixSrc, Vidsrc, Streamtape, Filemoon, MixDrop, generic media, Worker, …)
 * resolve streams normally.
 */
object DesktopContext : Context

object StreamResolver {
    private val tvExtractor = StreamExtractor(DesktopContext)

    /** Quick "first playable server wins" resolution, mirroring the TV player. */
    suspend fun resolve(
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1,
        title: String = "",
    ): Map<String, Any>? =
        tvExtractor.resolveStream(tmdbId, isMovie, season, episode, title)

    /** Full multi-server resolution for the player's server picker. */
    suspend fun resolveAll(
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1,
        title: String = "",
    ): List<Map<String, Any>> =
        tvExtractor.resolveStreams(tmdbId, isMovie, season, episode, title)
}