package com.maxstream.app.ui.navigation

import androidx.compose.foundation.ScrollState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class TvNavigationProvider {
    private val _selectedTab = mutableStateOf(0)
    var selectedTab: Int by _selectedTab
        private set

    private val _focusOnSidebar = mutableStateOf(false)
    val focusOnSidebar: Boolean get() = _focusOnSidebar.value

    private val _isDeepNavigating = mutableStateOf(false)
    val isDeepNavigating: Boolean get() = _isDeepNavigating.value

    private val _searchFocused = mutableStateOf(false)
    val searchFocused: Boolean get() = _searchFocused.value

    private val _tabScrollOffsets = mutableStateMapOf<Int, Double>()
    private val _tabFocusedIndices = mutableStateMapOf<Int, Int>()
    private val _sectionFocusIndices = mutableStateMapOf<Int, Int>()
    private val _rowFocusedIndices = mutableStateMapOf<String, Int>()
    private val _activeRowIds = mutableStateMapOf<Int, String>()
    private val _tabScrollStates = mutableStateMapOf<Int, ScrollState>()

    fun selectTab(index: Int) {
        if (_selectedTab.value != index) {
            _selectedTab.value = index
            _focusOnSidebar.value = false
            _isDeepNavigating.value = false
            _searchFocused.value = false
        }
    }

    fun setFocusOnSidebar(value: Boolean) {
        if (_focusOnSidebar.value != value) {
            _focusOnSidebar.value = value
            _searchFocused.value = false
        }
    }

    fun setSearchFocused(value: Boolean) {
        if (_searchFocused.value != value) {
            _searchFocused.value = value
            if (value) {
                _focusOnSidebar.value = false
            }
        }
    }

    fun setDeepNavigating(value: Boolean) {
        _isDeepNavigating.value = value
    }

    fun saveScrollOffset(tabIndex: Int, offset: Double) {
        _tabScrollOffsets[tabIndex] = offset
    }

    fun getScrollOffset(tabIndex: Int): Double {
        return _tabScrollOffsets[tabIndex] ?: 0.0
    }

    fun registerScrollController(tabIndex: Int, controller: ScrollState) {
        _tabScrollStates[tabIndex] = controller
    }

    fun getScrollController(tabIndex: Int): ScrollState? {
        return _tabScrollStates[tabIndex]
    }

    fun restoreScrollPosition(tabIndex: Int) {
        val controller = _tabScrollStates[tabIndex]
        val offset = _tabScrollOffsets[tabIndex]
        if (controller != null && offset != null && offset > 0) {
            // Scroll restoration should be handled by the composable
            // owning the ScrollState via LaunchedEffect observing this offset.
        }
    }

    fun saveFocusedIndex(tabIndex: Int, index: Int) {
        _tabFocusedIndices[tabIndex] = index
    }

    fun getFocusedIndex(tabIndex: Int): Int {
        return _tabFocusedIndices[tabIndex] ?: 0
    }

    fun setSectionFocusIndex(tabIndex: Int, index: Int) {
        _sectionFocusIndices[tabIndex] = index
    }

    fun getSectionFocusIndex(tabIndex: Int): Int {
        return _sectionFocusIndices[tabIndex] ?: 0
    }

    fun saveRowFocusedIndex(rowId: String, index: Int) {
        _rowFocusedIndices[rowId] = index
    }

    fun getRowFocusedIndex(rowId: String): Int {
        return _rowFocusedIndices[rowId] ?: 0
    }

    fun saveActiveRowId(tabIndex: Int, rowId: String) {
        _activeRowIds[tabIndex] = rowId
    }

    fun getActiveRowId(tabIndex: Int): String? {
        return _activeRowIds[tabIndex]
    }

    fun returnToSidebar() {
        _focusOnSidebar.value = true
        _isDeepNavigating.value = false
        _searchFocused.value = false
        restoreScrollPosition(_selectedTab.value)
    }

    fun clearState() {
        _selectedTab.value = 0
        _focusOnSidebar.value = false
        _isDeepNavigating.value = false
        _searchFocused.value = false
        _tabScrollOffsets.clear()
        _tabFocusedIndices.clear()
        _sectionFocusIndices.clear()
        _rowFocusedIndices.clear()
        _activeRowIds.clear()
    }
}
