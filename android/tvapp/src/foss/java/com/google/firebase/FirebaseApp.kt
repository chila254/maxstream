package com.google.firebase

import android.content.Context

/**
 * FOSS stub — real Firebase classes are only on the classpath for the
 * "standard" product-flavor.  The stub lets shared code compile while every
 * call is a harmless no-op / returns safe defaults.
 */
class FirebaseApp {
    companion object {
        @JvmStatic fun getApps(context: Context): List<FirebaseApp> = emptyList()
        @JvmStatic fun initializeApp(context: Context): FirebaseApp = FirebaseApp()
    }
}
