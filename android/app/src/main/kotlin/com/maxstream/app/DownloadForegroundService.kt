package com.maxstream.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class DownloadForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "maxstream_download_service"
        const val NOTIFICATION_ID = 9999
        const val ACTION_START = "com.maxstream.app.action.START_DOWNLOAD_SERVICE"
        const val ACTION_STOP = "com.maxstream.app.action.STOP_DOWNLOAD_SERVICE"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val count = intent?.getIntExtra("download_count", 1) ?: 1
                val title = intent?.getStringExtra("title") ?: "Downloading media"
                val notification = buildNotification(count, title)
                startForeground(NOTIFICATION_ID, notification)
                return START_STICKY
            }
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Media Downloads",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps downloads running in the background"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(downloadCount: Int, title: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MaxStream")
            .setContentText(
                if (downloadCount == 1) "Downloading: $title"
                else "Downloading $downloadCount items"
            )
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
    }
}
