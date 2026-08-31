package com.maxstream.app.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import android.annotation.SuppressLint
import com.maxstream.app.data.local.WatchProgressRepository
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.repository.CloudSyncRepository
import com.maxstream.app.di.Modules
import kotlinx.coroutines.async
import kotlinx.coroutines.launch

class HomeViewModel(application: Application) : AndroidViewModel(application) {
    private val repo = Modules.catalogRepository

    private val _trendingMovies = MutableLiveData<List<MediaItem>>(emptyList())
    private val _trendingSeries = MutableLiveData<List<MediaItem>>(emptyList())
    private val _popularMovies = MutableLiveData<List<MediaItem>>(emptyList())
    private val _popularSeries = MutableLiveData<List<MediaItem>>(emptyList())
    private val _topRatedMovies = MutableLiveData<List<MediaItem>>(emptyList())
    private val _topRatedSeries = MutableLiveData<List<MediaItem>>(emptyList())
    private val _continueWatching = MutableLiveData<List<MediaItem>>(emptyList())
    private val _loading = MutableLiveData(true)
    private val _error = MutableLiveData<String?>(null)

    val trendingMovies: LiveData<List<MediaItem>> = _trendingMovies
    val trendingSeries: LiveData<List<MediaItem>> = _trendingSeries
    val popularMovies: LiveData<List<MediaItem>> = _popularMovies
    val popularSeries: LiveData<List<MediaItem>> = _popularSeries
    val topRatedMovies: LiveData<List<MediaItem>> = _topRatedMovies
    val topRatedSeries: LiveData<List<MediaItem>> = _topRatedSeries
    val continueWatching: LiveData<List<MediaItem>> = _continueWatching
    val loading: LiveData<Boolean> = _loading
    val error: LiveData<String?> = _error

    init {
        loadAll()
    }

    @SuppressLint("NullSafeMutableLiveData")
    fun loadAll() {
        _loading.value = true
        _error.value = null
        viewModelScope.launch {
            // Pull the phone's watch progress/watchlist into local storage so
            // Continue Watching reflects what was watched on the phone.
            // Never let sync failure block catalogue loading.
            runCatching { CloudSyncRepository.pullToDevice(getApplication()) }
            // Fetch all catalogue rows in parallel; a single TMDB failure must
            // not blank the whole home screen (previously sequential without
            // per-row catch left every list empty on the first exception).
            val trendingMoviesDef = async { runCatching { repo.trendingMovies() }.getOrNull() ?: emptyList() }
            val trendingSeriesDef = async { runCatching { repo.trendingSeries() }.getOrNull() ?: emptyList() }
            val popularMoviesDef = async { runCatching { repo.popularMovies() }.getOrNull() ?: emptyList() }
            val popularSeriesDef = async { runCatching { repo.popularSeries() }.getOrNull() ?: emptyList() }
            val topRatedMoviesDef = async { runCatching { repo.topRatedMovies() }.getOrNull() ?: emptyList() }
            val topRatedSeriesDef = async { runCatching { repo.topRatedSeries() }.getOrNull() ?: emptyList() }
            try {
                _trendingMovies.value = trendingMoviesDef.await()
                _trendingSeries.value = trendingSeriesDef.await()
                _popularMovies.value = popularMoviesDef.await()
                _popularSeries.value = popularSeriesDef.await()
                _topRatedMovies.value = topRatedMoviesDef.await()
                _topRatedSeries.value = topRatedSeriesDef.await()
            } catch (e: Exception) {
                _error.value = e.message
            }
            // Continue Watching row: locally persisted watch progress, newest
            // first, filtered like the phone (drop barely-started, watched and
            // >= 90% items — mirrors WatchHistoryService.getContinueWatching).
            _continueWatching.value = runCatching {
                WatchProgressRepository
                    .recent(getApplication(), limit = 20)
                    .filter { entry -> entry.isVisibleInContinueWatching() }
                    .map { it.toMediaItem() }
            }.getOrDefault(emptyList())
            _loading.value = false
            // Surface empty catalogue as error so UI can show retry instead of black.
            if (_trendingMovies.value.isNullOrEmpty() && _trendingSeries.value.isNullOrEmpty() &&
                _popularMovies.value.isNullOrEmpty() && _topRatedMovies.value.isNullOrEmpty()
            ) {
                _error.value = _error.value ?: "No content available. Pull to refresh or check connection."
            }
        }
    }

    /**
     * Re-reads locally-synced progress for Continue Watching. Inbound cloud
     * changes are mirrored by [CloudSyncCoordinator] (which also pulls on
     * [loadAll]); this only re-reads local storage so it is cheap and safe to
     * call on tab visibility + every revision bump.
     */
    @SuppressLint("NullSafeMutableLiveData")
    fun refreshSynced() {
        _continueWatching.value = WatchProgressRepository
            .recent(getApplication(), limit = 20)
            .filter { entry -> entry.isVisibleInContinueWatching() }
            .map { it.toMediaItem() }
    }
}
