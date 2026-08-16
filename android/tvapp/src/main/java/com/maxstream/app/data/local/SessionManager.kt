package com.maxstream.app.data.local

import android.content.Context
import android.content.SharedPreferences

/**
 * Persists the lightweight TV session (no Firebase dependency required for the
 * native TV build; the Flutter phone app keeps its own auth). Mirrors the
 * Dart [TvAuthGate] routing: a non-empty session means we skip login.
 *
 * Also stores the Firebase Auth [uid] and [idToken] captured at sign-in so the
 * cloud-sync layer can call the Firestore REST API as the authenticated user.
 */
object SessionManager {
    private const val PREFS = "maxstream_tv_session"
    private const val KEY_EMAIL = "email"
    private const val KEY_UID = "uid"
    private const val KEY_ID_TOKEN = "id_token"
    private const val KEY_LOGGED_IN = "logged_in"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isLoggedIn(context: Context): Boolean = prefs(context).getBoolean(KEY_LOGGED_IN, false)

    fun email(context: Context): String = prefs(context).getString(KEY_EMAIL, "") ?: ""

    fun uid(context: Context): String = prefs(context).getString(KEY_UID, "") ?: ""

    fun idToken(context: Context): String = prefs(context).getString(KEY_ID_TOKEN, "") ?: ""

    fun signIn(context: Context, email: String, uid: String, idToken: String) {
        prefs(context).edit()
            .putBoolean(KEY_LOGGED_IN, true)
            .putString(KEY_EMAIL, email)
            .putString(KEY_UID, uid)
            .putString(KEY_ID_TOKEN, idToken)
            .apply()
    }

    fun signOut(context: Context) {
        prefs(context).edit().clear().apply()
    }
}