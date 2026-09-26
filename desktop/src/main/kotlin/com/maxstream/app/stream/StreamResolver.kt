package com.maxstream.app.stream

import android.content.Context
import com.maxstream.app.StreamExtractor

/**
 * The desktop client's view of the shared stream extractor. Everything here is
 * plain JVM code: the Android API surface used by the TV extractor is absorbed
 * by the compatibility shim under desktop/src/.../android so the extractor and
 * salsa crypto all run unchanged on Windows.
 *
 * Note: the desktop JVM has no embedded browser engine, so WebView-based
 * extractors are reported as low-RAM and skipped (same guard as cheap TV
 * boxes). HTTP-based extractors (VidLink via the worker + XSalsa20 secretbox,
 * VixSrc, Vidsrc, Streamtape, Filemoon, MixDrop, generic media, Worker, …)
 * resolve streams normally.
 */
object DesktopContext : Context

object StreamResolver {
    private val extractor = StreamExtractor(DesktopContext)

    /** Quick "first playable server wins" resolution — the playback fast path. */
    suspend fun resolve(
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1,
        title: String = "",
    ): Map<String, Any>? =
        extractor.resolveStream(tmdbId, isMovie, season, episode, title)

    /**
     * Multi-server resolution for the player's server picker. [fast] uses the
     * short per-server budgets + light HLS validation so the picker paints in
     * seconds; the caller follows up with a full pass to harden the list.
     */
    suspend fun resolveAll(
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1,
        title: String = "",
        fast: Boolean = false,
    ): List<Map<String, Any>> =
        extractor.resolveStreams(tmdbId, isMovie, season, episode, title, fast)

    /** Re-fetches one named server (picker rows that failed discovery). */
    suspend fun resolveServer(
        name: String,
        tmdbId: String,
        isMovie: Boolean,
        season: Int = 1,
        episode: Int = 1,
        title: String = "",
    ): Map<String, Any>? =
        extractor.resolveServer(name, tmdbId, isMovie, season, episode, title)
}
