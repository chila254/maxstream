package com.maxstream.app.ui.tv

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.focus.FocusRequester

object TvFocusManager {
    private var sidebarFocusRequester: FocusRequester? = null
    private var contentFocusRequester: FocusRequester? = null
    private val _isSidebarFocused = mutableStateOf(true)
    val isSidebarFocused: Boolean get() = _isSidebarFocused.value

    var sidebarExpanded by mutableStateOf(false)
        private set

    fun initialize(sidebarFocusRequester: FocusRequester, contentFocusRequester: FocusRequester) {
        this.sidebarFocusRequester = sidebarFocusRequester
        this.contentFocusRequester = contentFocusRequester
    }

    fun focusSidebar() {
        _isSidebarFocused.value = true
        sidebarFocusRequester?.requestFocus()
    }

    fun focusContent() {
        _isSidebarFocused.value = false
        contentFocusRequester?.requestFocus()
    }

    fun toggleFocus() {
        if (_isSidebarFocused.value) {
            focusContent()
        } else {
            focusSidebar()
        }
    }

    fun onSidebarItemFocused() {
        sidebarExpanded = true
    }

    fun onSidebarItemUnfocused() {
        sidebarExpanded = false
    }

    fun reset() {
        _isSidebarFocused.value = true
        sidebarExpanded = false
    }

    fun dispose() {
        sidebarFocusRequester = null
        contentFocusRequester = null
    }
}
