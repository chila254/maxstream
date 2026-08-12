package com.maxstream.app.di

import android.content.Context
import com.maxstream.app.data.remote.TmdbApi
import com.maxstream.app.data.repository.CatalogRepository
import com.maxstream.app.data.repository.StreamRepository

/**
 * Process-wide module holder. Initialised lazily so the Flutter [Application]
 * is left untouched (the existing `android:name="${applicationName}"` stays
 * valid). Call [streamRepository] once with a context; it is then cached.
 */
object Modules {
    val tmdbApi: TmdbApi = TmdbApi()
    val catalogRepository: CatalogRepository = CatalogRepository(tmdbApi)

    @Volatile
    private var _streamRepository: StreamRepository? = null

    fun streamRepository(context: Context): StreamRepository =
        _streamRepository ?: synchronized(this) {
            _streamRepository ?: StreamRepository(context.applicationContext)
                .also { _streamRepository = it }
        }
}
