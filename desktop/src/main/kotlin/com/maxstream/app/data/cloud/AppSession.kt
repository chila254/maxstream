package com.maxstream.app.data.cloud

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.maxstream.app.core.AppConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.nio.file.Files
import java.nio.file.Paths
import java.util.concurrent.TimeUnit

/** A signed-in Firebase user (based on the TV app's AuthRepository session). */
data class FirebaseUser(
    val localId: String,
    val email: String,
    val displayName: String?,
    val idToken: String,
    val refreshToken: String,
    val expiresAt: Long,
)

/**
 * Firebase Auth session for the desktop client. Sign in/up via the Auth REST
 * API, token refresh via securetoken, and a locally-persisted session so the
 * app remembers who is signed in between launches. UI observes [user].
 */
object AppSession {

    var user by mutableStateOf<FirebaseUser?>(null)
        private set

    val isSignedIn: Boolean get() = user != null

    private const val JSON = "application/json; charset=utf-8"
    private val jsonType = JSON.toMediaType()

    private val http = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    /** Loads the persisted session (fast, local) — call once at app start. */
    fun restore() {
        user = try {
            val f = sessionFile()
            if (Files.exists(f)) {
                val o = JSONObject(Files.readString(f))
                FirebaseUser(
                    localId = o.getString("localId"),
                    email = o.getString("email"),
                    displayName = o.optString("displayName").ifBlank { null },
                    idToken = o.getString("idToken"),
                    refreshToken = o.getString("refreshToken"),
                    expiresAt = o.getLong("expiresAt"),
                )
            } else null
        } catch (_: Exception) {
            null
        }
    }

    suspend fun signIn(email: String, password: String): Result<FirebaseUser> =
        authRequest("signInWithPassword", email, password)

    suspend fun signUp(email: String, password: String): Result<FirebaseUser> =
        authRequest("signUp", email, password)

    suspend fun signOut() {
        user = null
        try {
            Files.deleteIfExists(sessionFile())
        } catch (_: Exception) {
        }
    }

    /**
     * Sends a Firebase password-reset email (mobile AuthService.resetPassword).
     * POST {AUTH_BASE}:sendOobEmail with requestType PASSWORD_RESET.
     */
    suspend fun sendPasswordReset(email: String): Result<Unit> =
        withContext(Dispatchers.IO) {
            runCatching {
                if (email.isBlank() || !email.contains("@")) {
                    throw IllegalArgumentException("Enter a valid email address")
                }
                val body = JSONObject()
                    .put("requestType", "PASSWORD_RESET")
                    .put("email", email.trim())
                val url = "${AppConfig.FIREBASE_AUTH_BASE}:sendOobEmail?key=${AppConfig.FIREBASE_WEB_API_KEY}"
                val (code, text) = post(url, body).use { r ->
                    r.code to (r.body?.string().orEmpty())
                }
                if (code / 100 != 2) {
                    throw IllegalArgumentException(firebaseErrorMessage(code, text, "Could not send reset email"))
                }
            }
        }

    /** Returns a valid idToken, refreshing if near/expired. */
    suspend fun freshToken(): String? {
        val u = user ?: return null
        if (System.currentTimeMillis() < u.expiresAt - 30_000L) return u.idToken
        return withContext(Dispatchers.IO) {
            runCatching {
                val body = JSONObject()
                    .put("grant_type", "refresh_token")
                    .put("refresh_token", u.refreshToken)
                val res = post(AppConfig.FIREBASE_TOKEN_BASE, body).use { r ->
                    r.code to (r.body?.string().orEmpty())
                }
                val (code, text) = res
                if (code / 100 != 2) {
                    throw IllegalStateException(firebaseErrorMessage(code, text, "Token refresh failed"))
                }
                parseJsonObject(text, code, "Token refresh failed")
            }.getOrNull()?.let { json ->
                val now = System.currentTimeMillis()
                val renewed = u.copy(
                    idToken = json.optString("access_token").ifBlank { u.idToken },
                    refreshToken = json.optString("refresh_token").ifBlank { u.refreshToken },
                    expiresAt = now + json.optLong("expires_in", 3600L) * 1000L,
                )
                user = renewed
                persist(renewed)
                renewed.idToken
            }
        }
    }

