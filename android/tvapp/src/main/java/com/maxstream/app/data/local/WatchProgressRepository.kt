package com.maxstream.app.data.local

import android.content.Context
import android.content.SharedPreferences
import com.maxstream.app.data.model.MediaItem
import org.json.JSONArray
import org.json.JSONObject

/**
 * Local watch-progress store (mirrors the Dart [WatchHistoryService] flow).
 * Persists per-title resume positions plus a timestamped "recently watched"
 * list so the native TV app can resume playback and populate the Home
 * "Continue Watching" row without the cloud-sync backend.
 */
object WatchProgressRepository {
    private const val PREFS = "maxstream_tv_watch_progress"
    private const val KEY_RECENT = "recent"
    private const val POSITION_SAVE_THRESHOLD_SECONDS = 30

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun progressKey(tmdbId: String, isMovie: Boolean, season: Int, episode: Int) =
        "progress:$tmdbId:$isMovie:$season:$episode"

    /** Resume position in seconds for the given title (0 when none). */
    fun loadPosition(context: Context, tmdbId: String, isMovie: Boolean, season: Int, episode: Int): Long {
        val raw = prefs(context).getString(progressKey(tmdbId, isMovie, season, episode), null) ?: return 0L
        return runCatching { JSONObject(raw).optLong("position", 0L) }.getOrDefault(0L)
    }

    /**
     * Persists watch progress. Ignores positions below the save threshold so a
     * freshly opened title is never marked as "started".
     */
    fun saveProgress(
        context: Context,
        tmdbId: String,
        title: String,
        isMovie: Boolean,
        season: Int,
        episode: Int,
        positionSeconds: Long,
        durationSeconds: Long,
        posterPath: String = "",
        backdropPath: String = "",
    ) {
        if (positionSeconds <= POSITION_SAVE_THRESHOLD_SECONDS) return
        val entry = JSONObject()
            .put("tmdbId", tmdbId)
            .put("title", title)
            .put("isMovie", isMovie)
            .put("season", season)
            .put("episode", episode)
            .put("position", positionSeconds)
            .put("duration", durationSeconds)
            .put("posterPath", posterPath)
            .put("backdropPath", backdropPath)
            .put("timestamp", System.currentTimeMillis())
        prefs(context).edit().putString(progressKey(tmdbId, isMovie, season, episode), entry.toString()).apply()
        upsertRecent(context, entry)
    }

    /** Clears the resume position (used when the user watches to the end). */
    fun clearPosition(context: Context, tmdbId: String, isMovie: Boolean, season: Int, episode: Int) {
        prefs(context).edit().remove(progressKey(tmdbId, isMovie, season, episode)).apply()
    }

    /** Recently-watched entries, newest first, for the Home Continue Watching row. */
    fun recent(context: Context, limit: Int = 20): List<WatchEntry> {
        val raw = prefs(context).getString(KEY_RECENT, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { i ->
                runCatching { WatchEntry.fromJson(arr.getJSONObject(i)) }.getOrNull()
            }
        }.getOrDefault(emptyList()).take(limit)
    }

    private fun upsertRecent(context: Context, entry: JSONObject) {
        val current = runCatching {
            JSONArray(prefs(context).getString(KEY_RECENT, "[]"))
        }.getOrDefault(JSONArray())
        val key = "${entry.optString("tmdbId")}:${entry.optBoolean("isMovie")}"
        val filtered = JSONArray()
        for (i in 0 until current.length()) {
            val item = current.optJSONObject(i) ?: continue
            val itemKey = "${item.optString("tmdbId")}:${item.optBoolean("isMovie")}"
            if (itemKey != key) filtered.put(item)
        }
        filtered.put(entry)
        prefs(context).edit().putString(KEY_RECENT, filtered.toString()).apply()
    }
}

/**
 * Holds the application [Context] (set from MainActivity) so the pure
 * [MediaItem] model can expose a watch-progress fraction for Continue
 * Watching cards without threading a Context through the data layer.
 */
object WatchEntryCompat {
    @Volatile
    private var appContext: Context? = null

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    fun progressOf(tmdbId: Int, mediaType: String, season: Int, episode: Int): Float {
        val context = appContext ?: return 0f
        val prefs = context.getSharedPreferences("maxstream_tv_watch_progress", Context.MODE_PRIVATE)
        val key = "progress:$tmdbId:${mediaType == "movie"}:$season:$episode"
        val raw = prefs.getString(key, null) ?: return 0f
        return runCatching {
            val obj = JSONObject(raw)
            val position = obj.optLong("position", 0L)
            val duration = obj.optLong("duration", 0L)
            if (duration > 0) {
                (position.toFloat() / duration.toFloat()).coerceIn(0f, 1f)
            } else 0f
        }.getOrDefault(0f)
    }

    /**
     * Returns Continue Watching entries for a specific title — used by
     * DetailsScreen to show the resume row (mirrors Dart's _continueWatching
     * filter in TvCinematicDetails._load()).
     */
    fun getEntriesFor(tmdbId: Int, isTv: Boolean): List<Entry> {
        val context = appContext ?: return emptyList()
        return WatchProgressRepository.recent(context)
            .filter { it.tmdbId == tmdbId.toString() && it.isMovie == !isTv }
            .take(6)
            .map { entry ->
                Entry(
                    tmdbId = entry.tmdbId,
                    title = entry.title,
                    season = entry.season,
                    episode = entry.episode,
                    position = entry.positionSeconds,
                    duration = entry.durationSeconds,
                    posterUrl = if (entry.posterPath.isNotEmpty())
                        "https://image.tmdb.org/t/p/w500${entry.posterPath}"
                    else "",
                )
            }
    }

    /** Simplified entry for UI consumption (DetailsScreen continue-watching row). */
    data class Entry(
        val tmdbId: String,
        val title: String,
        val season: Int,
        val episode: Int,
        val position: Long,
        val duration: Long,
        val posterUrl: String,
    )
}

/** A single "Continue Watching" entry reconstructed from stored JSON. */
data class WatchEntry(
    val tmdbId: String,
    val title: String,
    val isMovie: Boolean,
    val season: Int,
    val episode: Int,
    val positionSeconds: Long,
    val durationSeconds: Long,
    val posterPath: String,
    val backdropPath: String,
) {
    val progress: Float
        get() = if (durationSeconds > 0) {
            (positionSeconds.toFloat() / durationSeconds.toFloat()).coerceIn(0f, 1f)
        } else 0f

    fun toMediaItem(): MediaItem = MediaItem(
        id = tmdbId.toIntOrNull() ?: 0,
        mediaType = if (isMovie) "movie" else "tv",
        title = title,
        overview = "",
        posterPath = posterPath.ifEmpty { null },
        backdropPath = backdropPath.ifEmpty { null },
        releaseDate = "",
        voteAverage = 0.0,
        genreIds = emptyList(),
        season = season,
        episode = episode,
    )

    companion object {
        fun fromJson(json: JSONObject): WatchEntry = WatchEntry(
            tmdbId = json.optString("tmdbId"),
            title = json.optString("title"),
            isMovie = json.optBoolean("isMovie"),
            season = json.optInt("season", 1),
            episode = json.optInt("episode", 1),
            positionSeconds = json.optLong("position", 0L),
            durationSeconds = json.optLong("duration", 0L),
            posterPath = json.optString("posterPath"),
            backdropPath = json.optString("backdropPath"),
        )
    }
}
