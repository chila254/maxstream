package com.maxstream.app.data.repository

import android.content.Context
import com.maxstream.app.data.local.SessionManager
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * Authentication for the native TV build, backed by the same Firebase project
 * the phone app uses (project maxstream-8effc). The TV APK intentionally does
 * not bundle the Firebase SDK or google-services.json, so auth goes over the
 * public Firebase REST APIs using OkHttp/Gson.
 *
 * Device-code pairing uses Firebase Realtime Database (RTDB) REST API instead
 * of Firestore to avoid Firestore daily usage limits.
 *
 * Flow:
 *  - Device Code: read the code from RTDB `device_codes/{code}`, burn it
 *    (isUsed -> true), then sign in directly with the embedded email and
 *    password via the Auth REST signInWithPassword endpoint.
 *  - Sign In / Sign Up: email + password against the Auth REST endpoints.
 *  - A successful auth persists a lightweight session via [SessionManager] so
 *    subsequent launches skip the login screen.
 */
object AuthRepository {
    private const val PROJECT_ID = "maxstream-8effc"
    private const val API_KEY = "AIzaSyAiNjTADd8kA3qi3Dgnvlyo1Vf347QnsYk"

    private const val AUTH_BASE = "https://identitytoolkit.googleapis.com/v1/accounts"
    private const val RTDB_BASE =
        "https://$PROJECT_ID-default-rtdb.firebaseio.com"

    private val JSON = "application/json".toMediaType()

    private val gson = Gson()

