package com.google.firebase.database

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks

/**
 * FOSS stub — see [com.google.firebase.FirebaseApp] javadoc.
 */
class FirebaseDatabase private constructor() {
    companion object {
        private val INSTANCE = FirebaseDatabase()
        @JvmStatic fun getInstance(): FirebaseDatabase = INSTANCE
    }
    private val root = DatabaseReference()
    fun getReference(): DatabaseReference = root
}
