package com.maxstream.app.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.remote.EpisodeRef
import com.maxstream.app.data.repository.CatalogRepository
import com.maxstream.app.di.Modules
import kotlinx.coroutines.launch

class SeriesViewModel(application: Application) : AndroidViewModel(application) {
    private val repo: CatalogRepository = Modules.catalogRepository

    private val _series = MutableLiveData<MediaItem?>(null)
    private val _seasons = MutableLiveData<List<Int>>(emptyList())
    private val _episodes = MutableLiveData<List<EpisodeRef>>(emptyList())
    private val _loading = MutableLiveData(false)
    private val _error = MutableLiveData<String?>(null)

    val series: LiveData<MediaItem?> = _series
    val seasons: LiveData<List<Int>> = _seasons
    val episodes: LiveData<List<EpisodeRef>> = _episodes
    val loading: LiveData<Boolean> = _loading
    val error: LiveData<String?> = _error

    private var currentSeriesId: Int? = null
    private var selectedSeason: Int = 1

    fun loadSeries(seriesId: Int) {
        // Always reload — don't skip if same ID, because the screen may have
        // been recreated or navigated to fresh with a clean ViewModel state.
        currentSeriesId = seriesId
        _loading.value = true
        _error.value = null
        _series.value = null
        _seasons.value = emptyList()
        _episodes.value = emptyList()
        viewModelScope.launch {
            try {
                val detailsJson = repo.seriesDetails(seriesId)
                val mediaItem = MediaItem.fromJson(detailsJson).copy(mediaType = "tv")
                _series.value = mediaItem

                val seasonsCount = detailsJson.optInt("number_of_seasons", 1).coerceAtLeast(1)
                _seasons.value = (1..seasonsCount).toList()
                selectedSeason = 1
                loadSeasonEpisodes(seriesId, selectedSeason)
            } catch (e: Exception) {
                _error.value = e.message
                _loading.value = false
            }
        }
    }

    fun selectSeason(season: Int) {
        if (selectedSeason == season) return
        selectedSeason = season
        currentSeriesId?.let { loadSeasonEpisodes(it, season) }
    }

    private fun loadSeasonEpisodes(seriesId: Int, season: Int) {
        _loading.value = true
        viewModelScope.launch {
            try {
                val episodes = repo.seasonEpisodes(seriesId, season)
                _episodes.value = episodes
            } catch (e: Exception) {
                _error.value = e.message
                _episodes.value = emptyList()
            } finally {
                _loading.value = false
            }
        }
    }
}