    private val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(25, TimeUnit.SECONDS)
            .build()
    }

    private suspend fun postJson(url: String, body: JsonObject): JsonObject? =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url(url)
                .post(body.toString().toRequestBody(JSON))
                .build()
            client.newCall(request).execute().use { response ->
                val text = response.body?.string() ?: return@use null
                runCatching { gson.fromJson(text, JsonObject::class.java) }.getOrNull()
            }
        }

    private suspend fun getJson(url: String): JsonObject? =
        withContext(Dispatchers.IO) {
            val request = Request.Builder().url(url).get().build()
            client.newCall(request).execute().use { response ->
                val text = response.body?.string() ?: return@use null
                if (text == "null" || text.isBlank()) return@use null
                runCatching { gson.fromJson(text, JsonObject::class.java) }.getOrNull()
            }
        }

    private suspend fun patchJson(url: String, body: JsonObject): JsonObject? =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url(url)
                .patch(body.toString().toRequestBody(JSON))
                .build()
            client.newCall(request).execute().use { response ->
                val text = response.body?.string() ?: return@use null
                runCatching { gson.fromJson(text, JsonObject::class.java) }.getOrNull()
            }
        }

    private fun authError(json: JsonObject?): String {
        val message = json
            ?.getAsJsonObject("error")
            ?.get("message")
            ?.asString
            ?: return "Authentication failed. Check your connection."
        return when {
            message.contains("EMAIL_NOT_FOUND") || message.contains("INVALID_LOGIN_CREDENTIALS") ||
                message.contains("INVALID_PASSWORD") -> "Incorrect email or password"
            message.contains("EMAIL_EXISTS") -> "An account already exists with this email"
            message.contains("WEAK_PASSWORD") -> "Password is too weak (min 6 characters)"
            message.contains("INVALID_EMAIL") -> "Invalid email format"
            message.contains("USER_DISABLED") -> "This account has been disabled"
            message.contains("TOO_MANY_ATTEMPTS_TRY_LATER") -> "Too many attempts. Try again later"
            else -> message
        }
    }

    /**
     * Extracts the Firebase Auth session fields (uid + idToken + refreshToken)
     * from an Auth REST response.
     */
    private fun sessionFrom(auth: JsonObject, email: String): Session {
        val uid = auth.get("localId")?.asString.orEmpty()
        val idToken = auth.get("idToken")?.asString.orEmpty()
        val refreshToken = auth.get("refreshToken")?.asString.orEmpty()
        return Session(email = email, uid = uid, idToken = idToken, refreshToken = refreshToken)
    }

    /**
     * Renews the Firebase ID token via the Auth REST securetoken endpoint.
     * ID tokens expire after ~1 hour. Returns the new token on success, null on failure.
     */
    suspend fun refreshIdToken(context: Context): String? {
        val refreshToken = SessionManager.refreshToken(context)
        if (refreshToken.isEmpty()) return null
        return try {
            val body = JsonObject().apply {
                addProperty("grant_type", "refresh_token")
                addProperty("refresh_token", refreshToken)
            }
            val response = postJson("https://securetoken.googleapis.com/v1/token?key=$API_KEY", body)
                ?: return null
            if (response.has("error")) return null
            val idToken = response.get("id_token")?.asString.orEmpty()
            val newRefreshToken = response.get("refresh_token")?.asString.orEmpty()
            if (idToken.isEmpty()) return null
            SessionManager.updateTokens(context, idToken, newRefreshToken)
            idToken
        } catch (e: Exception) {
            null
        }
    }

    /** Ensures a fresh idToken is stored, refreshing it if it has expired. */
    suspend fun ensureFreshIdToken(context: Context): String {
        val current = SessionManager.idToken(context)
        if (current.isNotEmpty() && !SessionManager.idTokenExpired(context)) return current
        return refreshIdToken(context) ?: current
    }

    /**
     * Reads a device code from RTDB, burns it, and signs the linked user
     * in directly using the email + password carried by the code.
     */
    suspend fun authenticateWithDeviceCode(code: String): Result<Session> {
        if (code.isBlank()) return Result.failure(IllegalArgumentException("Enter your code"))
        val clean = code.trim()
        val digits = clean.filter { it.isDigit() }
        if (digits.length != 6) return Result.failure(
            IllegalArgumentException("Code must be 6 digits"),
        )
        val encoded = java.net.URLEncoder.encode(digits, "UTF-8")
        return try {
            val doc = getJson("$RTDB_BASE/device_codes/$encoded.json")
                ?: return Result.failure(Exception(
                    "Cannot reach MaxStream servers. Check your internet connection.",
                ))

            // RTDB returns plain JSON object with fields directly (no "fields" wrapper)
            val email = doc.get("email")?.asString.orEmpty()
            val password = doc.get("password")?.asString.orEmpty()
            if (email.isBlank()) {
                return Result.failure(Exception(
                    "Code not found. Check the code and try again, "
                        + "or generate a new code on your phone.",
                ))
            }
            if (password.isBlank()) {
                return Result.failure(Exception(
                    "This code has no credentials. Sign in with your email "
                        + "and password instead, or generate a new code from "
                        + "a phone that signed in with email/password.",
                ))
            }

            val isUsed = doc.get("isUsed")?.asBoolean ?: false
            if (isUsed) return Result.failure(Exception(
                "Code already used. Generate a new code on your phone.",
            ))

            // Check expiry: RTDB stores as epoch millis (number)
            val expiresAt = doc.get("expiresAt")?.asLong
            if (expiresAt != null && System.currentTimeMillis() > expiresAt) {
                return Result.failure(Exception(
                    "Code expired. Generate a new code on your phone.",
                ))
            }

            // Burn the code so it can never be reused.
            val burnBody = JsonObject().apply {
                addProperty("isUsed", true)
            }
            val burnUrl = "$RTDB_BASE/device_codes/$encoded.json"
            runCatching { patchJson(burnUrl, burnBody) }

            // Sign in directly with the credentials the code carries.
            val signInBody = JsonObject().apply {
                addProperty("email", email)
                addProperty("password", password)
                addProperty("returnSecureToken", true)
            }
            val auth = postJson("$AUTH_BASE:signInWithPassword?key=$API_KEY", signInBody)
                ?: return Result.failure(Exception("Failed to sign in. Check your connection."))
            if (auth.has("error")) return Result.failure(Exception(authError(auth)))

            Result.success(sessionFrom(auth, email))
        } catch (e: Exception) {
            if (e is IllegalStateException || e is java.io.IOException) {
                Result.failure(Exception("Failed to connect. Check your connection."))
            } else {
                Result.failure(e)
            }
        }
    }

    suspend fun signInWithEmail(email: String, password: String): Result<Session> {
        if (email.isBlank() || password.isBlank()) {
            return Result.failure(IllegalArgumentException("Enter your email and password"))
        }
        return try {
            val body = JsonObject().apply {
                addProperty("email", email.trim())
                addProperty("password", password)
                addProperty("returnSecureToken", true)
            }
            val auth = postJson("$AUTH_BASE:signInWithPassword?key=$API_KEY", body)
                ?: return Result.failure(Exception("Failed to sign in. Check your connection."))
            if (auth.has("error")) return Result.failure(Exception(authError(auth)))
            Result.success(sessionFrom(auth, email.trim()))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun signUpWithEmail(email: String, password: String): Result<Session> {
        if (email.isBlank() || password.length < 6) {
            return Result.failure(IllegalArgumentException("Invalid email or password (min 6 characters)"))
        }
        return try {
            val body = JsonObject().apply {
                addProperty("email", email.trim())
                addProperty("password", password)
                addProperty("returnSecureToken", true)
            }
            val auth = postJson("$AUTH_BASE:signUp?key=$API_KEY", body)
                ?: return Result.failure(Exception("Failed to create account. Check your connection."))
            if (auth.has("error")) return Result.failure(Exception(authError(auth)))
            Result.success(sessionFrom(auth, email.trim()))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun completeSignIn(context: Context, session: Session) {
        SessionManager.signIn(
            context,
            session.email,
            session.uid,
            session.idToken,
            session.refreshToken,
        )
    }

    fun signOut(context: Context) = SessionManager.signOut(context)

    data class Session(
        val email: String,
        val uid: String,
        val idToken: String,
        val refreshToken: String = "",
    )
}
