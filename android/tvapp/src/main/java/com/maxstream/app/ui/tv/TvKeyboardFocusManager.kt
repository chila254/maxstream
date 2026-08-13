package com.maxstream.app.ui.tv

import androidx.compose.runtime.mutableStateOf

class TvKeyboardFocusManager {
    private val _isKeyboardActive = mutableStateOf(false)
    val isKeyboardActive: Boolean get() = _isKeyboardActive.value

    private val _isFocusedOnContent = mutableStateOf(false)
    val isFocusedOnContent: Boolean get() = _isFocusedOnContent.value

    fun activateKeyboard() {
        _isKeyboardActive.value = true
        _isFocusedOnContent.value = false
    }

    fun deactivateKeyboard() {
        _isKeyboardActive.value = false
    }

    fun focusOnContent() {
        _isFocusedOnContent.value = true
        _isKeyboardActive.value = false
    }

    fun unfocusContent() {
        _isFocusedOnContent.value = false
    }

    fun toggleFocus() {
        if (_isKeyboardActive.value) {
            focusOnContent()
        } else {
            activateKeyboard()
        }
    }

    fun reset() {
        _isKeyboardActive.value = false
        _isFocusedOnContent.value = false
    }
}
