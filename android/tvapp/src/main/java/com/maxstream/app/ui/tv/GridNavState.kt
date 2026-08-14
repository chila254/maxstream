package com.maxstream.app.ui.tv

import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * A grid section inside a (possibly multi-section) results panel.
 *
 * @param id            stable identity used to remember focus across panels.
 * @param count         number of cards in the grid.
 * @param sectionIndex  index of this grid's item within the parent [LazyListState].
 */
data class GridDesc(
    val id: String,
    val count: Int,
    val sectionIndex: Int = 0,
)

/**
 * State holder for D-pad navigation across one or more card grids, mirroring
 * the proven GenreScreen pattern (per-card [FocusRequester] + scroll-then-
 * retry focus). Scrolls the parent [LazyListState] to the grid's section and
 * requests focus on the target card, retrying until it is composed.
 *
 * Handles every boundary:
 *  - LEFT on column 0        → [onReturnToKeyboard]
 *  - UP on first row of grid → previous grid (same column) or [onReturnToKeyboard]
 *  - DOWN on last row        → next grid (same column) or consumed
 *  - ESC / Back              → [onReturnToSidebar]
 */
class GridNavState(private val columns: Int) {

    private val requesters = mutableMapOf<String, FocusRequester>()
    private val gridStates = mutableMapOf<String, LazyGridState>()
    private val savedIndices = mutableMapOf<String, Int>()

    /** In-flight focus move. Cancelled before every new move so rapid D-pad
     *  presses never queue up stale scroll+focus jobs that fight each other. */
    private var focusJob: Job? = null

    /** Ordered list of grid sections currently visible (top to bottom). */
    var grids: List<GridDesc> = emptyList()
        private set

    /** Grid that currently owns focus, or null when the keyboard is focused. */
    var activeGridId: String? = null
        private set

    fun setGrids(grids: List<GridDesc>) {
        this.grids = grids
    }

    /** Register a scrollable grid so [focusCard] can bring the card into view. */
    fun registerGrid(gridId: String, state: LazyGridState) {
        gridStates[gridId] = state
    }

    fun unregisterGrid(gridId: String) {
        gridStates.remove(gridId)
        requesters.keys.removeIf { it.substringBeforeLast(':') == gridId }
    }

    /** Number of cards in [gridId] (0 when the grid is not visible). */
    fun count(gridId: String): Int = grids.firstOrNull { it.id == gridId }?.count ?: 0

    /** Last focused card index for [gridId]. */
    fun focusedIndex(gridId: String): Int = savedIndices[gridId] ?: 0

    /** Stable per-card [FocusRequester], kept alive across recompositions. */
    fun requester(gridId: String, index: Int): FocusRequester =
        requesters.getOrPut("$gridId:$index") { FocusRequester() }

    /**
     * Moves focus to card [requestedIndex] of [gridId]. Scrolls the parent
     * [outerListState] (when given) to the grid's section and the grid itself
     * into view, then requests focus with retries.
     */
    suspend fun focusCard(
        gridId: String,
        requestedIndex: Int,
        outerListState: LazyListState?,
    ) {
        val desc = grids.firstOrNull { it.id == gridId } ?: return
        val index = requestedIndex.coerceIn(0, desc.count - 1)
        savedIndices[gridId] = index
        activeGridId = gridId

        runCatching { outerListState?.animateScrollToItem(desc.sectionIndex) }
        runCatching { gridStates[gridId]?.animateScrollToItem(index) }

        val requester = requester(gridId, index)
        var attempt = 0
        while (attempt < 6) {
            if (attempt > 0) delay(50L * attempt)
            val ok = runCatching { requester.requestFocus(); true }.getOrDefault(false)
            if (ok) return
            attempt++
        }
    }

    /** Cancels the previous move then starts a new one — keeps navigation
     *  snappy and prevents stale focus requests from stealing focus back. */
    fun moveTo(
        gridId: String,
        index: Int,
        outerListState: LazyListState?,
        scope: CoroutineScope,
    ) {
        focusJob?.cancel()
        focusJob = scope.launch { focusCard(gridId, index, outerListState) }
    }

    /**
     * Shared D-pad handler for a card inside [gridId].
     *
     * @return true when the event was consumed.
     */
    fun onCardKey(
        gridId: String,
        index: Int,
        event: KeyEvent,
        outerListState: LazyListState?,
        scope: CoroutineScope,
        onReturnToKeyboard: () -> Unit,
        onReturnToSidebar: () -> Unit,
    ): Boolean {
        if (event.type != KeyEventType.KeyDown) return false
        val column = index % columns
        val row = index / columns
        val desc = grids.firstOrNull { it.id == gridId } ?: return false
        val gridIndex = grids.indexOf(desc)

        return when (event.key) {
            Key.Back, Key.Escape -> { onReturnToSidebar(); true }

            Key.DirectionLeft -> {
                if (column == 0) onReturnToKeyboard()
                else moveTo(gridId, index - 1, outerListState, scope)
                true
            }

            Key.DirectionRight -> {
                if (column < columns - 1 && index + 1 < desc.count) {
                    moveTo(gridId, index + 1, outerListState, scope)
                }
                true
            }

            Key.DirectionUp -> {
                if (row == 0) {
                    if (gridIndex > 0) {
                        val target = grids[gridIndex - 1]
                        moveTo(target.id, column.coerceAtMost(target.count - 1), outerListState, scope)
                    } else {
                        onReturnToKeyboard()
                    }
                } else {
                    moveTo(gridId, index - columns, outerListState, scope)
                }
                true
            }

            Key.DirectionDown -> {
                val nextRowStart = (row + 1) * columns
                if (nextRowStart < desc.count) {
                    moveTo(gridId, (nextRowStart + column).coerceIn(nextRowStart, desc.count - 1), outerListState, scope)
                } else if (gridIndex < grids.lastIndex) {
                    val target = grids[gridIndex + 1]
                    moveTo(target.id, column.coerceAtMost(target.count - 1), outerListState, scope)
                }
                true
            }

            else -> false
        }
    }

    /** Moves focus to the first grid's previously focused card (keyboard → results). */
    fun focusFirstCard(gridId: String, outerListState: LazyListState?, scope: CoroutineScope) {
        moveTo(gridId, focusedIndex(gridId), outerListState, scope)
    }

    /** Drops requesters for grids that no longer exist. */
    fun clearMissingGrids() {
        val visible = grids.mapTo(mutableSetOf()) { it.id }
        requesters.keys.removeIf { it.substringBeforeLast(':') !in visible }
        activeGridId?.takeIf { it !in visible }?.let { activeGridId = null }
    }
}
