package com.maxstream.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.ui.tv.TvKeyboardFocusManager

@Composable
fun TvKeyboard(
    onInput: (String) -> Unit,
    onSubmit: () -> Unit,
    initialText: String = "",
    focusManager: TvKeyboardFocusManager? = null,
    focusRequester: FocusRequester = remember { FocusRequester() },
    onMoveRight: (() -> Unit)? = null,
    onMoveLeft: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    var keyboardLayout by remember { mutableStateOf(emptyList<List<String>>()) }
    var selectedRow by remember { mutableStateOf(0) }
    var selectedCol by remember { mutableStateOf(0) }
    var input by remember { mutableStateOf(initialText) }
    var capsLock by remember { mutableStateOf(false) }
    var isSymbols by remember { mutableStateOf(false) }
    val keyboardFocusRequester = focusRequester

    // One FocusRequester per key (stable across recompositions), matching the
    // Dart keyboard's per-key FocusNodes. Focus lands on the actual key so the
    // remote's OK (DirectionCenter) and Enter both type the focused key.
    val keyRequesters = remember { mutableMapOf<String, FocusRequester>() }

    fun initializeKeyboard() {
        keyboardLayout = if (isSymbols) {
            listOf(
                listOf("!", "@", "#", "\$", "%", "^", "&", "*", "(", ")"),
                listOf("-", "_", "=", "+", "[", "]", "{", "}", "|", "\\"),
                listOf(";", ":", "'", "\"", "<", ">", ",", ".", "?", "/"),
                listOf("SPACE", "BACKSPACE", "CLEAR", "ABC", "DONE"),
            )
        } else {
            listOf(
                listOf("Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"),
                listOf("A", "S", "D", "F", "G", "H", "J", "K", "L"),
                listOf("Z", "X", "C", "V", "B", "N", "M"),
                listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0"),
                listOf("SPACE", "BACKSPACE", "CLEAR", "SYM", "CAPS", "DONE"),
            )
        }
    }

    fun pressKey(key: String) {
        when (key) {
            "SPACE" -> input += " "
            "BACKSPACE" -> {
                if (input.isNotEmpty()) {
                    input = input.dropLast(1)
                }
            }
            "CLEAR" -> input = ""
            "CAPS" -> capsLock = !capsLock
            "SYM" -> {
                isSymbols = true
                selectedRow = 0
                selectedCol = 0
                initializeKeyboard()
                return
            }
            "ABC" -> {
                isSymbols = false
                selectedRow = 0
                selectedCol = 0
                initializeKeyboard()
                return
            }
            "DONE" -> {
                onSubmit()
                return
            }
            else -> {
                input += if (!isSymbols && capsLock) {
                    key
                } else if (!isSymbols && !capsLock) {
                    key.lowercase()
                } else {
                    key
                }
            }
        }
        onInput(input)
    }

    fun focusKey(row: Int, col: Int) {
        selectedRow = row
        selectedCol = col
        runCatching { keyRequesters["$row:$col"]?.requestFocus() }
    }

    fun handleKey(row: Int, col: Int, event: KeyEvent): Boolean {
        if (event.type != KeyEventType.KeyDown) return false
        val currentRow = keyboardLayout.getOrNull(row)
        return when (event.key) {
            Key.DirectionUp -> {
                val nr = (row - 1).coerceAtLeast(0)
                focusKey(nr, selectedCol.coerceAtMost(keyboardLayout.getOrNull(nr)?.lastIndex ?: 0))
                true
            }
            Key.DirectionDown -> {
                val nr = (row + 1).coerceAtMost(keyboardLayout.lastIndex)
                focusKey(nr, selectedCol.coerceAtMost(keyboardLayout.getOrNull(nr)?.lastIndex ?: 0))
                true
            }
            Key.DirectionLeft -> {
                if (col == 0) onMoveLeft?.invoke()
                else focusKey(row, col - 1)
                true
            }
            Key.DirectionRight -> {
                if (currentRow != null && col == currentRow.lastIndex) onMoveRight?.invoke()
                else focusKey(row, (col + 1).coerceAtMost(currentRow?.lastIndex ?: 0))
                true
            }
            Key.Enter, Key.DirectionCenter -> {
                val key = keyboardLayout.getOrNull(row)?.getOrNull(col)
                if (key != null) pressKey(key)
                true
            }
            Key.Escape, Key.Back -> {
                onMoveLeft?.invoke()
                true
            }
            else -> {
                // Physical keyboard: type the letter/digit itself instead of the
                // stale (0,0) "Q" the old whole-column handler fell back to.
                val ch = event.nativeKeyEvent?.unicodeChar
                if (ch != null && ch != 0 && (ch.toChar().isLetterOrDigit() || ch.toChar() == ' ')) {
                    pressKey(ch.toChar().toString())
                    true
                } else {
                    false
                }
            }
        }
    }

    LaunchedEffect(Unit) {
        initializeKeyboard()
        focusManager?.activateKeyboard()
        // Seed focus onto the first key so the remote's D-pad lands in the grid.
        runCatching { keyboardFocusRequester.requestFocus() }
        focusKey(0, 0)
    }

    Column(
        modifier = modifier
            .focusRequester(keyboardFocusRequester)
            .focusable()
            .onKeyEvent { event ->
                // Root fallback: when the whole keyboard (not a specific key) has
                // focus (e.g. after a re-seed), delegate to the current cell so
                // D-pad / OK behave as if that key were focused.
                if (event.type == KeyEventType.KeyDown && event.key in KEY_NAV_KEYS) {
                    handleKey(selectedRow, selectedCol, event)
                } else false
            }
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0xFF2A2A2A), RoundedCornerShape(12.dp))
                .border(2.dp, Color.Gray, RoundedCornerShape(12.dp))
                .padding(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                androidx.compose.material3.Text(
                    text = if (input.isEmpty()) "Start typing..." else input,
                    color = if (input.isEmpty()) Color.Gray else Color.White,
                    fontSize = 20.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                if (input.isNotEmpty()) {
                    androidx.compose.material3.Text(
                        text = "Clear",
                        color = Color.Red,
                        fontSize = 20.sp,
                        modifier = Modifier
                            .clickable {
                                input = ""
                                onInput("")
                            }
                            .padding(start = 8.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            keyboardLayout.forEachIndexed { rowIndex, row ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = if (rowIndex < keyboardLayout.lastIndex) 8.dp else 0.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    row.forEachIndexed { colIndex, key ->
                        val isFocused = selectedRow == rowIndex && selectedCol == colIndex
                        val isSpecial = key in listOf("SPACE", "BACKSPACE", "CLEAR", "SYM", "ABC", "CAPS", "DONE")

                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(52.dp)
                                .clip(RoundedCornerShape(6.dp))
                                .background(
                                    when {
                                        isFocused -> Color(0xFFE50914)
                                        isSpecial -> Color(0xFF666666)
                                        else -> Color(0xFF4D4D4D)
                                    }
                                )
                                .border(
                                    width = if (isFocused) 2.dp else 1.dp,
                                    color = if (isFocused) Color.White else Color.Transparent,
                                    shape = RoundedCornerShape(6.dp)
                                )
                                .focusRequester(keyRequesters.getOrPut("$rowIndex:$colIndex") { FocusRequester() })
                                .onFocusChanged { state -> if (state.hasFocus) { selectedRow = rowIndex; selectedCol = colIndex } }
                                .onKeyEvent { event -> handleKey(rowIndex, colIndex, event) }
                                .clickable { pressKey(key) },
                            contentAlignment = Alignment.Center
                        ) {
                            androidx.compose.material3.Text(
                                text = key,
                                color = if (isFocused) Color.White else Color.White.copy(alpha = 0.7f),
                                fontSize = if (key.length > 4) 14.sp else 20.sp,
                                fontWeight = if (isFocused) FontWeight.Bold else FontWeight.Normal,
                                textAlign = TextAlign.Center,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                if (!isSymbols) {
                    TvKeyboardStatusBadge(
                        label = "CAPS",
                        isActive = capsLock,
                        modifier = Modifier.padding(end = 16.dp)
                    )
                }
                TvKeyboardStatusBadge(
                    label = if (isSymbols) "ABC" else "SYM",
                    isActive = isSymbols
                )
            }
        }
    }
}

private val KEY_NAV_KEYS = setOf(
    Key.DirectionUp, Key.DirectionDown, Key.DirectionLeft, Key.DirectionRight,
    Key.Enter, Key.DirectionCenter,
)

@Composable
private fun TvKeyboardStatusBadge(
    label: String,
    isActive: Boolean,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(if (isActive) Color(0xFFE50914) else Color(0xFF666666))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        androidx.compose.material3.Text(
            text = label,
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
    }
}