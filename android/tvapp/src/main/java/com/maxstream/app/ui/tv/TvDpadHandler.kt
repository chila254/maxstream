package com.maxstream.app.ui.tv

import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.focus.FocusManager
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.key

object TvDpadHandler {
    fun isArrowDown(event: KeyEvent): Boolean =
        event.key == Key.DirectionDown

    fun isArrowUp(event: KeyEvent): Boolean =
        event.key == Key.DirectionUp

    fun isArrowLeft(event: KeyEvent): Boolean =
        event.key == Key.DirectionLeft

    fun isArrowRight(event: KeyEvent): Boolean =
        event.key == Key.DirectionRight

    fun isSelect(event: KeyEvent): Boolean =
        event.key == Key.Enter || event.key == Key.DirectionCenter

    fun moveDown(focusManager: FocusManager) {
        focusManager.moveFocus(FocusDirection.Down)
    }

    fun moveUp(focusManager: FocusManager) {
        focusManager.moveFocus(FocusDirection.Up)
    }

    fun moveLeft(focusManager: FocusManager) {
        focusManager.moveFocus(FocusDirection.Left)
    }

    fun moveRight(focusManager: FocusManager) {
        focusManager.moveFocus(FocusDirection.Right)
    }

    fun Modifier.onSidebarFocusChanged(onEnter: () -> Unit, onExit: () -> Unit) =
        onFocusChanged { focusState ->
            if (focusState.hasFocus) {
                TvFocusManager.focusSidebar()
                onEnter()
            } else {
                onExit()
            }
        }

    fun Modifier.onContentFocusChanged(onEnter: () -> Unit, onExit: () -> Unit) =
        onFocusChanged { focusState ->
            if (focusState.hasFocus) {
                TvFocusManager.focusContent()
                onEnter()
            } else {
                onExit()
            }
        }
}
