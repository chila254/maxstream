package com.maxstream.app.data.repository

import com.maxstream.app.data.WatchStateStore
import com.maxstream.app.data.cloud.CloudSync
import com.maxstream.app.data.model.ContinueWatch
import com.maxstream.app.data.model.Episode
import com.maxstream.app.data.model.HomeSection
import com.maxstream.app.data.model.MediaDetails
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.remote.TmdbClient

/**
 * Primary desktop data source. Reads catalog/metadata from the real TMDB API
 * (same endpoints and key as mobile + TV), and wires watchlist + progress
 * through Firebase cloud sync with the local watch-state store as the offline
 * merge target. Every network call falls back to [SampleCatalog] so the app
 * still renders when offline.
 */
object TmdbRepository : MediaRepository {

    private val client = TmdbClient()

    override suspend fun homeSections(): List<HomeSection> = runCatching {
        client.genres("movie")
        client.genres("tv")
        listOf(
            HomeSection("Trending movies", client.array("/trending/movie/week").map(client::parseMedia)),
            HomeSection("Trending series", client.array("/trending/tv/week").map(client::parseMedia)),
            HomeSection("Popular movies", client.array("/movie/popular").map(client::parseMedia)),
            HomeSection("Popular series", client.array("/tv/popular").map(client::parseMedia)),
            HomeSection(
                "Top rated",
                (client.array("/movie/top_rated").map(client::parseMedia) +
                    client.array("/tv/top_rated").map(client::parseMedia)).distinctBy { it.id },
            ),
        ).filter { it.items.isNotEmpty() }
    }.getOrElse { SampleCatalog.homeSections() }

    override suspend fun continueWatching(): List<ContinueWatch> =
        WatchStateStore.all().map { s ->
            ContinueWatch(
                item = MediaItem(
                    id = s.itemId,
                    mediaType = s.mediaType,
                    title = s.title.ifBlank { "Title $s.itemId" },
                    overview = "",
                    posterPath = s.posterPath,
                    backdropPath = s.backdropPath,
                ),
                progress = s.progress,
                season = s.season,
                episode = s.episode,
            )
        }

    override suspend fun movies(section: MovieSection): List<MediaItem> = runCatching {
        client.genres("movie")
        client.array(section.endpoint).map(client::parseMedia)
    }.getOrElse { SampleCatalog.movies(section) }

    override suspend fun series(section: SeriesSection): List<MediaItem> = runCatching {
        client.genres("tv")
        client.array(section.endpoint).map(client::parseMedia)
    }.getOrElse { SampleCatalog.series(section) }

    override suspend fun search(query: String): List<MediaItem> =
        if (query.isBlank()) emptyList()
        else runCatching {
            client.genres("movie")
            client.genres("tv")
            client.array("/search/multi", "query" to query, "page" to "1")
                .filter { it.optString("media_type") == "movie" || it.optString("media_type") == "tv" }
                .take(40)
                .map(client::parseMedia)
        }.getOrElse { SampleCatalog.search(query) }

    override suspend fun details(id: String, mediaType: String?): MediaDetails? {
        val type = mediaType ?: resolveType(id)
        return runCatching {
            val raw = when (type) {
                "tv" -> client.json("/tv/$id", "append_to_response" to "credits,videos,seasons,watch/providers")
                else -> client.json("/movie/$id", "append_to_response" to "credits,videos,watch/providers")
            }
            client.genres(type)
            val item = client.parseMedia(raw).copy(mediaType = type)
            client.parseDetails(item, raw)
        }.getOrElse {
            SampleCatalog.details(id, type)
        }
    }

    private suspend fun resolveType(id: String): String {
        // Movie/tv id namespaces don't overlap; probe movie first, then series.
        return runCatching { client.json("/movie/$id"); "movie" }.getOrElse { "tv" }
    }

    override suspend fun episodes(seriesId: String, season: Int): List<Episode> = runCatching {
        client.array("/tv/$seriesId/season/$season").map { client.parseEpisode(it, seriesId, season) }
    }.getOrElse { SampleCatalog.episodes(seriesId, season) }

    // ── watchlist ────────────────────────────────────────────────────────────

    override suspend fun watchlist(): List<MediaItem> = CloudSync.watchlist()

    override suspend fun isInWatchlist(id: String): Boolean = CloudSync.isInWatchlist(id)

    override suspend fun toggleWatchlist(item: MediaItem) {
        if (CloudSync.isInWatchlist(item.id)) CloudSync.removeFromWatchlist(item)
        else CloudSync.addToWatchlist(item)
    }

    // ── progress ─────────────────────────────────────────────────────────────

    override suspend fun saveProgress(item: MediaItem, season: Int, episode: Int, positionMs: Long, lengthMs: Long) {
        val nearEnd = lengthMs > 0L && positionMs >= lengthMs - 10_000L
        val state = WatchStateStore.WatchState(
            itemId = item.id,
            mediaType = item.mediaType,
            season = season,
            episode = episode,
            positionMs = if (nearEnd) 0L else positionMs,
            lengthMs = lengthMs,
            updatedAt = System.currentTimeMillis(),
            title = item.title,
            posterPath = item.posterPath,
            backdropPath = item.backdropPath,
        )
        if (nearEnd) {
            WatchStateStore.clear(item.id, season, episode)
            if (CloudSync.isSynced) CloudSync.clearWatchHistory(state)
        } else {
            WatchStateStore.save(state)
            if (CloudSync.isSynced) CloudSync.pushWatchHistory(state)
        }
    }
}