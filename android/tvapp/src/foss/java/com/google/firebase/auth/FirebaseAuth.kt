package com.google.firebase.auth

/**
 * FOSS stub — see [com.google.firebase.FirebaseApp] javadoc.
 */
class FirebaseAuth private constructor() {
    companion object {
        private val INSTANCE = FirebaseAuth()
        @JvmStatic fun getInstance(): FirebaseAuth = INSTANCE
    }
    val currentUser: FirebaseUser? get() = null
}
