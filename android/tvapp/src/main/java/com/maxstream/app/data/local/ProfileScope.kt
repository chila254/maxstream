package com.maxstream.app.data.local

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Manages the currently active profile on the TV.
 * Mirrors Flutter's ProfileScope — stores the active profile ID in
 * SharedPreferences and provides it for per-profile data isolation.
 *
 * Profiles themselves live in Firebase RTDB at `users/$uid/profiles/`
 * and are synced via [ProfileRepository]. This class only tracks which
 * profile is currently selected.
 */
object ProfileScope {
    private const val PREFS = "maxstream_tv_profiles"
    private const val KEY_ACTIVE_PROFILE_ID = "active_profile_id"
    private const val KEY_PROFILES_JSON = "profiles_json"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ── Active profile ────────────────────────────────────────────────

    /** The currently active profile ID, or empty if none selected. */
    fun activeProfileId(context: Context): String =
        prefs(context).getString(KEY_ACTIVE_PROFILE_ID, "") ?: ""

    fun setActiveProfileId(context: Context, id: String) {
        prefs(context).edit().putString(KEY_ACTIVE_PROFILE_ID, id).apply()
    }

    fun clearActiveProfile(context: Context) {
        prefs(context).edit().remove(KEY_ACTIVE_PROFILE_ID).apply()
    }

    /** Whether a profile has been selected this session. */
    fun hasSelectedProfile(context: Context): Boolean =
        activeProfileId(context).isNotEmpty()

    // ── Profile list cache ────────────────────────────────────────────

    /** Cached profiles from the last cloud pull (avoids blocking the UI). */
    fun getCachedProfiles(context: Context): List<ProfileData> {
        val raw = prefs(context).getString(KEY_PROFILES_JSON, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { ProfileData.fromJson(arr.getJSONObject(it)) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun cacheProfiles(context: Context, profiles: List<ProfileData>) {
        val arr = JSONArray()
        profiles.forEach { arr.put(it.toJson()) }
        prefs(context).edit().putString(KEY_PROFILES_JSON, arr.toString()).apply()
    }

    /** Returns true if profile selection can be skipped (only 1 profile). */
    fun canSkipSelection(context: Context): Boolean =
        getCachedProfiles(context).size <= 1

    /** Select the single profile automatically if there's only one. */
    fun autoSelectIfSingle(context: Context): Boolean {
        val profiles = getCachedProfiles(context)
        if (profiles.size == 1) {
            setActiveProfileId(context, profiles.first().id)
            return true
        }
        return false
    }

    fun clearAll(context: Context) {
        prefs(context).edit().clear().apply()
    }
}

/**
 * Simple profile data class for the TV app.
 * Matches the Flutter Profile model's JSON format for cross-device sync.
 */
data class ProfileData(
    val id: String,
    val name: String,
    val colorIndex: Int = 0,
    val iconCodePoint: Int = 0xe4ff, // Icons.person
    val isKids: Boolean = false,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("name", name)
        put("avatar", JSONObject().apply {
            put("colorIndex", colorIndex)
            put("iconCodePoint", iconCodePoint)
        })
        put("isKids", isKids)
    }

    companion object {
        private const val DEFAULT_ICON = 0xe4ff // Icons.person

        fun fromJson(json: JSONObject): ProfileData {
            val avatar = json.optJSONObject("avatar")
            return ProfileData(
                id = json.getString("id"),
                name = json.optString("name", "Profile"),
                colorIndex = avatar?.optInt("colorIndex", 0) ?: 0,
                iconCodePoint = avatar?.optInt("iconCodePoint", DEFAULT_ICON) ?: DEFAULT_ICON,
                isKids = json.optBoolean("isKids", false),
            )
        }
    }
}