    /**
     * Firebase Auth REST: POST {AUTH_BASE}:{action} — e.g.
     * .../v1/accounts:signInWithPassword (same as the TV AuthRepository).
     */
    private suspend fun authRequest(action: String, email: String, password: String): Result<FirebaseUser> =
        withContext(Dispatchers.IO) {
            runCatching {
                if (email.isBlank() || password.length < 6) {
                    throw IllegalArgumentException("Enter a valid email and a password of at least 6 characters.")
                }
                val body = JSONObject()
                    .put("email", email.trim())
                    .put("password", password)
                    .put("returnSecureToken", true)
                val url = "${AppConfig.FIREBASE_AUTH_BASE}:$action?key=${AppConfig.FIREBASE_WEB_API_KEY}"
                val (code, text) = post(url, body).use { r ->
                    r.code to (r.body?.string().orEmpty())
                }
                val json = if (code / 100 == 2) {
                    parseJsonObject(text, code, "Sign-in failed")
                } else {
                    throw IllegalArgumentException(firebaseErrorMessage(code, text, "Sign-in failed"))
                }
                val localId = json.optString("localId")
                val idToken = json.optString("idToken")
                val refreshToken = json.optString("refreshToken")
                if (localId.isBlank() || idToken.isBlank()) {
                    throw IllegalArgumentException("Sign-in failed: the server did not return a session.")
                }
                val now = System.currentTimeMillis()
                val u = FirebaseUser(
                    localId = localId,
                    email = json.optString("email").ifBlank { email.trim() },
                    displayName = json.optString("displayName").ifBlank { null },
                    idToken = idToken,
                    refreshToken = refreshToken,
                    expiresAt = now + json.optLong("expiresIn", 3600L) * 1000L,
                )
                user = u
                persist(u)
                u
            }.onFailure { e ->
                // Never surface raw org.json parse failures to the UI.
                if (e is org.json.JSONException) {
                    throw IllegalArgumentException(
                        e.message
                            ?.takeIf { it.startsWith("A JSON") }
                            ?.let { "Could not read the sign-in response. Check your connection and try again." }
                            ?: "Sign-in failed. Check your connection and try again.",
                    )
                }
            }
        }

    /** Strips BOM/whitespace and parses a JSON object, or throws a friendly error. */
    private fun parseJsonObject(raw: String, code: Int, fallback: String): JSONObject {
        val text = raw
            .removePrefix("﻿")
            .trim()
            .removePrefix("<!DOCTYPE")
            .removePrefix("<html")
        if (text.isEmpty() || !text.startsWith("{")) {
            throw IllegalArgumentException(
                if (code / 100 == 2) "$fallback. Check your connection and try again."
                else "$fallback (HTTP $code).",
            )
        }
        return try {
            JSONObject(text)
        } catch (e: org.json.JSONException) {
            throw IllegalArgumentException("$fallback. Check your connection and try again.")
        }
    }

    /** Maps Firebase Auth REST error payloads to human-readable messages. */
    private fun firebaseErrorMessage(code: Int, text: String, fallback: String): String {
        val message = runCatching {
            JSONObject(text.removePrefix("﻿").trim())
                .optJSONObject("error")
                ?.optString("message")
                .orEmpty()
        }.getOrDefault("")
        if (message.isBlank()) {
            return if (code == 404) "$fallback: service unavailable (HTTP 404)."
            else "$fallback (HTTP $code)."
        }
        return when {
            message.contains("EMAIL_NOT_FOUND") ||
                message.contains("INVALID_LOGIN_CREDENTIALS") ||
                message.contains("INVALID_PASSWORD") ||
                message.contains("INVALID_IDP_RESPONSE") -> "Incorrect email or password"
            message.contains("EMAIL_EXISTS") -> "An account already exists with this email"
            message.contains("WEAK_PASSWORD") -> "Password is too weak (min 6 characters)"
            message.contains("INVALID_EMAIL") || message.contains("MISSING_EMAIL") -> "Enter a valid email address"
            message.contains("MISSING_PASSWORD") -> "Enter your password"
            message.contains("USER_DISABLED") -> "This account has been disabled"
            message.contains("TOO_MANY_ATTEMPTS_TRY_LATER") -> "Too many attempts. Try again later"
            message.contains("OPERATION_NOT_ALLOWED") -> "Email/password sign-in is disabled for this project"
            message.contains("API_KEY_INVALID") -> "Invalid Firebase API key. Contact support."
            else -> message
        }
    }

    private fun post(url: String, body: JSONObject): okhttp3.Response {
        val request = Request.Builder()
            .url(url)
            .header("Content-Type", "application/json")
            .post(body.toString().toRequestBody(jsonType))
            .build()
        return http.newCall(request).execute()
    }

    private fun persist(u: FirebaseUser) {
        try {
            Files.createDirectories(sessionFile().parent)
            Files.writeString(
                sessionFile(),
                JSONObject()
                    .put("localId", u.localId)
                    .put("email", u.email)
                    .put("displayName", u.displayName ?: "")
                    .put("idToken", u.idToken)
                    .put("refreshToken", u.refreshToken)
                    .put("expiresAt", u.expiresAt)
                    .toString(),
            )
        } catch (_: Exception) {
        }
    }

    private fun sessionFile() = Paths.get(System.getProperty("user.home"), ".maxstream", "session.json")
}