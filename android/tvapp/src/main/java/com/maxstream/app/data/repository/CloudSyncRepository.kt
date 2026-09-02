package com.maxstream.app.data.repository

import android.content.Context
import com.maxstream.app.core.Constants
import com.maxstream.app.data.local.SessionManager
import com.maxstream.app.data.local.WatchProgressRepository
import com.maxstream.app.data.local.WatchlistRepository
import com.maxstream.app.data.model.MediaItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Cloud sync for the native TV build using Firebase Realtime Database REST API.
 * Watchlist + watch-progress data lives in RTDB under
 * `users/{uid}/watchlist` and `users/{uid}/watch_history`, so the TV and phone
 * stay in sync when signed in with the same account.
 *
 * All calls authenticate as the signed-in user via the idToken passed as a
 * query parameter — no Firebase SDK needed on the TV.
 */
object CloudSyncRepository {
    private const val PROJECT_ID = "maxstream-8effc"
    private const val RTDB_BASE =
        "https://$PROJECT_ID-default-rtdb.firebaseio.com"

    private val JSON = "application/json".toMediaType()

    private val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(25, TimeUnit.SECONDS)
            .build()
    }

    private fun auth(context: Context): String {
        val token = SessionManager.idToken(context)
        return if (token.isNotEmpty()) token else ""
    }

    private suspend fun ensureFreshToken(context: Context) {
        if (SessionManager.idToken(context).isEmpty()) return
        AuthRepository.ensureFreshIdToken(context)
    }

    private fun rtdbUrl(path: String, context: Context): String {
        val token = auth(context)
        val base = "$RTDB_BASE$path.json"
        return if (token.isNotEmpty()) "$base?auth=$token" else base
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HTTP helpers
    // ─────────────────────────────────────────────────────────────────────────

    private suspend fun getJson(path: String, context: Context): JSONObject? =
        withContext(Dispatchers.IO) {
            repeat(2) { attempt ->
                if (attempt == 0) {
                    ensureFreshToken(context)
                } else {
                    AuthRepository.refreshIdToken(context)
                }
                val request = Request.Builder().url(rtdbUrl(path, context)).get().build()
                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        val text = response.body?.string()
                        if (text.isNullOrBlank() || text == "null") return@withContext null
                        return@withContext JSONObject(text)
                    }
                    if (response.code != 401 && response.code != 403) {
                        throw IOException("Realtime Database read failed: HTTP ${response.code}")
                    }
                }
            }
            throw IOException("Realtime Database authentication failed after token refresh")
        }

    private suspend fun putJson(path: String, body: JSONObject, context: Context) {
        withContext(Dispatchers.IO) {
            ensureFreshToken(context)
            val url = rtdbUrl(path, context)
            val request = Request.Builder().url(url)
                .put(body.toString().toRequestBody(JSON))
                .build()
            client.newCall(request).execute().use { }
        }
    }

    private suspend fun deleteJson(path: String, context: Context) {
        withContext(Dispatchers.IO) {
            ensureFreshToken(context)
            val url = rtdbUrl(path, context)
            val request = Request.Builder().url(url).delete().build()
            client.newCall(request).execute().use { }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Watchlist
    // ─────────────────────────────────────────────────────────────────────────

    private fun watchlistKey(id: String, mediaType: String): String =
        "${id}_$mediaType"

    private fun fullUrl(path: String?): String {
        if (path.isNullOrEmpty()) return ""
        if (path.startsWith("http://") || path.startsWith("https://")) return path
        return "${Constants.TMDB_IMAGE_BASE}/w500$path"
    }

    /** Pushes a watchlist entry to RTDB (upsert). */
    suspend fun pushWatchlist(context: Context, item: MediaItem) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || item.id == 0) return
        val key = watchlistKey(item.id.toString(), item.mediaType)
        val body = JSONObject().apply {
            put("id", item.id.toString())
            put("title", item.title)
            put("description", item.overview)
            put("thumbnail", fullUrl(item.posterPath))
            put("backdrop", fullUrl(item.backdropPath))
            put("videoUrl", "")
            put("trailerUrl", "")
            put("year", item.releaseDate.take(4))
            put("rating", item.voteAverage)
            put("mediaType", item.mediaType)
            put("country", "")
        }
        putJson("/users/$uid/watchlist/$key", body, context)
    }

    /** Deletes a watchlist entry from RTDB. */
    suspend fun deleteWatchlist(context: Context, id: String, mediaType: String) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || id.isEmpty()) return
        deleteJson("/users/$uid/watchlist/${watchlistKey(id, mediaType)}", context)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Watch progress
    // ─────────────────────────────────────────────────────────────────────────

    private fun watchHistoryKey(tmdbId: String, isMovie: Boolean, season: Int, episode: Int): String =
        if (isMovie) "movie_$tmdbId" else "tv_${tmdbId}_${season}_$episode"

    /** Pushes watch progress to RTDB (upsert). */
    suspend fun pushWatchProgress(
        context: Context,
        tmdbId: String,
        title: String,
        isMovie: Boolean,
        season: Int,
        episode: Int,
        positionSeconds: Long,
        durationSeconds: Long,
        posterPath: String,
        seriesTitle: String = "",
        episodeName: String = "",
    ) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || tmdbId.isEmpty()) return
        val percentage = if (durationSeconds > 0)
            (positionSeconds.toDouble() / durationSeconds * 100).coerceIn(0.0, 100.0)
        else 0.0
        val body = JSONObject().apply {
            put("tmdbId", tmdbId)
            put("title", title)
            put("isMovie", isMovie)
            put("season", season)
            put("episode", episode)
            put("posterUrl", fullUrl(posterPath))
            put("seriesTitle", seriesTitle)
            put("episodeName", episodeName)
            put("position", positionSeconds)
            put("duration", durationSeconds)
            put("watchPercentage", percentage)
            put("isWatched", percentage >= 90.0)
            put("timestamp", System.currentTimeMillis())
        }
        val key = watchHistoryKey(tmdbId, isMovie, season, episode)
        putJson("/users/$uid/watch_history/$key", body, context)
    }

    /** Deletes watch progress from RTDB. */
    suspend fun deleteWatchProgress(
        context: Context,
        tmdbId: String,
        isMovie: Boolean,
        season: Int,
        episode: Int,
    ) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || tmdbId.isEmpty()) return
        val key = watchHistoryKey(tmdbId, isMovie, season, episode)
        deleteJson("/users/$uid/watch_history/$key", context)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Pull (cloud → local)
    // ─────────────────────────────────────────────────────────────────────────

    /** Pulls the signed-in user's cloud data into local storage. Safe to call
     * repeatedly; missing auth or network failure is silently ignored.
     *
     * Returns which collections changed so screens can refresh. */
    suspend fun pullToDevice(context: Context): SyncChange {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || auth(context).isEmpty()) return SyncChange(false, false)

        var historyChanged = false
        var watchlistChanged = false

        runCatching {
            val historyJson = getJson("/users/$uid/watch_history", context)
            if (historyJson != null) {
                val cloudKeys = mutableSetOf<String>()
                val keys = historyJson.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val entry = historyJson.optJSONObject(key) ?: continue
                    val tmdbId = entry.optString("tmdbId", "")
                    if (tmdbId.isEmpty()) continue
                    val isMovie = entry.optBoolean("isMovie", false)
                    val season = entry.optInt("season", 1).takeIf { it > 0 } ?: 1
                    val episode = entry.optInt("episode", 1).takeIf { it > 0 } ?: 1
                    val position = entry.optLong("position", 0)
                    val duration = entry.optLong("duration", 0)
                    if (position <= 0L) continue
                    val title = entry.optString("title", tmdbId)
                    cloudKeys += key
                    historyChanged = WatchProgressRepository.importCloudEntry(
                        context,
                        tmdbId = tmdbId,
                        title = title,
                        isMovie = isMovie,
                        season = season,
                        episode = episode,
                        positionSeconds = position,
                        durationSeconds = duration,
                        posterPath = entry.optString("posterUrl", ""),
                        backdropPath = "",
                        timestamp = entry.optLong("timestamp", 0),
                        seriesTitle = entry.optString("seriesTitle", ""),
                        episodeName = entry.optString("episodeName", ""),
                        isWatched = entry.optBoolean("isWatched", false),
                    ) || historyChanged
                }
                // Deletions: drop local entries the cloud no longer has.
                val local = WatchProgressRepository.recent(context, limit = 200)
                for (entry in local) {
                    val key = watchHistoryKey(entry.tmdbId, entry.isMovie, entry.season, entry.episode)
                    if (key !in cloudKeys) {
                        WatchProgressRepository.removeEntry(
                            context, entry.tmdbId, entry.isMovie, entry.season, entry.episode,
                        )
                        historyChanged = true
                    }
                }
            }
        }

        runCatching {
            val watchlistJson = getJson("/users/$uid/watchlist", context)
            if (watchlistJson != null) {
                val localKeysBefore = WatchlistRepository.getAll(context)
                    .map { watchlistKey(it.id.toString(), it.mediaType) }
                    .toSet()
                val cloudKeys = mutableSetOf<String>()
                val keys = watchlistJson.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val entry = watchlistJson.optJSONObject(key) ?: continue
                    val id = entry.optString("id", "")
                    if (id.isEmpty()) continue
                    val mediaType = entry.optString("mediaType", "movie")
                    val item = MediaItem(
                        id = id.toIntOrNull() ?: continue,
                        mediaType = mediaType,
                        title = entry.optString("title", id),
                        overview = entry.optString("description", ""),
                        posterPath = entry.optString("thumbnail", "").ifBlank { null },
                        backdropPath = entry.optString("backdrop", "").ifBlank { null },
                        releaseDate = entry.optString("year", ""),
                        voteAverage = entry.optDouble("rating", 0.0),
                        genreIds = emptyList(),
                    )
                    cloudKeys += key
                    WatchlistRepository.add(context, item)
                }
                // Deletions: drop local items the cloud no longer has.
                val local = WatchlistRepository.getAll(context)
                for (item in local) {
                    val key = watchlistKey(item.id.toString(), item.mediaType)
                    if (key !in cloudKeys) {
                        WatchlistRepository.removeByKey(context, item.id.toString(), item.mediaType)
                        watchlistChanged = true
                    }
                }
                // Additions: a new cloud entry that wasn't local before.
                val localKeysAfter = WatchlistRepository.getAll(context)
                    .map { watchlistKey(it.id.toString(), it.mediaType) }
                    .toSet()
                if (localKeysAfter != localKeysBefore) watchlistChanged = true
            }
        }

        return SyncChange(historyChanged, watchlistChanged)
    }

    /** Result of a cloud pull: which collections actually changed. */
    data class SyncChange(
        val historyChanged: Boolean,
        val watchlistChanged: Boolean,
    )
}
