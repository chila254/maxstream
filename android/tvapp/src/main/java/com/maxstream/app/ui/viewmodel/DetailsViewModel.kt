package com.maxstream.app.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.model.Source
import com.maxstream.app.data.remote.EpisodeRef
import com.maxstream.app.di.Modules
import kotlinx.coroutines.launch

/**
 * Drives the details screen: pulls metadata, lists episodes for a series, and
 * resolves a playable [Source] (or every server) via the reused extractor.
 */
class DetailsViewModel(application: Application, private val item: MediaItem) :
    AndroidViewModel(application) {

    private val catalog = Modules.catalogRepository
    private val streamRepo = Modules.streamRepository(application)

    private val _seasonCount = MutableLiveData(1)
    private val _episodes = MutableLiveData<List<EpisodeRef>>(emptyList())
    private val _stream = MutableLiveData<Source?>(null)
    private val _servers = MutableLiveData<List<Source>>(emptyList())
    private val _resolving = MutableLiveData(false)
    private val _error = MutableLiveData<String?>(null)

    val seasonCount: LiveData<Int> = _seasonCount
    val episodes: LiveData<List<EpisodeRef>> = _episodes
    val stream: LiveData<Source?> = _stream
    val servers: LiveData<List<Source>> = _servers
    val resolving: LiveData<Boolean> = _resolving
    val error: LiveData<String?> = _error

    init {
        loadMeta()
    }

    private fun loadMeta() {
        if (item.isMovie) return
        viewModelScope.launch {
            runCatching { catalog.seriesDetails(item.id) }.onSuccess { json ->
                val count = json.optInt("number_of_seasons", 1).coerceAtLeast(1)
                _seasonCount.value = count
                loadEpisodes(1)
            }.onFailure { _error.value = it.message }
        }
    }

    fun loadEpisodes(season: Int) {
        if (item.isMovie) return
        viewModelScope.launch {
            runCatching { catalog.seasonEpisodes(item.id, season) }
                .onSuccess { _episodes.value = it }
                .onFailure { _error.value = it.message }
        }
    }

    fun resolve(season: Int = 1, episode: Int = 1) {
        _resolving.value = true
        _error.value = null
        viewModelScope.launch {
            runCatching {
                streamRepo.resolve(
                    tmdbId = item.id.toString(),
                    isMovie = item.isMovie,
                    season = if (item.isMovie) 1 else season,
                    episode = if (item.isMovie) 1 else episode,
                    title = item.title,
                )
            }.onSuccess { _stream.value = it }
                .onFailure { _error.value = it.message ?: "Could not resolve a stream" }
            _resolving.value = false
        }
    }

    fun resolveAll(season: Int = 1, episode: Int = 1) {
        viewModelScope.launch {
            runCatching {
                streamRepo.resolveAll(
                    tmdbId = item.id.toString(),
                    isMovie = item.isMovie,
                    season = if (item.isMovie) 1 else season,
                    episode = if (item.isMovie) 1 else episode,
                    title = item.title,
                )
            }.onSuccess { _servers.value = it }
                .onFailure { _error.value = it.message }
        }
    }
}
