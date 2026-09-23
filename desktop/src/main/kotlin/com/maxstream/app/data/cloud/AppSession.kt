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
        authRequest("accounts:signInWithPassword", email, password)

    suspend fun signUp(email: String, password: String): Result<FirebaseUser> =
        authRequest("accounts:signUp", email, password)

    suspend fun signOut() {
        user = null
        try {
            Files.deleteIfExists(sessionFile())
        } catch (_: Exception) {
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
                val res = post(AppConfig.FIREBASE_TOKEN_BASE, body)
                if (res.code / 100 == 2) {
                    JSONObject(res.body?.string().orEmpty())
                } else {
                    throw IllegalStateException("token refresh ${res.code}")
                }
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

    private suspend fun authRequest(endpoint: String, email: String, password: String): Result<FirebaseUser> =
        withContext(Dispatchers.IO) {
            runCatching {
                if (email.isBlank() || password.length < 6) {
                    throw IllegalArgumentException("Enter a valid email and a password of at least 6 characters.")
                }
                val body = JSONObject()
                    .put("email", email.trim())
                    .put("password", password)
                    .put("returnSecureToken", true)
                val url = "${AppConfig.FIREBASE_AUTH_BASE}/$endpoint?key=${AppConfig.FIREBASE_WEB_API_KEY}"
                val res = post(url, body)
                val text = res.body?.string().orEmpty()
                if (res.code / 100 != 2) {
                    val msg = JSONObject(text).optString("error").let { err ->
                        try {
                            JSONObject(err.toString()).optString("message", "Sign-in failed.")
                        } catch (_: Exception) {
                            "Sign-in failed (${res.code})."
                        }
                    }
                    throw IllegalArgumentException(msg)
                }
                val json = JSONObject(text)
                val now = System.currentTimeMillis()
                val u = FirebaseUser(
                    localId = json.optString("localId"),
                    email = json.optString("email"),
                    displayName = json.optString("displayName").ifBlank { null },
                    idToken = json.optString("idToken"),
                    refreshToken = json.optString("refreshToken"),
                    expiresAt = now + json.optLong("expiresIn", 3600L) * 1000L,
                )
                user = u
                persist(u)
                u
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