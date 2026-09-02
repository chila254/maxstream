package com.maxstream.app.data.local

import android.content.Context
import android.content.SharedPreferences

/**
 * Persists the lightweight TV session (no Firebase dependency required for the
 * native TV build; the Flutter phone app keeps its own auth). Mirrors the
 * Dart [TvAuthGate] routing: a non-empty session means we skip login.
 *
 * Also stores the Firebase Auth [uid] and [idToken] captured at sign-in so the
 * cloud-sync layer can call the Realtime Database REST API as the authenticated user.
 * The [refreshToken] is kept so the idToken can be renewed when it expires
 * (~1 hour) via the Auth REST securetoken endpoint, otherwise cloud sync would
 * silently die with 401/403s after an hour.
 */
object SessionManager {
    private const val PREFS = "maxstream_tv_session"
    private const val KEY_EMAIL = "email"
    private const val KEY_UID = "uid"
    private const val KEY_ID_TOKEN = "id_token"
    private const val KEY_REFRESH_TOKEN = "refresh_token"
    private const val KEY_TOKEN_ISSUED_AT = "token_issued_at"
    private const val KEY_LOGGED_IN = "logged_in"

    /** idToken issued at/after this epoch ms is treated as fresh (not expired). */
    private const val TOKEN_SKEW_MS = 5 * 60 * 1000L

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isLoggedIn(context: Context): Boolean = prefs(context).getBoolean(KEY_LOGGED_IN, false)

    fun email(context: Context): String = prefs(context).getString(KEY_EMAIL, "") ?: ""

    fun uid(context: Context): String = prefs(context).getString(KEY_UID, "") ?: ""

    fun idToken(context: Context): String = prefs(context).getString(KEY_ID_TOKEN, "") ?: ""

    fun refreshToken(context: Context): String = prefs(context).getString(KEY_REFRESH_TOKEN, "") ?: ""

    fun signIn(context: Context, email: String, uid: String, idToken: String, refreshToken: String = "") {
        prefs(context).edit()
            .putBoolean(KEY_LOGGED_IN, true)
            .putString(KEY_EMAIL, email)
            .putString(KEY_UID, uid)
            .putString(KEY_ID_TOKEN, idToken)
            .putString(KEY_REFRESH_TOKEN, refreshToken)
            .putLong(KEY_TOKEN_ISSUED_AT, System.currentTimeMillis())
            .apply()
    }

    /** Persists a refreshed idToken/refreshToken pair (from the Auth REST
     * securetoken endpoint), keeping the rest of the session intact. */
    fun updateTokens(context: Context, idToken: String, refreshToken: String) {
        prefs(context).edit()
            .putString(KEY_ID_TOKEN, idToken)
            .putString(KEY_REFRESH_TOKEN, refreshToken)
            .putLong(KEY_TOKEN_ISSUED_AT, System.currentTimeMillis())
            .apply()
    }

    /** True when the stored idToken is (probably) still valid: issued recently
     * enough that Firebase's ~1h expiry hasn't passed. Returns false when the
     * issued-at stamp is unknown or clearly stale. */
    fun idTokenExpired(context: Context): Boolean {
        val issuedAt = prefs(context).getLong(KEY_TOKEN_ISSUED_AT, 0L)
        if (issuedAt <= 0L) return true
        return System.currentTimeMillis() - issuedAt >= (60 * 60 * 1000L - TOKEN_SKEW_MS)
    }

    fun signOut(context: Context) {
        prefs(context).edit().clear().apply()
    }
}
