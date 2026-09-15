package com.maxstream.app.data.repository

import android.content.Context
import com.maxstream.app.data.local.ProfileData
import com.maxstream.app.data.local.ProfileScope
import com.maxstream.app.data.local.SessionManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Reads/writes profiles to Firebase RTDB via REST API.
 * Profiles live at `users/$uid/profiles/` — same path the Flutter phone app
 * writes to, so profiles created on phone auto-appear on TV and vice versa.
 *
 * No Firebase SDK needed — pure OkHttp + REST, matching CloudSyncRepository.
 */
object ProfileRepository {
    private const val PROJECT_ID = "maxstream-8effc"
    private const val RTDB_BASE = "https://$PROJECT_ID-default-rtdb.firebaseio.com"
    private val JSON = "application/json".toMediaType()

    private val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .build()
    }

    private fun rtdbUrl(path: String, context: Context): String {
        val token = SessionManager.idToken(context)
        val base = "$RTDB_BASE$path.json"
        return if (token.isNotEmpty()) "$base?auth=$token" else base
    }

    private suspend fun ensureFreshToken(context: Context) {
        if (SessionManager.idToken(context).isEmpty()) return
        AuthRepository.ensureFreshIdToken(context)
    }

    // ── Read ──────────────────────────────────────────────────────────

    /** Fetch all profiles from RTDB and cache locally. */
    suspend fun pullProfiles(context: Context): List<ProfileData> = withContext(Dispatchers.IO) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty()) return@withContext emptyList()

        ensureFreshToken(context)

        val path = "/users/$uid/profiles"
        val request = Request.Builder().url(rtdbUrl(path, context)).get().build()

        try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@withContext ProfileScope.getCachedProfiles(context)

                val text = response.body?.string()
                if (text.isNullOrBlank() || text == "null") return@withContext emptyList()

                val data = JSONObject(text)
                val profiles = data.keys().asSequence().map { key ->
                    ProfileData.fromJson(data.getJSONObject(key))
                }.toList()

                ProfileScope.cacheProfiles(context, profiles)
                profiles
            }
        } catch (e: Exception) {
            // Fall back to cache on network error
            ProfileScope.getCachedProfiles(context)
        }
    }

    /** Push a full profile list to RTDB (replaces all profiles). */
    suspend fun pushProfiles(context: Context, profiles: List<ProfileData>) = withContext(Dispatchers.IO) {
        val uid = SessionManager.uid(context)
        if (uid.isEmpty()) return@withContext

        ensureFreshToken(context)

        val path = "/users/$uid/profiles"
        val body = JSONObject().apply {
            profiles.forEach { put(it.id, it.toJson()) }
        }.toString()

        val request = Request.Builder()
            .url(rtdbUrl(path, context))
            .put(body.toRequestBody(JSON))
            .build()

        try {
            client.newCall(request).execute().close()
        } catch (_: Exception) { }

        ProfileScope.cacheProfiles(context, profiles)
    }

    /** Create a new profile and push to cloud. */
    suspend fun createProfile(
        context: Context,
        name: String,
        colorIndex: Int = 0,
        iconCodePoint: Int = 0xe4ff,
        isKids: Boolean = false,
    ): ProfileData? {
        val existing = ProfileScope.getCachedProfiles(context)
        if (existing.size >= 5) return null

        val id = "p_${System.currentTimeMillis()}_${(System.currentTimeMillis() % 100000).toString().padStart(5, '0')}"
        val profile = ProfileData(
            id = id,
            name = name,
            colorIndex = colorIndex,
            iconCodePoint = iconCodePoint,
            isKids = isKids,
        )

        val updated = existing + profile
        pushProfiles(context, updated)
        return profile
    }

    /** Delete a profile by ID and push to cloud. */
    suspend fun deleteProfile(context: Context, profileId: String): Boolean {
        val existing = ProfileScope.getCachedProfiles(context)
        if (existing.size <= 1) return false

        val updated = existing.filter { it.id != profileId }
        pushProfiles(context, updated)

        if (ProfileScope.activeProfileId(context) == profileId) {
            ProfileScope.setActiveProfileId(context, updated.first().id)
        }
        return true
    }
}
