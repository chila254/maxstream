package com.maxstream.app.data

import org.json.JSONArray
import org.json.JSONObject
import java.nio.file.Files
import java.nio.file.Paths

/**
 * Local resume memory for the desktop player. Persists last-watched position
 * and enough metadata (title/poster) to render Continue Watching offline, and
 * is the merge target for cloud watch-history pulled from Firebase.
 */
object WatchStateStore {

    data class WatchState(
        val itemId: String,
        val mediaType: String,
        val season: Int,
        val episode: Int,
        val positionMs: Long,
        val lengthMs: Long,
        val updatedAt: Long,
        val title: String = "",
        val posterPath: String? = null,
        val backdropPath: String? = null,
    ) {
        val progress: Float
            get() = if (lengthMs > 0L) (positionMs.toFloat() / lengthMs).coerceIn(0f, 1f) else 0f
    }

    /** Resume position for a specific movie/episode, or null when fresh. */
    fun resumeFor(itemId: String, season: Int, episode: Int): WatchState? =
        load()[key(itemId, season, episode)]

    /** Overwrites the stored state for the given movie/episode. */
    fun save(state: WatchState) = synchronized(this) {
        val all = load().toMutableMap()
        all[key(state.itemId, state.season, state.episode)] = state
        write(all)
    }

    /** Removes a finished/cleared movie/episode. */
    fun clear(itemId: String, season: Int, episode: Int) = synchronized(this) {
        val all = load().toMutableMap()
        all.remove(key(itemId, season, episode))
        write(all)
    }

    /** Everything, newest last-played first. */
    fun all(): List<WatchState> = synchronized(this) {
        load().values.sortedByDescending { it.updatedAt }
    }

    /** Merges cloud entries into the local store (newest per movie/episode wins). */
    fun mergeIncoming(states: List<WatchState>): Int = synchronized(this) {
        val all = load().toMutableMap()
        var merged = 0
        states.forEach { s ->
            val k = key(s.itemId, s.season, s.episode)
            val existing = all[k]
            if (existing == null || s.updatedAt > existing.updatedAt) {
                all[k] = s
                merged++
            }
        }
        write(all)
        merged
    }

    // ── persistence ──────────────────────────────────────────────────────────

    private val map = HashMap<String, WatchState>()

    private fun load(): Map<String, WatchState> = synchronized(this) {
        if (map.isNotEmpty()) return HashMap(map)
        try {
            if (Files.exists(file())) {
                val root = JSONObject(Files.readString(file()))
                val arr = root.optJSONArray("items") ?: JSONArray()
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    map[o.getString("key")] = WatchState(
                        itemId = o.optString("itemId", ""),
                        mediaType = o.optString("mediaType", "movie"),
                        season = o.optInt("season", 1),
                        episode = o.optInt("episode", 1),
                        positionMs = o.optLong("positionMs", 0L),
                        lengthMs = o.optLong("lengthMs", 0L),
                        updatedAt = o.optLong("updatedAt", 0L),
                        title = o.optString("title", ""),
                        posterPath = o.optString("posterPath").ifBlank { null },
                        backdropPath = o.optString("backdropPath").ifBlank { null },
                    )
                }
            }
        } catch (_: Exception) {
            // Corrupt state file — start fresh.
        }
        HashMap(map)
    }

    private fun write(all: Map<String, WatchState>) {
        try {
            val arr = JSONArray()
            all.values.forEach {
                arr.put(
                    JSONObject()
                        .put("key", key(it.itemId, it.season, it.episode))
                        .put("itemId", it.itemId)
                        .put("mediaType", it.mediaType)
                        .put("season", it.season)
                        .put("episode", it.episode)
                        .put("positionMs", it.positionMs)
                        .put("lengthMs", it.lengthMs)
                        .put("updatedAt", it.updatedAt)
                        .put("title", it.title)
                        .put("posterPath", it.posterPath ?: "")
                        .put("backdropPath", it.backdropPath ?: ""),
                )
            }
            Files.createDirectories(file().parent)
            Files.writeString(file(), JSONObject().put("items", arr).toString())
        } catch (_: Exception) {
        }
    }

    private fun file() =
        Paths.get(System.getProperty("user.home"), ".maxstream", "watchstate.json")

    private fun key(itemId: String, season: Int, episode: Int) = "$itemId|S$season|E$episode"
}