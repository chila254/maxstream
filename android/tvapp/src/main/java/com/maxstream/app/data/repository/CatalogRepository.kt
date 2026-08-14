package com.maxstream.app.data.repository

import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.remote.EpisodeRef
import com.maxstream.app.data.remote.TmdbApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

/**
 * Catalogue access for browse/search/details. Thin coroutine wrapper over [TmdbApi].
 */
class CatalogRepository(private val api: TmdbApi) {

    suspend fun trendingMovies(page: Int = 1): List<MediaItem> = withContext(Dispatchers.IO) {
        api.trendingMovies(page)
    }

    suspend fun trendingSeries(page: Int = 1): List<MediaItem> = withContext(Dispatchers.IO) {
        api.trendingSeries(page)
    }

    suspend fun popularMovies(page: Int = 1): List<MediaItem> = withContext(Dispatchers.IO) {
        api.popularMovies(page)
    }

    suspend fun popularSeries(page: Int = 1): List<MediaItem> = withContext(Dispatchers.IO) {
        api.popularSeries(page)
    }

    suspend fun topRatedMovies(page: Int = 1): List<MediaItem> = withContext(Dispatchers.IO) {
        api.topRatedMovies(page)
    }

    suspend fun topRatedSeries(page: Int = 1): List<MediaItem> = withContext(Dispatchers.IO) {
        api.topRatedSeries(page)
    }

    suspend fun search(query: String, page: Int = 1): List<MediaItem> = withContext(Dispatchers.IO) {
        api.search(query, page)
    }

    suspend fun movieDetails(id: Int): JSONObject = withContext(Dispatchers.IO) { api.movieDetails(id) }
    suspend fun seriesDetails(id: Int): JSONObject = withContext(Dispatchers.IO) { api.seriesDetails(id) }

    suspend fun seasonEpisodes(seriesId: Int, season: Int): List<EpisodeRef> =
        withContext(Dispatchers.IO) { api.seasonEpisodes(seriesId, season) }

    suspend fun genres(type: String): Map<Int, String> = withContext(Dispatchers.IO) { api.genres(type) }

    suspend fun catalogByGenre(genreId: Int, type: String, page: Int = 1): List<com.maxstream.app.data.model.MediaItem> =
        withContext(Dispatchers.IO) { api.discover(type, genreId, page) }
}
