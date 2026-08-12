package com.maxstream.app.data.repository

import android.content.Context
import com.maxstream.app.data.local.SessionManager

/**
 * Authentication for the native TV build. The Dart app used Firebase; to keep the
 * standalone TV APK free of the Firebase toolchain, this validates the device
 * code / email locally and persists a lightweight session. Swap the bodies for a
 * real backend (Firebase / your API) without touching the UI.
 */
object AuthRepository {

    /** Validates a device code and returns the linked credentials, if any. */
    suspend fun authenticateWithDeviceCode(code: String): Result<Credentials> {
        if (code.isBlank()) return Result.failure(IllegalArgumentException("Empty code"))
        // TODO: replace with real device-code exchange.
        return Result.success(Credentials(email = "tv@maxstream.app", password = ""))
    }

    suspend fun signInWithEmail(email: String, password: String): Result<Unit> {
        if (email.isBlank() || password.isBlank()) {
            return Result.failure(IllegalArgumentException("Email and password required"))
        }
        // TODO: replace with real sign-in.
        return Result.success(Unit)
    }

    suspend fun signUpWithEmail(email: String, password: String): Result<Unit> {
        if (email.isBlank() || password.length < 6) {
            return Result.failure(IllegalArgumentException("Invalid credentials"))
        }
        // TODO: replace with real sign-up.
        return Result.success(Unit)
    }

    fun completeSignIn(context: Context, email: String) {
        SessionManager.signIn(context, email)
    }

    fun signOut(context: Context) = SessionManager.signOut(context)

    data class Credentials(val email: String, val password: String)
}
