package com.maxstream.app

import android.app.Application
import android.content.Context
import androidx.work.Configuration
import androidx.work.WorkManager

class MaxStreamApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        // Initialize WorkManager with custom configuration
        val config = Configuration.Builder()
            .setMinimumLoggingLevel(android.util.Log.INFO)
            .build()
        
        WorkManager.initialize(this, config)
    }
}
