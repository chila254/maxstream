package com.maxstream.app.data.repository

import com.maxstream.app.data.model.MediaItem

/**
 * Catalog access for the desktop client. Backed by in-memory sample data today
 * so the shell compiles and runs offline; the interface is the seam where the
 * real backend (the same REST API the mobile/Chromecast clients hit) plugs in.
 */
interface MediaRepository {
    suspend fun home(): List<MediaItem>
    suspend fun byId(id: String): MediaItem?
    suspend fun search(query: String): List<MediaItem>
    suspend fun continueWatching(): List<MediaItem>
}

object DesktopRepository : MediaRepository {

    private val catalog = listOf(
        MediaItem("1", "Neon Horizon", "movie", "A data courier is chased across a rain-soaked megacity after stealing the algorithm that runs it.",
            2026, listOf("Sci-Fi", "Thriller"), 8.2, 0f),
        MediaItem("2", "The Last Lighthouse", "movie", "Two rivals guard the final lighthouse guarding a flooded coastal nation.",
            2025, listOf("Drama"), 7.6, 0.42f),
        MediaItem("3", "Static Bloom", "tv", "A detective who sees static everywhere untangles a city-wide signal conspiracy.",
            2026, listOf("Crime", "Mystery"), 8.8, 0f),
        MediaItem("4", "Garden of Machines", "movie", "An AI gardener inherits a dead colony's botanical vault and must resurrect it.",
            2024, listOf("Sci-Fi", "Family"), 7.1, 0f),
        MediaItem("5", "Tidewater", "tv", "Siblings fight over the family fishing empire on a shrinking boyhood island.",
            2025, listOf("Drama"), 8.0, 0.71f),
        MediaItem("6", "Carbon Copy", "movie", "A memoir ghost-writer discovers her subject is writing the same book about her.",
            2026, listOf("Comedy", "Drama"), 6.9, 0.15f),
        MediaItem("7", "No Signal Above", "tv", "Astronauts lose Earth after a solar storm and must steer a drifting station home.",
            2024, listOf("Sci-Fi"), 8.5, 0f),
        MediaItem("8", "Paper Lanterns", "movie", "A quiet romance in a city that turns off its lights one night a year.",
            2023, listOf("Romance"), 7.4, 0f),
    )

    override suspend fun home(): List<MediaItem> = catalog

    override suspend fun byId(id: String): MediaItem? = catalog.firstOrNull { it.id == id }

    override suspend fun search(query: String): List<MediaItem> =
        if (query.isBlank()) catalog
        else catalog.filter {
            it.title.contains(query, ignoreCase = true) ||
                it.genres.any { g -> g.contains(query, ignoreCase = true) }
        }

    override suspend fun continueWatching(): List<MediaItem> =
        catalog.filter { it.progress > 0f }.sortedByDescending { it.progress }
}