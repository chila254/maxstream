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
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Cloud sync for the native TV build, mirroring the phone's Dart
 * [CloudSyncService]. Watchlist + watch-progress data lives in Firestore under
 * `users/{uid}/watchlist` and `users/{uid}/watch_history`, so the TV and phone
 * stay in sync when signed in with the same account.
 *
 * All calls authenticate as the signed-in user with the idToken captured at
 * login (see [AuthRepository] / [SessionManager]) via the Firestore REST API —
 * no Firebase SDK needed on the TV.
 */
object CloudSyncRepository {
    private const val PROJECT_ID = "maxstream-8effc"

    private const val FIRESTORE_BASE =
        "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents"

    private val JSON = "application/json".toMediaType()

    private val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(25, TimeUnit.SECONDS)
            .build()
    }

    private fun auth(context: Context): String {
        val token = SessionManager.idToken(context)
        return if (token.isNotEmpty()) "Bearer $token" else ""
    }

    private fun headers(context: Context): Map<String, String> {
        val bearer = auth(context)
        return if (bearer.isEmpty()) emptyMap() else mapOf("Authorization" to bearer)
    }

    private fun docPath(context: Context, collection: String, docId: String): String {
        val uid = SessionManager.uid(context)
        return "$FIRESTORE_BASE/users/$uid/$collection/$docId"
    }

    private fun collectionPath(context: Context, collection: String): String {
        val uid = SessionManager.uid(context)
        return "$FIRESTORE_BASE/users/$uid/$collection"
    }

    private fun listPath(context: Context, collection: String): String =
        collectionPath(context, collection) + "?pageSize=300"

    // ─────────────────────────────────────────────────────────────────────────
    // HTTP helpers
    // ─────────────────────────────────────────────────────────────────────────

    private suspend fun getJson(url: String, context: Context): JSONObject? =
        withContext(Dispatchers.IO) {
            val builder = Request.Builder().url(url)
            headers(context).forEach { (k, v) -> builder.header(k, v) }
            client.newCall(builder.get().build()).execute().use { response ->
                if (!response.isSuccessful) return@use null
                val text = response.body?.string() ?: return@use null
                runCatching { JSONObject(text) }.getOrNull()
            }
        }

    private suspend fun patchJson(url: String, body: JSONObject, context: Context) {
        withContext(Dispatchers.IO) {
            val builder = Request.Builder().url(url)
            headers(context).forEach { (k, v) -> builder.header(k, v) }
            builder.header("Content-Type", "application/json")
            client.newCall(builder.patch(body.toString().toRequestBody(JSON)).build())
                .execute().use { }
        }
    }

    private suspend fun deleteJson(url: String, context: Context) {
        withContext(Dispatchers.IO) {
            val builder = Request.Builder().url(url)
            headers(context).forEach { (k, v) -> builder.header(k, v) }
            client.newCall(builder.delete().build()).execute().use { }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Field builders (Firestore REST value objects)
    // ─────────────────────────────────────────────────────────────────────────

    private fun string(value: String): JSONObject =
        JSONObject().put("stringValue", value)

    private fun boolean(value: Boolean): JSONObject =
        JSONObject().put("booleanValue", value)

    private fun integer(value: Long): JSONObject =
        JSONObject().put("integerValue", value.toString())

    private fun double(value: Double): JSONObject =
        JSONObject().put("doubleValue", value)

    private fun fields(vararg entries: Pair<String, JSONObject>): JSONObject {
        val obj = JSONObject()
        entries.forEach { (k, v) -> obj.put(k, v) }
        return JSONObject().put("fields", obj)
    }

    private fun updateMask(fieldNames: List<String>): String {
        val sb = StringBuilder()
        fieldNames.forEach { name ->
            if (sb.isNotEmpty()) sb.append('&')
            sb.append("updateMask.fieldPaths=").append(name)
        }
        return sb.toString()
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

    /** Pushes a watchlist entry to Firestore (upsert). */
    suspend fun pushWatchlist(context: Context, item: MediaItem) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || item.id == 0) return
        val key = watchlistKey(item.id.toString(), item.mediaType)
        val body = fields(
            "id" to string(item.id.toString()),
            "title" to string(item.title),
            "description" to string(item.overview),
            "thumbnail" to string(fullUrl(item.posterPath)),
            "backdrop" to string(fullUrl(item.backdropPath)),
            "videoUrl" to string(""),
            "trailerUrl" to string(""),
            "genres" to JSONObject().put("arrayValue", JSONObject().put("values", JSONArray())),
            "year" to string(item.releaseDate.take(4)),
            "rating" to double(item.voteAverage),
            "mediaType" to string(item.mediaType),
            "country" to string(""),
        )
        val names = listOf(
            "id", "title", "description", "thumbnail", "backdrop", "videoUrl",
            "trailerUrl", "genres", "year", "rating", "mediaType", "country",
        )
        val url = docPath(context, "watchlist", key) + "?" + updateMask(names)
        patchJson(url, body, context)
    }

    /** Deletes a watchlist entry from Firestore. */
    suspend fun deleteWatchlist(context: Context, id: String, mediaType: String) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || id.isEmpty()) return
        deleteJson(docPath(context, "watchlist", watchlistKey(id, mediaType)), context)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Watch progress
    // ─────────────────────────────────────────────────────────────────────────

    private fun watchHistoryKey(tmdbId: String, isMovie: Boolean, season: Int, episode: Int): String =
        if (isMovie) "movie_$tmdbId" else "tv_${tmdbId}_${season}_$episode"

    /** Pushes watch progress to Firestore (upsert). */
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
    ) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || tmdbId.isEmpty()) return
        val percentage = if (durationSeconds > 0)
            (positionSeconds.toDouble() / durationSeconds * 100).coerceIn(0.0, 100.0)
        else 0.0
        val body = fields(
            "tmdbId" to string(tmdbId),
            "title" to string(title),
            "isMovie" to boolean(isMovie),
            "season" to integer(season.toLong()),
            "episode" to integer(episode.toLong()),
            "posterUrl" to string(fullUrl(posterPath)),
            "position" to integer(positionSeconds),
            "duration" to integer(durationSeconds),
            "watchPercentage" to double(percentage),
            "isWatched" to boolean(percentage >= 90.0),
            "timestamp" to integer(System.currentTimeMillis()),
        )
        val names = listOf(
            "tmdbId", "title", "isMovie", "season", "episode", "posterUrl",
            "position", "duration", "watchPercentage", "isWatched", "timestamp",
        )
        val url = docPath(context, "watch_history", watchHistoryKey(tmdbId, isMovie, season, episode)) +
            "?" + updateMask(names)
        patchJson(url, body, context)
    }

    /** Deletes watch progress from Firestore. */
    suspend fun deleteWatchProgress(
        context: Context,
        tmdbId: String,
        isMovie: Boolean,
        season: Int,
        episode: Int,
    ) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || tmdbId.isEmpty()) return
        deleteJson(
            docPath(context, "watch_history", watchHistoryKey(tmdbId, isMovie, season, episode)),
            context,
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Pull (cloud → local)
    // ─────────────────────────────────────────────────────────────────────────

    private fun fieldsOf(doc: JSONObject): JSONObject =
        doc.optJSONObject("fields") ?: JSONObject()

    private fun str(fields: JSONObject, name: String): String =
        fields.optJSONObject(name)?.optString("stringValue") ?: ""

    private fun bool(fields: JSONObject, name: String): Boolean =
        fields.optJSONObject(name)?.optBoolean("booleanValue", false) ?: false

    private fun long(fields: JSONObject, name: String): Long =
        fields.optJSONObject(name)?.optString("integerValue")?.toLongOrNull()
            ?: fields.optJSONObject(name)?.optDouble("doubleValue", 0.0)?.toLong() ?: 0L

    private fun doubleVal(fields: JSONObject, name: String): Double =
        fields.optJSONObject(name)?.optDouble("doubleValue", 0.0)
            ?: fields.optJSONObject(name)?.optString("integerValue")?.toDoubleOrNull() ?: 0.0

    /** Pulls the signed-in user's cloud data into local storage. Safe to call
     * repeatedly; missing auth or network failure is silently ignored. */
    suspend fun pullToDevice(context: Context) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || auth(context).isEmpty()) return

        runCatching {
            val historyJson = getJson(listPath(context, "watch_history"), context)
            val historyDocs = historyJson?.optJSONArray("documents")
            if (historyDocs != null) {
                for (i in 0 until historyDocs.length()) {
                    val doc = historyDocs.optJSONObject(i) ?: continue
                    val f = fieldsOf(doc)
                    val tmdbId = str(f, "tmdbId")
                    if (tmdbId.isEmpty()) continue
                    val isMovie = bool(f, "isMovie")
                    val season = (long(f, "season").takeIf { it > 0 } ?: 1L).toInt()
                    val episode = (long(f, "episode").takeIf { it > 0 } ?: 1L).toInt()
                    val position = long(f, "position")
                    val duration = long(f, "duration")
                    if (position <= 0L) continue
                    val title = str(f, "title").ifBlank { tmdbId }
                    WatchProgressRepository.importCloudEntry(
                        context,
                        tmdbId = tmdbId,
                        title = title,
                        isMovie = isMovie,
                        season = season,
                        episode = episode,
                        positionSeconds = position,
                        durationSeconds = duration,
                        posterPath = str(f, "posterUrl"),
                        backdropPath = "",
                        timestamp = long(f, "timestamp"),
                    )
                }
            }
        }

        runCatching {
            val watchlistJson = getJson(listPath(context, "watchlist"), context)
            val watchlistDocs = watchlistJson?.optJSONArray("documents")
            if (watchlistDocs != null) {
                for (i in 0 until watchlistDocs.length()) {
                    val doc = watchlistDocs.optJSONObject(i) ?: continue
                    val f = fieldsOf(doc)
                    val id = str(f, "id")
                    if (id.isEmpty()) continue
                    val mediaType = str(f, "mediaType").ifBlank { "movie" }
                    val item = MediaItem(
                        id = id.toIntOrNull() ?: continue,
                        mediaType = mediaType,
                        title = str(f, "title").ifBlank { id },
                        overview = str(f, "description"),
                        posterPath = str(f, "thumbnail").ifBlank { null },
                        backdropPath = str(f, "backdrop").ifBlank { null },
                        releaseDate = str(f, "year"),
                        voteAverage = doubleVal(f, "rating"),
                        genreIds = emptyList(),
                    )
                    WatchlistRepository.add(context, item)
                }
            }
        }
    }
}