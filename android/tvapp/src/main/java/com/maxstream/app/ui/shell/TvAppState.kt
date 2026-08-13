package com.maxstream.app.ui.shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue

/**
 * Single source of truth for TV app navigation state.
 *
 * Mirrors Dart's TvNavigationProvider exactly, but as a plain Compose-state
 * class (no ChangeNotifier, no LiveData).  Instantiated once with
 * [rememberTvAppState] and passed down the tree; screens read it directly or
 * receive the relevant slice as a parameter.
 *
 * Focus convention (same as Dart):
 *   - App starts with focus on content (hero banner), NOT sidebar.
 *   - LEFT from content → sidebar
 *   - RIGHT / ENTER from sidebar → content
 */
class TvAppState {
    // ── Tab selection ────────────────────────────────────────────────────────
    var selectedTab by mutableStateOf(0)
        private set

    // ── Focus region ─────────────────────────────────────────────────────────
    /** true = D-pad is currently operating the sidebar */
    var focusOnSidebar by mutableStateOf(false)
        private set

    var isDeepNavigating by mutableStateOf(false)
        private set

    var searchFocused by mutableStateOf(false)
        private set

    // ── Scroll / focus memory per tab ────────────────────────────────────────
    private val tabScrollOffsets = mutableStateMapOf<Int, Float>()
    private val tabFocusedIndices = mutableStateMapOf<Int, Int>()
    private val sectionFocusIndices = mutableStateMapOf<Int, Int>()
    private val rowFocusedIndices = mutableStateMapOf<String, Int>()
    private val activeRowIds = mutableStateMapOf<Int, String>()

    // ── Tab actions ───────────────────────────────────────────────────────────

    /** Switch to [index] and move focus to content area. */
    fun selectTab(index: Int) {
        if (selectedTab != index) {
            selectedTab = index
        }
        // Always move focus to content on explicit tab selection
        focusOnSidebar = false
        isDeepNavigating = false
        searchFocused = false
    }

    // ── Focus region actions ──────────────────────────────────────────────────

    fun setFocusOnSidebar(value: Boolean) {
        if (focusOnSidebar != value) {
            focusOnSidebar = value
            if (!value) searchFocused = false
        }
    }

    fun setSearchFocused(value: Boolean) {
        if (searchFocused != value) {
            searchFocused = value
            if (value) focusOnSidebar = false
        }
    }

    fun setDeepNavigating(value: Boolean) {
        isDeepNavigating = value
    }

    fun returnToSidebar() {
        focusOnSidebar = true
        isDeepNavigating = false
        searchFocused = false
    }

    // ── Scroll persistence ────────────────────────────────────────────────────

    fun saveScrollOffset(tabIndex: Int, offset: Float) {
        tabScrollOffsets[tabIndex] = offset
    }

    fun getScrollOffset(tabIndex: Int): Float = tabScrollOffsets[tabIndex] ?: 0f

    // ── Focus index persistence ───────────────────────────────────────────────

    fun saveFocusedIndex(tabIndex: Int, index: Int) {
        tabFocusedIndices[tabIndex] = index
    }

    fun getFocusedIndex(tabIndex: Int): Int = tabFocusedIndices[tabIndex] ?: 0

    fun setSectionFocusIndex(tabIndex: Int, index: Int) {
        sectionFocusIndices[tabIndex] = index
    }

    fun getSectionFocusIndex(tabIndex: Int): Int = sectionFocusIndices[tabIndex] ?: 0

    fun saveRowFocusedIndex(rowId: String, index: Int) {
        rowFocusedIndices[rowId] = index
    }

    fun getRowFocusedIndex(rowId: String): Int = rowFocusedIndices[rowId] ?: 0

    fun saveActiveRowId(tabIndex: Int, rowId: String) {
        activeRowIds[tabIndex] = rowId
    }

    fun getActiveRowId(tabIndex: Int): String? = activeRowIds[tabIndex]

    // ── Reset ─────────────────────────────────────────────────────────────────

    fun clearState() {
        selectedTab = 0
        focusOnSidebar = false
        isDeepNavigating = false
        searchFocused = false
        tabScrollOffsets.clear()
        tabFocusedIndices.clear()
        sectionFocusIndices.clear()
        rowFocusedIndices.clear()
        activeRowIds.clear()
    }
}

@Composable
fun rememberTvAppState(): TvAppState = remember { TvAppState() }
