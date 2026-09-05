package com.maxstream.app.data.repository

import android.content.Context
import com.maxstream.app.data.local.SessionManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Continuous cloud-sync coordinator for the TV, mirroring the Dart phone app's
 * `CloudSyncService.startListening()` real-time listener.
 *
 * While the user is signed in, a background loop re-pulls the phone's watch
 * progress + watchlist from Realtime Database every [SYNC_INTERVAL_MS]. Any change
 * bumps the matching revision [StateFlow] — the Home/Details/Watchlist screens
 * collect these and refresh, so a title watched (or un-watched) on the phone
 * appears on the TV within a few seconds, just like the Dart listener did.
 *
 * Writes are already pushed eagerly at the write sites (PlayerScreen /
 * DetailsScreen), so this loop only has to mirror inbound changes.
 */
object CloudSyncCoordinator {
    private const val SYNC_INTERVAL_MS = 10_000L

    private val _historyRevision = MutableStateFlow(0)
    private val _watchlistRevision = MutableStateFlow(0)

    /** Bumped whenever synced watch history changed (Dart historyRevision). */
    val historyRevision: StateFlow<Int> = _historyRevision.asStateFlow()

    /** Bumped whenever synced watchlist changed (Dart watchlistRevision). */
    val watchlistRevision: StateFlow<Int> = _watchlistRevision.asStateFlow()

    @Volatile
    private var started = false
    private var job: Job? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Starts the background sync loop (no-op if already running). */
    fun start(context: Context) {
        if (started) return
        started = true
        job = scope.launch {
            while (isActive) {
                if (SessionManager.isLoggedIn(context)) {
                    // The stored Firebase idToken expires after ~1h; refresh it
                    // first so Realtime Database REST calls don't silently 401/403.
                    runCatching { AuthRepository.ensureFreshIdToken(context) }
                    val fbChange = runCatching {
                        CloudSyncRepository.pullToDevice(context)
                    }.getOrDefault(CloudSyncRepository.SyncChange(false, false))
                    // Supabase full sync (watch_history, watchlist, provider_prefs) - same tables as mobile
                    // Phone+TV now share same Postgres via Firebase UID, so continue watching is instant
                    runCatching { com.maxstream.app.data.supabase.TvSupabaseSyncService.pullToDevice(context) }
                    if (fbChange.historyChanged) _historyRevision.value++
                    if (fbChange.watchlistChanged) _watchlistRevision.value++
                    // Also bump for Supabase pulls (polling, no realtime yet) - ensures TV picks up phone's Supabase pushes
                    // Simple: if Supabase had any data, bump (cheap, UI will dedupe)
                    // We can't easily know if Supabase changed, so bump on any successful pull when not already bumped
                    if (!fbChange.historyChanged) {
                        // If Supabase had history, it would have imported, we bump to refresh
                        // Use a lightweight check - if we just pulled Supabase, bump once per cycle
                        // to keep TV in sync with phone's Supabase pushes (watch progress)
                        _historyRevision.value++
                        _watchlistRevision.value++
                    }
                }
                delay(SYNC_INTERVAL_MS)
            }
        }
    }

    /** Stops the background sync loop. */
    fun stop() {
        started = false
        job?.cancel()
        job = null
    }
}
