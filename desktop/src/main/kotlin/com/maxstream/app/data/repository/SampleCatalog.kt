package com.maxstream.app.data.repository

import com.maxstream.app.data.model.ContinueWatch
import com.maxstream.app.data.model.Episode
import com.maxstream.app.data.model.HomeSection
import com.maxstream.app.data.model.MediaDetails
import com.maxstream.app.data.model.MediaItem

/**
 * Offline fallback catalog. Used when TMDB is unreachable so the desktop shell
 * never renders as an empty void. Data mirrors the old static sample set.
 */
object SampleCatalog : MediaRepository {

    private val catalog = listOf(
        MediaItem("1", "Neon Horizon", "movie", "A data courier is chased across a rain-soaked megacity after stealing the algorithm that runs it.",
            2026, listOf("Sci-Fi", "Thriller"), 8.2, 0f, null, null),
        MediaItem("2", "The Last Lighthouse", "movie", "Two rivals guard the final lighthouse guarding a flooded coastal nation.",
            2025, listOf("Drama"), 7.6, 0f, null, null),
        MediaItem("3", "Static Bloom", "tv", "A detective who sees static everywhere untangles a city-wide signal conspiracy.",
            2026, listOf("Crime", "Mystery"), 8.8, 0f, null, null),
        MediaItem("4", "Garden of Machines", "movie", "An AI gardener inherits a dead colony's botanical vault and must resurrect it.",
            2024, listOf("Sci-Fi", "Family"), 7.1, 0f, null, null),
        MediaItem("5", "Tidewater", "tv", "Siblings fight over the family fishing empire on a shrinking boyhood island.",
            2025, listOf("Drama"), 8.0, 0f, null, null),
        MediaItem("6", "Carbon Copy", "movie", "A memoir ghost-writer discovers her subject is writing the same book about her.",
            2026, listOf("Comedy", "Drama"), 6.9, 0f, null, null),
        MediaItem("7", "No Signal Above", "tv", "Astronauts lose Earth after a solar storm and must steer a drifting station home.",
            2024, listOf("Sci-Fi"), 8.5, 0f, null, null),
        MediaItem("8", "Paper Lanterns", "movie", "A quiet romance in a city that turns off its lights one night a year.",
            2023, listOf("Romance"), 7.4, 0f, null, null),
    )

    override suspend fun homeSections(): List<HomeSection> = listOf(
        HomeSection("Trending", catalog.take(6)),
        HomeSection("Popular", catalog.drop(1).take(6)),
    )

    override suspend fun continueWatching(): List<ContinueWatch> = emptyList()

    override suspend fun movies(section: MovieSection): List<MediaItem> = catalog.filter { it.mediaType == "movie" }

    override suspend fun series(section: SeriesSection): List<MediaItem> = catalog.filter { it.mediaType == "tv" }

    override suspend fun search(query: String): List<MediaItem> =
        if (query.isBlank()) catalog
        else catalog.filter { it.title.contains(query, ignoreCase = true) || it.genres.any { g -> g.contains(query, ignoreCase = true) } }

    override suspend fun details(id: String, mediaType: String?): MediaDetails? =
        catalog.firstOrNull { it.id == id }?.let { MediaDetails(it) }

    override suspend fun episodes(seriesId: String, season: Int): List<Episode> = emptyList()

    override suspend fun watchlist(): List<MediaItem> = emptyList()

    override suspend fun isInWatchlist(id: String): Boolean = false

    override suspend fun toggleWatchlist(item: MediaItem) = Unit

    override suspend fun saveProgress(item: MediaItem, season: Int, episode: Int, positionMs: Long, lengthMs: Long) = Unit
}