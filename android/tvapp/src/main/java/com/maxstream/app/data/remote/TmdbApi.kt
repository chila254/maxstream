package com.maxstream.app.data.remote

import com.maxstream.app.core.Constants
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Thin TMDB v3 client (OkHttp). Mirrors the endpoints used by the legacy Flutter
 * [TmdbApiService] so the native TV app shows the same catalogue.
 */
class TmdbApi(
    private val client: OkHttpClient = defaultClient,
    private val apiKey: String = Constants.TMDB_API_KEY,
) {
    private fun get(path: String, params: Map<String, String> = emptyMap()): JSONObject {
        val url = buildString {
            append(Constants.TMDB_BASE_URL).append(path)
            append(if (path.contains('?')) '&' else '?')
            append("api_key=").append(apiKey)
            params.forEach { (k, v) -> append('&').append(k).append('=').append(v) }
        }
        val request = Request.Builder().url(url).header("Accept", "application/json").build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IllegalStateException("TMDB HTTP ${response.code} for $path")
            }
            val body = response.body?.string().orEmpty()
            return JSONObject(body)
        }
    }

    suspend fun trendingMovies(page: Int = 1): List<com.maxstream.app.data.model.MediaItem> =
        list("/trending/movie/week", page)

    suspend fun trendingSeries(page: Int = 1): List<com.maxstream.app.data.model.MediaItem> =
        list("/trending/tv/week", page)

    suspend fun popularMovies(page: Int = 1): List<com.maxstream.app.data.model.MediaItem> =
        list("/movie/popular", page)

    suspend fun popularSeries(page: Int = 1): List<com.maxstream.app.data.model.MediaItem> =
        list("/tv/popular", page)

    suspend fun topRatedMovies(page: Int = 1): List<com.maxstream.app.data.model.MediaItem> =
        list("/movie/top_rated", page)

    suspend fun topRatedSeries(page: Int = 1): List<com.maxstream.app.data.model.MediaItem> =
        list("/tv/top_rated", page)

    suspend fun search(query: String, page: Int = 1): List<com.maxstream.app.data.model.MediaItem> {
        if (query.isBlank()) return emptyList()
        val json = get("/search/multi", mapOf("query" to query, "page" to page.toString()))
        return parseResults(json)
    }

    suspend fun movieDetails(id: Int): JSONObject =
        get("/movie/$id", mapOf("append_to_response" to "credits,similar,videos"))

    suspend fun seriesDetails(id: Int): JSONObject =
        get("/tv/$id", mapOf("append_to_response" to "credits,similar,videos,seasons"))

    suspend fun episodeDetails(seriesId: Int, season: Int, episode: Int): JSONObject =
        get("/tv/$seriesId/season/$season/episode/$episode")

    suspend fun seasonEpisodes(seriesId: Int, season: Int): List<EpisodeRef> {
        val json = get("/tv/$seriesId/season/$season")
        val arr = json.optJSONArray("episodes") ?: return emptyList()
        return (0 until arr.length()).mapNotNull { i ->
            val e = arr.optJSONObject(i) ?: return@mapNotNull null
            EpisodeRef(
                number = e.optInt("episode_number", 0),
                title = e.optString("name").ifBlank { "Episode ${e.optInt("episode_number")}" },
                overview = e.optString("overview"),
                stillPath = e.optString("still_path").ifBlank { null },
                airDate = e.optString("air_date"),
            )
        }
    }

    suspend fun genres(type: String): Map<Int, String> {
        val json = get("/genre/$type/list")
        val arr = json.optJSONArray("genres") ?: return emptyMap()
        val map = mutableMapOf<Int, String>()
        for (i in 0 until arr.length()) {
            val g = arr.optJSONObject(i) ?: continue
            map[g.optInt("id")] = g.optString("name")
        }
        return map
    }

    suspend fun discover(type: String, genreId: Int, page: Int = 1): List<com.maxstream.app.data.model.MediaItem> {
        val path = if (type == "tv") "/discover/tv" else "/discover/movie"
        return parseResults(get(path, mapOf("with_genres" to genreId.toString(), "page" to page.toString())))
    }

    private fun list(path: String, page: Int): List<com.maxstream.app.data.model.MediaItem> =
        parseResults(get(path, mapOf("page" to page.toString())))

    private fun parseResults(json: JSONObject): List<com.maxstream.app.data.model.MediaItem> {
        val arr = json.optJSONArray("results") ?: JSONArray()
        return com.maxstream.app.data.model.MediaItem.fromJsonList(arr)
    }

    companion object {
        val defaultClient: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .connectTimeout(Constants.NETWORK_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .readTimeout(Constants.NETWORK_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .build()
        }
    }
}

data class EpisodeRef(
    val number: Int,
    val title: String,
    val overview: String,
    val stillPath: String?,
    val airDate: String,
)
