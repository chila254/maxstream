package com.maxstream.app.data.cloud

import com.maxstream.app.core.AppConfig
import com.maxstream.app.data.WatchStateStore
import com.maxstream.app.data.model.MediaItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Firebase Realtime Database sync for the desktop client — watchlist + watch
 * history, stored under the same paths the TV app uses
 * (/users/{uid}/profiles/{profile}/...). All calls are signed-out safe: they
 * no-op and return empty results until a Firebase session exists.
 */
object CloudSync {

    private val jsonType = "application/json; charset=utf-8".toMediaType()

    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    val isSynced: Boolean get() = AppSession.isSignedIn

    // ── watchlist ────────────────────────────────────────────────────────────

    suspend fun watchlist(): List<MediaItem> = authed { token, base ->
        val root = get("$base/watchlist.json", token) ?: return@authed emptyList()
        val out = mutableListOf<MediaItem>()
        root.keys().forEach { key ->
            val o = root.optJSONObject(key) ?: return@forEach
            out += MediaItem(
                id = o.optString("mediaId"),
                title = o.optString("title"),
                mediaType = o.optString("mediaType", "movie"),
                overview = o.optString("overview"),
                year = o.optInt("year", 0).takeIf { it > 0 },
                rating = o.optDouble("rating", 0.0),
                posterPath = o.optString("posterUrl").ifBlank { o.optString("posterPath") }.ifBlank { null },
                backdropPath = o.optString("backdropUrl").ifBlank { o.optString("backdropPath") }.ifBlank { null },
            )
        }
        out
    } ?: emptyList()

    suspend fun isInWatchlist(id: String): Boolean = authed { token, base ->
        get("$base/watchlist.json", token)
            ?.let { root ->
                root.keys().asSequence().any { k -> root.optJSONObject(k)?.optString("mediaId") == id }
            }
            ?: false
    } ?: false

    suspend fun addToWatchlist(item: MediaItem) {
        authed { token, base ->
            val key = "${item.id}_${item.mediaType}"
            put(
                "$base/watchlist/$key.json",
                JSONObject()
                    .put("mediaId", item.id)
                    .put("mediaType", item.mediaType)
                    .put("title", item.title)
                    .put("posterPath", item.posterPath ?: "")
                    .put("backdropPath", item.backdropPath ?: "")
                    .put("overview", item.overview)
                    .put("year", item.year ?: 0)
                    .put("rating", item.rating)
                    .put("addedAt", System.currentTimeMillis()),
                token,
            )
        }
    }

    suspend fun removeFromWatchlist(item: MediaItem) {
        authed { token, base ->
            val key = "${item.id}_${item.mediaType}"
            delete("$base/watchlist/$key.json", token)
        }
    }

    // ── watch history / progress ─────────────────────────────────────────────

    suspend fun pushWatchHistory(s: WatchStateStore.WatchState) {
        authed { token, base ->
            val key = if (s.mediaType == "tv") "tv_${s.itemId}_${s.season}_${s.episode}" else "movie_${s.itemId}"
            put(
                "$base/watch_history/$key.json",
                JSONObject()
                    .put("itemId", s.itemId)
                    .put("mediaType", s.mediaType)
                    .put("season", s.season)
                    .put("episode", s.episode)
                    .put("positionMs", s.positionMs)
                    .put("lengthMs", s.lengthMs)
                    .put("progress", s.progress)
                    .put("title", s.title)
                    .put("posterPath", s.posterPath ?: "")
                    .put("backdropPath", s.backdropPath ?: "")
                    .put("year", s.year ?: 0)
                    .put("rating", s.rating)
                    .put("updatedAt", s.updatedAt),
                token,
            )
        }
    }

    /** Pulls cloud watch history into the local store; returns # merged. */
    suspend fun syncWatchHistory(): Int = authed { token, base ->
        val root = get("$base/watch_history.json", token) ?: return@authed 0
        val states = mutableListOf<WatchStateStore.WatchState>()
        root.keys().forEach { key ->
            val o = root.optJSONObject(key) ?: return@forEach
            states += WatchStateStore.WatchState(
                itemId = o.optString("itemId"),
                mediaType = o.optString("mediaType", "movie"),
                season = o.optInt("season", 1),
                episode = o.optInt("episode", 1),
                positionMs = o.optLong("positionMs", 0L),
                lengthMs = o.optLong("lengthMs", 0L),
                updatedAt = o.optLong("updatedAt", System.currentTimeMillis()),
                title = o.optString("title"),
                posterPath = o.optString("posterUrl").ifBlank { o.optString("posterPath") }.ifBlank { null },
                backdropPath = o.optString("backdropUrl").ifBlank { o.optString("backdropPath") }.ifBlank { null },
                year = o.optInt("year", 0).takeIf { it > 0 },
                rating = o.optDouble("rating", 0.0),
            )
        }
        WatchStateStore.mergeIncoming(states)
    } ?: 0

    suspend fun clearWatchHistory(s: WatchStateStore.WatchState) {
        authed { token, base ->
            val key = if (s.mediaType == "tv") "tv_${s.itemId}_${s.season}_${s.episode}" else "movie_${s.itemId}"
            delete("$base/watch_history/$key.json", token)
        }
    }

    // ── RTDB helpers ─────────────────────────────────────────────────────────

    /**
     * Runs [block] with the RTDB base + auth token when signed in; returns
     * null otherwise so every cloud call is signed-out safe.
     */
    private suspend fun <T> authed(block: (token: String, base: String) -> T): T? {
        val token = AppSession.freshToken() ?: return null
        val user = AppSession.user ?: return null
        return withContext(Dispatchers.IO) {
            block(token, rtdbBase(user.localId))
        }
    }

    private fun rtdbBase(uid: String): String {
    val profile = ProfileStore.activeProfileId ?: "default"
    return "${AppConfig.FIREBASE_RTDB_URL}/users/$uid/profiles/$profile"
}

    private fun get(url: String, token: String): JSONObject? {
        val request = Request.Builder()
            .url("$url?auth=$token")
            .header("Accept", "application/json")
            .build()
        return http.newCall(request).execute().use { res ->
            if (res.code == 404) null
            else if (!res.isSuccessful) null
            else runCatching { JSONObject(res.body?.string().orEmpty()) }.getOrNull()
        }
    }

    private fun put(url: String, body: JSONObject, token: String) {
        val request = Request.Builder()
            .url("$url?auth=$token")
            .put(body.toString().toRequestBody(jsonType))
            .build()
        http.newCall(request).execute().close()
    }

    private fun delete(url: String, token: String) {
        val request = Request.Builder()
            .url("$url?auth=$token")
            .delete()
            .build()
        http.newCall(request).execute().close()
    }
}