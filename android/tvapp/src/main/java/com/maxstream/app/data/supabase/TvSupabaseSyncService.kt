package com.maxstream.app.data.supabase

import android.content.Context
import android.util.Log
import com.maxstream.app.BuildConfig
import com.maxstream.app.data.local.SessionManager
import com.maxstream.app.data.local.WatchProgressRepository
import com.maxstream.app.data.local.WatchlistRepository
import com.maxstream.app.data.model.MediaItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Full Supabase sync for TV (mirrors mobile SupabaseSyncService).
 * Uses Firebase UID as user_id (same as mobile) so phone+TV sync together
 * via same Postgres tables (watch_history, watchlist, provider_preferences).
 * REST via PostgREST, Realtime via polling (CloudSyncCoordinator already polls every 10s).
 * Falls back to no-op if SUPABASE_URL is placeholder.
 */
object TvSupabaseSyncService {
    private const val TAG = "TvSupabaseSync"
    private val JSON = "application/json".toMediaType()
    private val client: OkHttpClient by lazy {
        OkHttpClient.Builder().connectTimeout(15, TimeUnit.SECONDS).readTimeout(25, TimeUnit.SECONDS).build()
    }
    fun isConfigured(): Boolean {
        val url = BuildConfig.SUPABASE_URL
        val key = BuildConfig.SUPABASE_ANON_KEY
        return url.contains("supabase.co") && key.isNotBlank() && !key.contains("YOUR_ANON")
    }
    private fun baseUrl(): String = BuildConfig.SUPABASE_URL.trimEnd('/')
    private fun anonKey(): String = BuildConfig.SUPABASE_ANON_KEY
    private fun authHeaders(): Map<String, String> = mapOf(
        "apikey" to anonKey(),
        "Authorization" to "Bearer ${anonKey()}",
        "Content-Type" to "application/json",
        "Prefer" to "resolution=merge-duplicates"
    )
    private fun Request.Builder.headersToBuilder(map: Map<String, String>): Request.Builder {
        map.forEach { (k, v) -> header(k, v) }
        return this
    }

    fun pushWatchProgress(
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
        if (!isConfigured()) return
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || tmdbId.isEmpty()) return
        // Launch in background so callers (WatchProgressRepository.saveProgress) don't need to be suspend
        kotlinx.coroutines.GlobalScope.launch(Dispatchers.IO) {
            val body = JSONObject().apply {
                put("user_id", uid)
                put("tmdb_id", tmdbId)
                put("is_movie", isMovie)
                put("season", season)
                put("episode", episode)
                put("title", title)
                put("poster_url", posterPath)
                put("position_seconds", positionSeconds)
                put("duration_seconds", durationSeconds)
                put("updated_at", java.time.Instant.now().toString())
            }
            val url = "${baseUrl()}/rest/v1/watch_history"
            val req = Request.Builder().url(url).headersToBuilder(authHeaders()).post(body.toString().toRequestBody(JSON)).build()
            try { client.newCall(req).execute().use {} } catch (e: Exception) { Log.w(TAG, "pushHistory failed: ${e.message}") }
        }
    }

    suspend fun pushWatchlist(context: Context, item: MediaItem) {
        if (!isConfigured()) return
        val uid = SessionManager.uid(context)
        if (uid.isEmpty() || item.id == 0) return
        val body = JSONObject().apply {
            put("user_id", uid)
            put("id", item.id.toString())
            put("media_type", item.mediaType)
            put("title", item.title)
            put("description", item.overview)
            put("thumbnail", item.posterPath ?: "")
            put("backdrop", item.backdropPath ?: "")
            put("year", item.releaseDate.take(4))
            put("rating", item.voteAverage)
            put("updated_at", java.time.Instant.now().toString())
        }
        val url = "${baseUrl()}/rest/v1/watchlist"
        val req = Request.Builder().url(url).headersToBuilder(authHeaders()).post(body.toString().toRequestBody(JSON)).build()
        try { withContext(Dispatchers.IO) { client.newCall(req).execute().use {} } } catch (e: Exception) { Log.w(TAG, "pushWatchlist failed: ${e.message}") }
    }

    suspend fun pullToDevice(context: Context) {
        if (!isConfigured()) return
        val uid = SessionManager.uid(context)
        if (uid.isEmpty()) return
        runCatching {
            val url = "${baseUrl()}/rest/v1/watch_history?user_id=eq.$uid&select=*"
            val req = Request.Builder().url(url).headersToBuilder(authHeaders()).get().build()
            withContext(Dispatchers.IO) {
                client.newCall(req).execute().use { resp ->
                    if (!resp.isSuccessful) return@use
                    val arr = JSONArray(resp.body?.string() ?: "[]")
                    for (i in 0 until arr.length()) {
                        val obj = arr.optJSONObject(i) ?: continue
                        val tmdbId = obj.optString("tmdb_id", "")
                        if (tmdbId.isEmpty()) continue
                        WatchProgressRepository.importCloudEntry(
                            context,
                            tmdbId = tmdbId,
                            title = obj.optString("title", tmdbId),
                            isMovie = obj.optBoolean("is_movie", false),
                            season = obj.optInt("season", 1),
                            episode = obj.optInt("episode", 1),
                            positionSeconds = obj.optLong("position_seconds", 0),
                            durationSeconds = obj.optLong("duration_seconds", 0),
                            posterPath = obj.optString("poster_url", ""),
                            backdropPath = "",
                            timestamp = try { java.time.Instant.parse(obj.optString("updated_at", "")).toEpochMilli() } catch (_: Exception) { System.currentTimeMillis() },
                            seriesTitle = "",
                            episodeName = "",
                            isWatched = false
                        )
                    }
                }
            }
        }
        runCatching {
            val url = "${baseUrl()}/rest/v1/watchlist?user_id=eq.$uid&select=*"
            val req = Request.Builder().url(url).headersToBuilder(authHeaders()).get().build()
            withContext(Dispatchers.IO) {
                client.newCall(req).execute().use { resp ->
                    if (!resp.isSuccessful) return@use
                    val arr = JSONArray(resp.body?.string() ?: "[]")
                    for (i in 0 until arr.length()) {
                        val obj = arr.optJSONObject(i) ?: continue
                        val id = obj.optString("id", "")
                        if (id.isEmpty()) continue
                        val item = MediaItem(
                            id = id.toIntOrNull() ?: continue,
                            mediaType = obj.optString("media_type", "movie"),
                            title = obj.optString("title", id),
                            overview = obj.optString("description", ""),
                            posterPath = obj.optString("thumbnail", "").ifBlank { null },
                            backdropPath = obj.optString("backdrop", "").ifBlank { null },
                            releaseDate = obj.optString("year", ""),
                            voteAverage = obj.optDouble("rating", 0.0),
                            genreIds = emptyList()
                        )
                        WatchlistRepository.add(context, item)
                    }
                }
            }
        }
    }

    suspend fun pushEntireHistory(context: Context) {
        if (!isConfigured()) return
        val uid = SessionManager.uid(context)
        if (uid.isEmpty()) return
        val recent = WatchProgressRepository.recent(context, limit = 100)
        for (entry in recent) {
            pushWatchProgress(
                context = context,
                tmdbId = entry.tmdbId,
                title = entry.title,
                isMovie = entry.isMovie,
                season = entry.season,
                episode = entry.episode,
                positionSeconds = entry.positionSeconds,
                durationSeconds = entry.durationSeconds,
                posterPath = entry.posterPath,
            )
        }
    }
}
