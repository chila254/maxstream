package com.google.firebase.database

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks

/**
 * FOSS stub — see [com.google.firebase.FirebaseApp] javadoc.
 */
class DatabaseReference {
    fun child(path: String): DatabaseReference = this
    fun setValue(value: Any?): Task<Void> = Tasks.forResult(null)
    fun get(): Task<DataSnapshot> = Tasks.forResult(DataSnapshot())
}
