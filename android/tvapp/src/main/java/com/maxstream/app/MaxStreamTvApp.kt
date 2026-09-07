package com.maxstream.app

import android.app.Application
import android.util.Log
import com.google.firebase.FirebaseApp

/**
 * Application entry point for MaxStream TV.
 *
 * Initializes Firebase explicitly so that FirebaseAuth, FirebaseDatabase,
 * and other Firebase services are available throughout the app lifetime.
 * Without this, calling FirebaseAuth.getInstance() before any Firebase
 * SDK auto-init would throw:
 *   IllegalStateException: Default FirebaseApp is not initialized in this process
 */
class MaxStreamTvApp : Application() {

    override fun onCreate() {
        super.onCreate()
        initFirebase()
    }

    private fun initFirebase() {
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
                Log.d(TAG, "Firebase initialized")
            }
        } catch (e: Exception) {
            // google-services.json missing or invalid — Firebase unavailable.
            // Cloud sync will be skipped gracefully; local settings still work.
            Log.w(TAG, "Firebase initialization failed: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "MaxStreamTvApp"
    }
}
