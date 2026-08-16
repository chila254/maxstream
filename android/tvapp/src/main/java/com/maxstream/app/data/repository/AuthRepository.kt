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
 * public Firebase REST APIs (Auth REST + Firestore REST) using OkHttp/Gson,
 * which are already on the classpath.
 *
 * Flow:
 *  - Device Code: read the code doc from Firestore `device_codes/{code}`, burn
 *    it (isUsed -> true), then sign in directly with the embedded email and
 *    password via the Auth REST signInWithPassword endpoint.
 *  - Sign In / Sign Up: email + password against the Auth REST endpoints.
 *  - A successful auth persists a lightweight session via [SessionManager] so
 *    subsequent launches skip the login screen.
 */
object AuthRepository {
    private const val PROJECT_ID = "maxstream-8effc"
    private const val API_KEY = "AIzaSyAiNjTADd8kA3qi3Dgnvlyo1Vf347QnsYk"

    private const val AUTH_BASE = "https://identitytoolkit.googleapis.com/v1/accounts"
    private const val FIRESTORE_BASE =
        "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents"

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
     * Reads a device code from Firestore, burns it, and signs the linked user
     * in directly using the email + password carried by the code.
     */
    suspend fun authenticateWithDeviceCode(code: String): Result<Credentials> {
        if (code.isBlank()) return Result.failure(IllegalArgumentException("Enter your code"))
        val encoded = java.net.URLEncoder.encode(code.trim(), "UTF-8")
        return try {
            val doc = getJson("$FIRESTORE_BASE/device_codes/$encoded?key=$API_KEY")
                ?: return Result.failure(Exception("Invalid code"))
            if (doc.has("error")) {
                return Result.failure(Exception("Invalid code"))
            }
            val fields = doc.getAsJsonObject("fields") ?: return Result.failure(Exception("Invalid code"))

            fun string(field: String): String =
                fields.getAsJsonObject(field)?.get("stringValue")?.asString ?: ""

            val email = string("email")
            val password = string("password")
            if (email.isBlank() || password.isBlank()) {
                return Result.failure(
                    Exception("This code has no credentials. Sign in with your email and password instead."),
                )
            }

            val isUsed = fields.getAsJsonObject("isUsed")?.get("booleanValue")?.asBoolean ?: false
            if (isUsed) return Result.failure(Exception("Code already used"))

            val expiresAt = fields.getAsJsonObject("expiresAt")?.get("timestampValue")?.asString
            if (expiresAt != null) {
                val expired = runCatching {
                    val parsed = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
                        .apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }
                        .parse(expiresAt.replace("Z", ""))
                    parsed != null && System.currentTimeMillis() > parsed.time
                }.getOrDefault(false)
                if (expired) return Result.failure(Exception("Code expired"))
            }

            // Burn the code so it can never be reused.
            val patchBody = JsonObject().apply {
                val isUsedField = JsonObject().apply { addProperty("booleanValue", true) }
                add("fields", JsonObject().apply { add("isUsed", isUsedField) })
            }
            val patchUrl = buildString {
                append("$FIRESTORE_BASE/device_codes/$encoded")
                append("?updateMask.fieldPaths=isUsed&key=$API_KEY")
            }
            runCatching { patchJson(patchUrl, patchBody) }

            // Sign in directly with the credentials the code carries.
            val signInBody = JsonObject().apply {
                addProperty("email", email)
                addProperty("password", password)
                addProperty("returnSecureToken", true)
            }
            val auth = postJson("$AUTH_BASE:signInWithPassword?key=$API_KEY", signInBody)
                ?: return Result.failure(Exception("Failed to sign in. Check your connection."))
            if (auth.has("error")) return Result.failure(Exception(authError(auth)))

            Result.success(Credentials(email = email, password = password))
        } catch (e: Exception) {
            if (e is IllegalStateException || e is java.io.IOException) {
                Result.failure(Exception("Failed to connect. Check your connection."))
            } else {
                Result.failure(e)
            }
        }
    }

    suspend fun signInWithEmail(email: String, password: String): Result<Unit> {
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
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun signUpWithEmail(email: String, password: String): Result<Unit> {
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
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun completeSignIn(context: Context, email: String) {
        SessionManager.signIn(context, email)
    }

    fun signOut(context: Context) = SessionManager.signOut(context)

    data class Credentials(val email: String, val password: String)
}
