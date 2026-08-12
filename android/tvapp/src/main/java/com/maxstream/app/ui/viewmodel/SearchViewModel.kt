package com.maxstream.app.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.di.Modules
import kotlinx.coroutines.launch

class SearchViewModel(application: Application) : AndroidViewModel(application) {
    private val repo = Modules.catalogRepository

    private val _results = MutableLiveData<List<MediaItem>>(emptyList())
    private val _loading = MutableLiveData(false)
    private val _error = MutableLiveData<String?>(null)

    val results: LiveData<List<MediaItem>> = _results
    val loading: LiveData<Boolean> = _loading
    val error: LiveData<String?> = _error

    fun search(query: String) {
        if (query.isBlank()) {
            _results.value = emptyList()
            return
        }
        _loading.value = true
        viewModelScope.launch {
            runCatching { repo.search(query) }
                .onSuccess { _results.value = it }
                .onFailure { _error.value = it.message }
            _loading.value = false
        }
    }
}
