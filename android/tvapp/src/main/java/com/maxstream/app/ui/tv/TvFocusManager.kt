package com.maxstream.app.ui.tv

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

object TvFocusManager {
    var isSidebarFocused by mutableStateOf(true)
        private set

    var sidebarExpanded by mutableStateOf(false)
        private set

    fun focusSidebar() {
        isSidebarFocused = true
    }

    fun focusContent() {
        isSidebarFocused = false
    }

    fun toggleFocus() {
        isSidebarFocused = !isSidebarFocused
    }

    fun onSidebarItemFocused() {
        sidebarExpanded = true
    }

    fun onSidebarItemUnfocused() {
        sidebarExpanded = false
    }

    fun reset() {
        isSidebarFocused = true
        sidebarExpanded = false
    }
}
