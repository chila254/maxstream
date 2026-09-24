package com.maxstream.app.data.repository

import com.maxstream.app.data.model.ContinueWatch
import com.maxstream.app.data.model.Episode
import com.maxstream.app.data.model.HomeSection
import com.maxstream.app.data.model.MediaDetails
import com.maxstream.app.data.model.MediaItem

/** Catalog sections available on the Movies screen. */
enum class MovieSection(val display: String, val endpoint: String) {
    POPULAR("Popular", "/movie/popular"),
    TOP_RATED("Top rated", "/movie/top_rated"),
    UPCOMING("Upcoming", "/movie/upcoming"),
}

/** Catalog sections available on the Series screen. */
enum class SeriesSection(val display: String, val endpoint: String) {
    POPULAR("Popular", "/tv/popular"),
    TOP_RATED("Top rated", "/tv/top_rated"),
    ON_THE_AIR("On the air", "/tv/on_the_air"),
}

/**
 * Catalog + sync access for the desktop client. Backed by the real TMDB /
 * Firebase backend (same as mobile & TV) via [TmdbRepository], with an offline
 * sample catalog as the last-resort fallback so the shell still renders.
 */
interface MediaRepository {
    suspend fun homeSections(): List<HomeSection>
    suspend fun continueWatching(): List<ContinueWatch>
    suspend fun movies(section: MovieSection, page: Int = 1): List<MediaItem>
    suspend fun series(section: SeriesSection, page: Int = 1): List<MediaItem>
    suspend fun search(query: String, page: Int = 1): List<MediaItem>
    suspend fun details(id: String, mediaType: String? = null): MediaDetails?
    suspend fun episodes(seriesId: String, season: Int): List<Episode>
    /** Similar titles for the Details "More like this" rail (may be empty). */
    suspend fun recommendations(id: String, mediaType: String?): List<MediaItem> = emptyList()

    // Cloud sync (watchlist + progress) — safe to call signed out.
    suspend fun watchlist(): List<MediaItem>
    suspend fun isInWatchlist(id: String): Boolean
    suspend fun toggleWatchlist(item: MediaItem)
    suspend fun saveProgress(item: MediaItem, season: Int, episode: Int, positionMs: Long, lengthMs: Long)
}