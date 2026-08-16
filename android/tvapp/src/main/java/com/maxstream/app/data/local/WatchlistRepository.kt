package com.maxstream.app.data.local

import android.content.Context
import android.content.SharedPreferences
import com.maxstream.app.data.model.MediaItem

/**
 * Local watchlist store (mirrors the Dart `DBHelper.getWatchlistItems` flow).
 * Persists [MediaItem]s as JSON in SharedPreferences so the TV app keeps a
 * watchlist without the cloud-sync backend.
 */
object WatchlistRepository {
    private const val PREFS = "maxstream_tv_watchlist"
    private const val KEY_ITEMS = "items"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun getAll(context: Context): List<MediaItem> {
        val raw = prefs(context).getString(KEY_ITEMS, null) ?: return emptyList()
        return runCatching {
            val arr = org.json.JSONArray(raw)
            (0 until arr.length()).mapNotNull { i ->
                runCatching { MediaItem.fromJson(arr.getJSONObject(i)) }.getOrNull()
            }
        }.getOrDefault(emptyList())
    }

    fun isIn(context: Context, item: MediaItem): Boolean =
        getAll(context).any { it.id == item.id && it.mediaType == item.mediaType }

    fun add(context: Context, item: MediaItem) {
        val items = getAll(context).toMutableList()
        if (items.none { it.id == item.id && it.mediaType == item.mediaType }) {
            items.add(0, item)
            save(context, items)
        }
    }

    fun remove(context: Context, item: MediaItem) {
        val items = getAll(context).filterNot { it.id == item.id && it.mediaType == item.mediaType }
        save(context, items)
    }

    /** Removes by id+type without needing a full [MediaItem] (cloud reconcile). */
    fun removeByKey(context: Context, id: String, mediaType: String) {
        val items = getAll(context).filterNot { it.id.toString() == id && it.mediaType == mediaType }
        save(context, items)
    }

    fun toggle(context: Context, item: MediaItem): Boolean {
        return if (isIn(context, item)) {
            remove(context, item)
            false
        } else {
            add(context, item)
            true
        }
    }

    private fun save(context: Context, items: List<MediaItem>) {
        val arr = org.json.JSONArray()
        items.forEach { arr.put(it.toJson()) }
        prefs(context).edit().putString(KEY_ITEMS, arr.toString()).apply()
    }

    private fun MediaItem.toJson(): org.json.JSONObject {
        val json = org.json.JSONObject()
        json.put("id", id)
        json.put("media_type", mediaType)
        json.put("title", title)
        json.put("overview", overview)
        json.put("poster_path", posterPath)
        json.put("backdrop_path", backdropPath)
        json.put("release_date", releaseDate)
        json.put("vote_average", voteAverage)
        val genres = org.json.JSONArray()
        genreIds.forEach { genres.put(it) }
        json.put("genre_ids", genres)
        return json
    }
}
