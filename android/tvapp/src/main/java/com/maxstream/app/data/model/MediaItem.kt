package com.maxstream.app.data.model

import org.json.JSONObject

/**
 * A catalogue entry (movie or series) surfaced in browse/search.
 * Constructed from a TMDB result object.
 */
data class MediaItem(
    val id: Int,
    val mediaType: String, // "movie" | "tv"
    val title: String,
    val overview: String,
    val posterPath: String?,
    val backdropPath: String?,
    val releaseDate: String,
    val voteAverage: Double,
    val genreIds: List<Int>,
    val season: Int = 1,
    val episode: Int = 1,
    val seriesTitle: String = "",
    val episodeName: String = "",
) {
    val isMovie: Boolean get() = mediaType == "movie"
    val posterUrl: String get() = imageUrl(posterPath, "w500")
    val backdropUrl: String get() = imageUrl(backdropPath, "w1280")

    private fun imageUrl(path: String?, size: String): String {
        if (path.isNullOrEmpty()) return ""
        if (path.startsWith("http://") || path.startsWith("https://")) return path
        return "${com.maxstream.app.core.Constants.TMDB_IMAGE_BASE}/$size$path"
    }

    fun toBundle(): android.os.Bundle = android.os.Bundle().apply {
        putInt("id", id)
        putString("mediaType", mediaType)
        putString("title", title)
        putString("overview", overview)
        putString("posterPath", posterPath)
        putString("backdropPath", backdropPath)
        putString("releaseDate", releaseDate)
        putDouble("voteAverage", voteAverage)
        putIntegerArrayList("genreIds", ArrayList(genreIds))
        putInt("season", season)
        putInt("episode", episode)
        putString("seriesTitle", seriesTitle)
        putString("episodeName", episodeName)
    }

    companion object {
        fun fromBundle(bundle: android.os.Bundle): MediaItem = MediaItem(
            id = bundle.getInt("id"),
            mediaType = bundle.getString("mediaType").orEmpty(),
            title = bundle.getString("title").orEmpty(),
            overview = bundle.getString("overview").orEmpty(),
            posterPath = bundle.getString("posterPath"),
            backdropPath = bundle.getString("backdropPath"),
            releaseDate = bundle.getString("releaseDate").orEmpty(),
            voteAverage = bundle.getDouble("voteAverage", 0.0),
            genreIds = bundle.getIntegerArrayList("genreIds").orEmpty(),
            season = bundle.getInt("season", 1),
            episode = bundle.getInt("episode", 1),
            seriesTitle = bundle.getString("seriesTitle").orEmpty(),
            episodeName = bundle.getString("episodeName").orEmpty(),
        )

        /**
         * @param defaultType used when the JSON lacks a "media_type" field.
         *   TMDB's type-specific list endpoints (/tv/popular, /trending/tv/week, …)
         *   do NOT include "media_type" on each result, so callers must pass the
         *   known type ("tv"/"movie"). Only /search/multi and /trending/all supply
         *   it per item.
         */
        fun fromJson(json: JSONObject, defaultType: String = "movie"): MediaItem {
            val type = if (json.has("media_type")) json.getString("media_type") else defaultType
            val title = json.optString("title").ifBlank { json.optString("name") }
            val release = json.optString("release_date").ifBlank { json.optString("first_air_date") }
            val poster = json.optString("poster_path").ifBlank { null }
            val backdrop = json.optString("backdrop_path").ifBlank { null }
            val genres = json.optJSONArray("genre_ids")
            val genreIds = if (genres != null) {
                (0 until genres.length()).map { genres.getInt(it) }
            } else emptyList()
            return MediaItem(
                id = json.getInt("id"),
                mediaType = type,
                title = title,
                overview = json.optString("overview"),
                posterPath = poster,
                backdropPath = backdrop,
                releaseDate = release,
                voteAverage = json.optDouble("vote_average", 0.0),
                genreIds = genreIds,
            )
        }

        fun fromJsonList(array: org.json.JSONArray, defaultType: String = "movie"): List<MediaItem> {
            val out = mutableListOf<MediaItem>()
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                runCatching { out += fromJson(obj, defaultType) }
            }
            return out
        }
    }
}
