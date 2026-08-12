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
            val trendingMovies: List<MediaItem> = async { repo.trendingMovies() ?: emptyList() }.await()
            val trendingSeries: List<MediaItem> = async { repo.trendingSeries() ?: emptyList() }.await()
            val popularMovies: List<MediaItem> = async { repo.popularMovies() ?: emptyList() }.await()
            val popularSeries: List<MediaItem> = async { repo.popularSeries() ?: emptyList() }.await()
            val topRatedMovies: List<MediaItem> = async { repo.topRatedMovies() ?: emptyList() }.await()
            val topRatedSeries: List<MediaItem> = async { repo.topRatedSeries() ?: emptyList() }.await()
            _trendingMovies.value = trendingMovies
            _trendingSeries.value = trendingSeries
            _popularMovies.value = popularMovies
            _popularSeries.value = popularSeries
            _topRatedMovies.value = topRatedMovies
            _topRatedSeries.value = topRatedSeries
            _loading.value = false
        }
    }
}
