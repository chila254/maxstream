package com.maxstream.app.data.cloud

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.maxstream.app.core.AppConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject
import java.nio.file.Files
import java.nio.file.Paths
import java.util.concurrent.TimeUnit

data class UserProfile(
    val id: String,
    val name: String,
    val colorIndex: Int = 0,
    val iconCodePoint: Int = 0xe4ff,
    val isKids: Boolean = false,
    val createdAt: String = "",
)

/**
 * Desktop profile store under /users/{uid}/profiles/{profileId} — same RTDB
 * layout the mobile ProfileService uses, plus a locally-persisted active
 * profile id so the shell can restore who is watching.
 */
object ProfileStore {

    const val MAX_PROFILES = 5

    var profiles by mutableStateOf<List<UserProfile>>(emptyList())
        private set

    var activeProfileId by mutableStateOf<String?>(null)
        private set

    val activeProfile: UserProfile?
        get() = profiles.firstOrNull { it.id == activeProfileId } ?: profiles.firstOrNull()

    private val jsonType = "application/json; charset=utf-8"
    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    fun restoreLocal() {
        activeProfileId = try {
            val f = stateFile()
            if (Files.exists(f)) {
                val o = JSONObject(Files.readString(f))
                o.optString("activeProfileId").ifBlank { null }
            } else null
        } catch (_: Exception) {
            null
        }
    }

    suspend fun refresh(): List<UserProfile> = withContext(Dispatchers.IO) {
        val user = AppSession.user ?: return@withContext profiles
        val token = AppSession.freshToken() ?: return@withContext profiles
        runCatching {
            val url = "${AppConfig.FIREBASE_RTDB_URL}/users/${user.localId}/profiles.json?auth=$token"
            val request = Request.Builder().url(url).header("Accept", "application/json").build()
            http.newCall(request).execute().use { res ->
                if (!res.isSuccessful) return@runCatching profiles
                val body = res.body?.string().orEmpty()
                if (body.isBlank() || body == "null") return@runCatching profiles
                parseProfiles(JSONObject(body))
            }
        }.getOrDefault(profiles)
    }.also { list ->
        if (list.isNotEmpty()) {
            profiles = list
            if (activeProfileId == null || list.none { it.id == activeProfileId }) {
                setActive(list.first().id)
            }
        } else if (AppSession.isSignedIn && profiles.isEmpty()) {
            // Same first-run behavior as mobile ProfileService._createDefaultProfile.
            create(
                name = AppSession.user?.displayName?.ifBlank { null } ?: "Profile 1",
                colorIndex = 0,
                iconCodePoint = 0xe4ff,
            )
        }
    }

    suspend fun create(name: String, colorIndex: Int, iconCodePoint: Int, isKids: Boolean = false): UserProfile? =
        withContext(Dispatchers.IO) {
            val user = AppSession.user ?: return@withContext null
            val token = AppSession.freshToken() ?: return@withContext null
            if (profiles.size >= MAX_PROFILES) return@withContext null
            val id = "p_${System.currentTimeMillis()}_${(System.currentTimeMillis() % 100000).toString().padStart(5, '0')}"
            val profile = UserProfile(
                id = id,
                name = name.ifBlank { "Profile ${profiles.size + 1}" },
                colorIndex = colorIndex,
                iconCodePoint = iconCodePoint,
                isKids = isKids,
                createdAt = java.time.Instant.now().toString(),
            )
            val next = profiles + profile
            runCatching {
                val url = "${AppConfig.FIREBASE_RTDB_URL}/users/${user.localId}/profiles/$id.json?auth=$token"
                put(url, toJson(profile), token)
            }
            profiles = next
            if (activeProfileId == null) setActive(id)
            profile
        }

    fun setActive(id: String) {
        activeProfileId = id
        persistActive(id)
    }

    fun clear() {
        profiles = emptyList()
        activeProfileId = null
        try {
            Files.deleteIfExists(stateFile())
        } catch (_: Exception) {
        }
    }

    private fun parseProfiles(root: JSONObject): List<UserProfile> {
        val out = mutableListOf<UserProfile>()
        root.keys().forEach { key ->
            val o = root.optJSONObject(key) ?: return@forEach
            val avatar = o.optJSONObject("avatar")
            out += UserProfile(
                id = o.optString("id", key),
                name = o.optString("name", "Profile"),
                colorIndex = avatar?.optInt("colorIndex", 0) ?: 0,
                iconCodePoint = avatar?.optInt("iconCodePoint", 0xe4ff) ?: 0xe4ff,
                isKids = o.optBoolean("isKids", false),
                createdAt = o.optString("createdAt"),
            )
        }
        return out.sortedBy { it.createdAt }
    }

    private fun toJson(p: UserProfile): JSONObject = JSONObject()
        .put("id", p.id)
        .put("name", p.name)
        .put("isKids", p.isKids)
        .put("pinHash", JSONObject.NULL)
        .put("createdAt", p.createdAt)
        .put("avatar", JSONObject().put("colorIndex", p.colorIndex).put("iconCodePoint", p.iconCodePoint))

    private fun put(url: String, body: JSONObject, token: String) {
        val request = Request.Builder()
            .url(url)
            .put(body.toString().toRequestBody(jsonType.toMediaType()))
            .build()
        http.newCall(request).execute().close()
    }

    private fun persistActive(id: String) {
        try {
            val f = stateFile()
            Files.createDirectories(f.parent)
            Files.writeString(f, JSONObject().put("activeProfileId", id).toString())
        } catch (_: Exception) {
        }
    }

    private fun stateFile() =
        Paths.get(System.getProperty("user.home"), ".maxstream", "profile.json")
}
