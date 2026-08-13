package com.maxstream.app.ui.tv

import androidx.compose.ui.focus.FocusRequester

/**
 * Lightweight singleton focus coordinator.
 *
 * Mirrors Dart's TvFocusManager static class. Holds references to the
 * sidebar's per-item FocusRequesters and the content-area FocusRequester,
 * all of which are created once in MainActivity and injected here via
 * [initialize].
 *
 * Screens call [focusContent] / [focusSidebar] directly without needing to
 * hold a reference to any parent state.
 */
object TvFocusManager {

    private var sidebarFocusRequesters: List<FocusRequester> = emptyList()
    private var contentFocusRequester: FocusRequester? = null
    private var _currentSidebarIndex: Int = 0

    /** Called once from MainActivity's LaunchedEffect(Unit). */
    fun initialize(
        sidebarFocusRequesters: List<FocusRequester>,
        contentFocusRequester: FocusRequester,
    ) {
        this.sidebarFocusRequesters = sidebarFocusRequesters
        this.contentFocusRequester = contentFocusRequester
    }

    /** Move focus to the current sidebar item. */
    fun focusSidebar(index: Int = _currentSidebarIndex) {
        _currentSidebarIndex = index
        runCatching { sidebarFocusRequesters.getOrNull(index)?.requestFocus() }
    }

    /** Move focus to the content area. */
    fun focusContent() {
        runCatching { contentFocusRequester?.requestFocus() }
    }

    /** Called by Sidebar when the selected tab changes. */
    fun onTabChanged(index: Int) {
        _currentSidebarIndex = index
    }

    fun dispose() {
        sidebarFocusRequesters = emptyList()
        contentFocusRequester = null
    }
}
