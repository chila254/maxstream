package com.maxstream.app.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.maxstream.app.data.model.MediaItem
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
    private val _loading = MutableLiveData(true)
    private val _error = MutableLiveData<String?>(null)

    val trendingMovies: LiveData<List<MediaItem>> = _trendingMovies
    val trendingSeries: LiveData<List<MediaItem>> = _trendingSeries
    val popularMovies: LiveData<List<MediaItem>> = _popularMovies
    val popularSeries: LiveData<List<MediaItem>> = _popularSeries
    val topRatedMovies: LiveData<List<MediaItem>> = _topRatedMovies
    val topRatedSeries: LiveData<List<MediaItem>> = _topRatedSeries
    val loading: LiveData<Boolean> = _loading
    val error: LiveData<String?> = _error

    init {
        loadAll()
    }

    fun loadAll() {
        _loading.value = true
        _error.value = null
        viewModelScope.launch {
            val trendingMovies = async { repo.trendingMovies() }
            val trendingSeries = async { repo.trendingSeries() }
            val popularMovies = async { repo.popularMovies() }
            val popularSeries = async { repo.popularSeries() }
            val topRatedMovies = async { repo.topRatedMovies() }
            val topRatedSeries = async { repo.topRatedSeries() }
            _trendingMovies.value = trendingMovies.await()
            _trendingSeries.value = trendingSeries.await()
            _popularMovies.value = popularMovies.await()
            _popularSeries.value = popularSeries.await()
            _topRatedMovies.value = topRatedMovies.await()
            _topRatedSeries.value = topRatedSeries.await()
            _loading.value = false
        }
    }
}
