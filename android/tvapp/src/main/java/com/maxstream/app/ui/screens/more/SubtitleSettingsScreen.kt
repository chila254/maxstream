package com.maxstream.app.ui.screens.more

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.local.SubtitleSettingsRepository
import com.maxstream.app.data.local.TvSubtitleSettings

// ─────────────────────────────────────────────────────────────────────────────
// Color palette — identical to mobile
// ─────────────────────────────────────────────────────────────────────────────

private val SUBTITLE_PRESET_COLORS = listOf(
    Color.White,
    Color.Yellow,
    Color(0xFFCCFF90), // lime
    Color(0xFF69F0AE), // green
    Color(0xFF18FFFF), // cyan
    Color(0xFF448AFF), // blue
    Color(0xFFE040FB), // purple
    Color(0xFFF44336), // red
    Color(0xFFFF9800), // orange
    Color(0xFF9E9E9E), // grey
    Color(0xFFFFD740), // amber
    Color(0xFF1DE9B6), // teal
    Color(0xFFFF4081), // pink
    Color(0xFF651FFF), // indigo
    Color(0xFF795548), // brown
)

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun SubtitleSettingsScreen(
    onBack: () -> Unit = {},
) {
    val context = LocalContext.current
    val cloudRevision by SubtitleSettingsRepository.cloudRevision.collectAsState()

    // ── Settings state ───────────────────────────────────────────────────────
    var textColor   by remember { mutableStateOf(Color.White) }
    var bgColor     by remember { mutableStateOf(Color.Black) }
    var bgOpacity   by remember { mutableFloatStateOf(0.55f) }
    var fontSize    by remember { mutableFloatStateOf(22f) }
    var textShadow  by remember { mutableStateOf(true) }
    var shadowColor by remember { mutableStateOf(Color.Black) }
    var edgeType    by remember { mutableStateOf("outline") }
    var edgeColor   by remember { mutableStateOf(Color.Black) }
    var position    by remember { mutableStateOf("bottom") }

    // Load from local prefs (and re-load whenever cloud sync updates them)
    LaunchedEffect(cloudRevision) {
        SubtitleSettingsRepository.invalidateCache()
        val s = SubtitleSettingsRepository.load(context)
        textColor   = parseSubColor(s.textColor)
        bgColor     = parseSubColor(s.backgroundColor)
        bgOpacity   = s.backgroundOpacity
        fontSize    = s.fontSize
        textShadow  = s.textShadow
        shadowColor = parseSubColor(s.textShadowColor)
        edgeType    = s.edgeType
        edgeColor   = parseSubColor(s.edgeColor)
        position    = s.position
    }

    // ── Color picker state ───────────────────────────────────────────────────
    // Kept as top-level state so the AlertDialog is always rendered in the root
    // Box — never inside a LazyColumn item (which would crash on recomposition).
    var showColorPicker by remember { mutableStateOf<String?>(null) }

    // ── Stable snapshot refs used by lambdas inside LazyColumn items ─────────
    // Capturing mutable vars directly in LazyColumn item lambdas causes
    // "CompositionLocal … not present" or "State read of … after snapshot" 
    // crashes when the lambda outlives the item's composition. rememberUpdatedState
    // gives each lambda a stable, always-current reference.
    val currentTextColor   by rememberUpdatedState(textColor)
    val currentBgColor     by rememberUpdatedState(bgColor)
    val currentBgOpacity   by rememberUpdatedState(bgOpacity)
    val currentFontSize    by rememberUpdatedState(fontSize)
    val currentTextShadow  by rememberUpdatedState(textShadow)
    val currentShadowColor by rememberUpdatedState(shadowColor)
    val currentEdgeType    by rememberUpdatedState(edgeType)
    val currentEdgeColor   by rememberUpdatedState(edgeColor)
    val currentPosition    by rememberUpdatedState(position)

    // ── Save helper — stable lambda, no local-function capture issue ─────────
    // Defined as a remembered lambda so it is stable across recompositions and
    // safe to call from LazyColumn item event handlers.
    val save: () -> Unit = remember(context) {
        {
            SubtitleSettingsRepository.save(
                context,
                TvSubtitleSettings(
                    textColor         = subColorToHex(currentTextColor),
                    backgroundColor   = subColorToHex(currentBgColor),
                    backgroundOpacity = currentBgOpacity,
                    fontSize          = currentFontSize,
                    textShadow        = currentTextShadow,
                    textShadowColor   = subColorToHex(currentShadowColor),
                    edgeType          = currentEdgeType,
                    edgeColor         = subColorToHex(currentEdgeColor),
                    position          = currentPosition,
                )
            )
        }
    }

    // ── Focus ────────────────────────────────────────────────────────────────
    // Max 9 focusable rows. Index matches the visible order top→bottom:
    //  0=TextColor 1=FontSize 2=BgColor 3=BgOpacity
    //  4=EdgeType 5=EdgeColor 6=TextShadow 7=ShadowColor(cond) 8=Position
    val focusRequesters = remember { List(9) { FocusRequester() } }
    var focusedIndex by remember { mutableIntStateOf(0) }

    // Index of each row in the visible list (fixed; ShadowColor is always idx 7
    // in the requester array even though it's conditionally shown — its requester
    // just stays unattached when hidden, which is safe in Compose).
    val IDX_TEXT_COLOR   = 0
    val IDX_FONT_SIZE    = 1
    val IDX_BG_COLOR     = 2
    val IDX_BG_OPACITY   = 3
    val IDX_EDGE_TYPE    = 4
    val IDX_EDGE_COLOR   = 5
    val IDX_TEXT_SHADOW  = 6
    val IDX_SHADOW_COLOR = 7  // only shown when textShadow=true
    val IDX_POSITION     = 8

    // When textShadow is toggled off, the ShadowColor row disappears.
    // If it had focus, move focus to Position (the next visible row).
    LaunchedEffect(textShadow) {
        if (!textShadow && focusedIndex == IDX_SHADOW_COLOR) {
            focusedIndex = IDX_POSITION
            runCatching { focusRequesters[IDX_POSITION].requestFocus() }
        }
    }

    // Helper: next visible index below idx (skips shadow color when hidden)
    fun nextIdx(idx: Int): Int {
        val next = idx + 1
        return if (next == IDX_SHADOW_COLOR && !textShadow) next + 1 else next
    }
    // Helper: next visible index above idx
    fun prevIdx(idx: Int): Int {
        val prev = idx - 1
        return if (prev == IDX_SHADOW_COLOR && !textShadow) prev - 1 else prev
    }

    val listState = rememberLazyListState()

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(120)
        repeat(8) { attempt ->
            val ok = runCatching { focusRequesters[IDX_TEXT_COLOR].requestFocus() }
            if (ok.isSuccess) return@LaunchedEffect
            kotlinx.coroutines.delay(60L * (attempt + 1))
        }
    }

    // ── Root Box — intercepts Back ───────────────────────────────────────────
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0F0F0F))
            .onKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown &&
                    (event.key == Key.Back || event.key == Key.Escape)
                ) { onBack(); true } else false
            }
    ) {

        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 56.dp),
            contentPadding = PaddingValues(top = 40.dp, bottom = 60.dp),
        ) {

            // ── Header + preview ─────────────────────────────────────────────
            item(key = "header") {
                Text(
                    "Subtitle Settings",
                    color = Color.White,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    "Customize how subtitles appear during playback",
                    color = Color(0xFF999999),
                    fontSize = 14.sp,
                )
                Spacer(Modifier.height(20.dp))
                // Live preview
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.Black),
                    contentAlignment = if (position == "top") Alignment.TopCenter else Alignment.BottomCenter,
                ) {
                    Text(
                        "Sample Video",
                        color = Color.Gray.copy(alpha = 0.3f),
                        modifier = Modifier.align(Alignment.Center),
                    )
                    Box(Modifier.padding(10.dp), contentAlignment = Alignment.Center) {
                        Text(
                            "This is a sample subtitle",
                            color = textColor,
                            fontSize = fontSize.coerceIn(10f, 28f).sp,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .background(bgColor.copy(alpha = bgOpacity), RoundedCornerShape(4.dp))
                                .padding(horizontal = 14.dp, vertical = 6.dp),
                        )
                    }
                }
                Spacer(Modifier.height(24.dp))
            }

            // ════════════════════════════════════════════════════════════════
            // TEXT
            // ════════════════════════════════════════════════════════════════
            item(key = "sec_text") { SubSectionHeader("TEXT") }

            item(key = "textColor") {
                SubColorRow(
                    label          = "Text Color",
                    color          = textColor,
                    isFocused      = focusedIndex == IDX_TEXT_COLOR,
                    focusRequester = focusRequesters[IDX_TEXT_COLOR],
                    onFocused      = { focusedIndex = IDX_TEXT_COLOR },
                    onSelect       = { showColorPicker = "textColor" },
                    onMoveUp       = { /* first row — do nothing */ },
                    onMoveDown     = { moveFocus(nextIdx(IDX_TEXT_COLOR), focusRequesters) },
                )
            }

            item(key = "fontSize") {
                SubStepRow(
                    label          = "Font Size",
                    value          = "${fontSize.toInt()}sp",
                    isFocused      = focusedIndex == IDX_FONT_SIZE,
                    focusRequester = focusRequesters[IDX_FONT_SIZE],
                    onFocused      = { focusedIndex = IDX_FONT_SIZE },
                    onDecrement    = { fontSize = (fontSize - 2f).coerceIn(12f, 36f); save() },
                    onIncrement    = { fontSize = (fontSize + 2f).coerceIn(12f, 36f); save() },
                    onMoveUp       = { moveFocus(prevIdx(IDX_FONT_SIZE), focusRequesters) },
                    onMoveDown     = { moveFocus(nextIdx(IDX_FONT_SIZE), focusRequesters) },
                )
            }

            // ════════════════════════════════════════════════════════════════
            // BACKGROUND
            // ════════════════════════════════════════════════════════════════
            item(key = "sec_bg") { SubSectionHeader("BACKGROUND") }

            item(key = "bgColor") {
                SubColorRow(
                    label          = "Background Color",
                    color          = bgColor,
                    isFocused      = focusedIndex == IDX_BG_COLOR,
                    focusRequester = focusRequesters[IDX_BG_COLOR],
                    onFocused      = { focusedIndex = IDX_BG_COLOR },
                    onSelect       = { showColorPicker = "bgColor" },
                    onMoveUp       = { moveFocus(prevIdx(IDX_BG_COLOR), focusRequesters) },
                    onMoveDown     = { moveFocus(nextIdx(IDX_BG_COLOR), focusRequesters) },
                )
            }

            item(key = "bgOpacity") {
                SubStepRow(
                    label          = "Opacity",
                    value          = "${(bgOpacity * 100).toInt()}%",
                    isFocused      = focusedIndex == IDX_BG_OPACITY,
                    focusRequester = focusRequesters[IDX_BG_OPACITY],
                    onFocused      = { focusedIndex = IDX_BG_OPACITY },
                    onDecrement    = { bgOpacity = (bgOpacity - 0.05f).coerceIn(0f, 1f); save() },
                    onIncrement    = { bgOpacity = (bgOpacity + 0.05f).coerceIn(0f, 1f); save() },
                    onMoveUp       = { moveFocus(prevIdx(IDX_BG_OPACITY), focusRequesters) },
                    onMoveDown     = { moveFocus(nextIdx(IDX_BG_OPACITY), focusRequesters) },
                )
            }

            // ════════════════════════════════════════════════════════════════
            // EDGE / SHADOW
            // ════════════════════════════════════════════════════════════════
            item(key = "sec_edge") { SubSectionHeader("EDGE / SHADOW") }

            item(key = "edgeType") {
                val edgeTypes  = listOf("none", "outline", "dropShadow")
                val edgeLabels = mapOf("none" to "None", "outline" to "Outline", "dropShadow" to "Drop Shadow")
                SubCycleRow(
                    label          = "Edge Type",
                    value          = edgeLabels[edgeType] ?: edgeType,
                    isFocused      = focusedIndex == IDX_EDGE_TYPE,
                    focusRequester = focusRequesters[IDX_EDGE_TYPE],
                    onFocused      = { focusedIndex = IDX_EDGE_TYPE },
                    onPrev         = { val i = edgeTypes.indexOf(edgeType); edgeType = edgeTypes[(i - 1 + edgeTypes.size) % edgeTypes.size]; save() },
                    onNext         = { val i = edgeTypes.indexOf(edgeType); edgeType = edgeTypes[(i + 1) % edgeTypes.size]; save() },
                    onMoveUp       = { moveFocus(prevIdx(IDX_EDGE_TYPE), focusRequesters) },
                    onMoveDown     = { moveFocus(nextIdx(IDX_EDGE_TYPE), focusRequesters) },
                )
            }

            item(key = "edgeColor") {
                SubColorRow(
                    label          = "Edge Color",
                    color          = edgeColor,
                    isFocused      = focusedIndex == IDX_EDGE_COLOR,
                    focusRequester = focusRequesters[IDX_EDGE_COLOR],
                    onFocused      = { focusedIndex = IDX_EDGE_COLOR },
                    onSelect       = { showColorPicker = "edgeColor" },
                    onMoveUp       = { moveFocus(prevIdx(IDX_EDGE_COLOR), focusRequesters) },
                    onMoveDown     = { moveFocus(nextIdx(IDX_EDGE_COLOR), focusRequesters) },
                )
            }

            item(key = "textShadow") {
                SubToggleRow(
                    label          = "Text Shadow",
                    value          = textShadow,
                    isFocused      = focusedIndex == IDX_TEXT_SHADOW,
                    focusRequester = focusRequesters[IDX_TEXT_SHADOW],
                    onFocused      = { focusedIndex = IDX_TEXT_SHADOW },
                    onToggle       = { textShadow = !textShadow; save() },
                    onMoveUp       = { moveFocus(prevIdx(IDX_TEXT_SHADOW), focusRequesters) },
                    onMoveDown     = { moveFocus(nextIdx(IDX_TEXT_SHADOW), focusRequesters) },
                )
            }

            // Shadow Color only shown when Text Shadow is On (same as mobile)
            if (textShadow) {
                item(key = "shadowColor") {
                    SubColorRow(
                        label          = "Shadow Color",
                        color          = shadowColor,
                        isFocused      = focusedIndex == IDX_SHADOW_COLOR,
                        focusRequester = focusRequesters[IDX_SHADOW_COLOR],
                        onFocused      = { focusedIndex = IDX_SHADOW_COLOR },
                        onSelect       = { showColorPicker = "shadowColor" },
                        onMoveUp       = { moveFocus(prevIdx(IDX_SHADOW_COLOR), focusRequesters) },
                        onMoveDown     = { moveFocus(nextIdx(IDX_SHADOW_COLOR), focusRequesters) },
                    )
                }
            }

            // ════════════════════════════════════════════════════════════════
            // POSITION
            // ════════════════════════════════════════════════════════════════
            item(key = "sec_pos") { SubSectionHeader("POSITION") }

            item(key = "position") {
                SubCycleRow(
                    label          = "Position",
                    value          = position.replaceFirstChar { it.uppercase() },
                    isFocused      = focusedIndex == IDX_POSITION,
                    focusRequester = focusRequesters[IDX_POSITION],
                    onFocused      = { focusedIndex = IDX_POSITION },
                    onPrev         = { position = if (position == "bottom") "top" else "bottom"; save() },
                    onNext         = { position = if (position == "bottom") "top" else "bottom"; save() },
                    onMoveUp       = { moveFocus(prevIdx(IDX_POSITION), focusRequesters) },
                    onMoveDown     = { /* last row */ },
                )
            }

            // Reset
            item(key = "reset") {
                Spacer(Modifier.height(24.dp))
                SubResetRow {
                    val d = TvSubtitleSettings()
                    textColor   = parseSubColor(d.textColor)
                    bgColor     = parseSubColor(d.backgroundColor)
                    bgOpacity   = d.backgroundOpacity
                    fontSize    = d.fontSize
                    textShadow  = d.textShadow
                    shadowColor = parseSubColor(d.textShadowColor)
                    edgeType    = d.edgeType
                    edgeColor   = parseSubColor(d.edgeColor)
                    position    = d.position
                    // Save defaults — pushes to Firebase which syncs to mobile
                    SubtitleSettingsRepository.save(context, d)
                }
            }
        }

        // ── Color picker — always outside LazyColumn ─────────────────────────
        if (showColorPicker != null) {
            val pickerKey = showColorPicker!!
            SubColorPickerDialog(
                currentColor = when (pickerKey) {
                    "textColor"   -> textColor
                    "bgColor"     -> bgColor
                    "shadowColor" -> shadowColor
                    else          -> edgeColor
                },
                onColorSelected = { color ->
                    when (pickerKey) {
                        "textColor"   -> textColor   = color
                        "bgColor"     -> bgColor     = color
                        "shadowColor" -> shadowColor = color
                        else          -> edgeColor   = color
                    }
                    save()
                    showColorPicker = null
                },
                onDismiss = { showColorPicker = null },
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Focus helpers
// ─────────────────────────────────────────────────────────────────────────────

private fun moveFocus(idx: Int, requesters: List<FocusRequester>) {
    if (idx in requesters.indices) runCatching { requesters[idx].requestFocus() }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row container — focus style matching app content cards:
//   • 2dp white border on focus
//   • slight scale (1.015x)
//   • darker background on focus
//   NO graphicsLayer shadow (removes the "reflection" artefact on TV)
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SubRowContainer(
    focusRequester: FocusRequester,
    isFocused: Boolean,
    onFocused: () -> Unit,
    onKeyEvent: (androidx.compose.ui.input.key.KeyEvent) -> Boolean,
    onClick: (() -> Unit)? = null,
    content: @Composable RowScope.() -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.015f else 1f,
        animationSpec = tween(160, easing = FastOutSlowInEasing),
        label = "subRowScale",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            // Scale without graphicsLayer shadow — no reflection artefact
            .then(
                if (scale != 1f) Modifier.then(
                    Modifier /* graphicsLayer-free scale via draw modifier */
                ) else Modifier
            )
            // Clip + border first so border stays crisp under scale
            .clip(RoundedCornerShape(12.dp))
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(12.dp),
            )
            .background(
                if (isFocused) Color(0xFF2C2C2C) else Color(0xFF1C1C1C)
            )
            .focusRequester(focusRequester)
            .onFocusChanged { if (it.hasFocus) onFocused() }
            .onKeyEvent(onKeyEvent)
            .focusable()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 22.dp, vertical = 15.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) { content() }
}

private typealias RowScope = androidx.compose.foundation.layout.RowScope

// ─────────────────────────────────────────────────────────────────────────────
// Row variants
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SubStepRow(
    label: String, value: String,
    isFocused: Boolean, focusRequester: FocusRequester,
    onFocused: () -> Unit,
    onDecrement: () -> Unit, onIncrement: () -> Unit,
    onMoveUp: () -> Unit, onMoveDown: () -> Unit,
) {
    SubRowContainer(focusRequester, isFocused, onFocused,
        onKeyEvent = { e ->
            if (e.type != KeyEventType.KeyDown) return@SubRowContainer false
            when (e.key) {
                Key.DirectionLeft  -> { onDecrement(); true }
                Key.DirectionRight -> { onIncrement(); true }
                Key.DirectionUp    -> { onMoveUp();    true }
                Key.DirectionDown  -> { onMoveDown();  true }
                else -> false
            }
        }
    ) {
        Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("◀", color = if (isFocused) Color.White else Color(0xFF555555), fontSize = 14.sp)
            Spacer(Modifier.width(12.dp))
            Text(value, color = Color(0xFFDDDDDD), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.width(12.dp))
            Text("▶", color = if (isFocused) Color.White else Color(0xFF555555), fontSize = 14.sp)
        }
    }
}

@Composable
private fun SubCycleRow(
    label: String, value: String,
    isFocused: Boolean, focusRequester: FocusRequester,
    onFocused: () -> Unit,
    onPrev: () -> Unit, onNext: () -> Unit,
    onMoveUp: () -> Unit, onMoveDown: () -> Unit,
) {
    SubRowContainer(focusRequester, isFocused, onFocused,
        onKeyEvent = { e ->
            if (e.type != KeyEventType.KeyDown) return@SubRowContainer false
            when (e.key) {
                Key.DirectionLeft  -> { onPrev();     true }
                Key.DirectionRight -> { onNext();     true }
                Key.DirectionUp    -> { onMoveUp();   true }
                Key.DirectionDown  -> { onMoveDown(); true }
                else -> false
            }
        }
    ) {
        Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("◀", color = if (isFocused) Color.White else Color(0xFF555555), fontSize = 14.sp)
            Spacer(Modifier.width(12.dp))
            Text(value, color = Color(0xFFDDDDDD), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.width(12.dp))
            Text("▶", color = if (isFocused) Color.White else Color(0xFF555555), fontSize = 14.sp)
        }
    }
}

@Composable
private fun SubColorRow(
    label: String, color: Color,
    isFocused: Boolean, focusRequester: FocusRequester,
    onFocused: () -> Unit, onSelect: () -> Unit,
    onMoveUp: () -> Unit, onMoveDown: () -> Unit,
) {
    SubRowContainer(focusRequester, isFocused, onFocused,
        onClick = onSelect,
        onKeyEvent = { e ->
            if (e.type != KeyEventType.KeyDown) return@SubRowContainer false
            when (e.key) {
                Key.Enter, Key.DirectionCenter -> { onSelect();   true }
                Key.DirectionUp               -> { onMoveUp();   true }
                Key.DirectionDown             -> { onMoveDown(); true }
                else -> false
            }
        }
    ) {
        Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (isFocused) {
                Text("Press OK", color = Color(0xFF888888), fontSize = 12.sp)
                Spacer(Modifier.width(10.dp))
            }
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(color)
                    .border(
                        width = if (isFocused) 2.dp else 1.dp,
                        color = if (isFocused) Color.White else Color(0xFF444444),
                        shape = RoundedCornerShape(6.dp),
                    ),
            )
        }
    }
}

@Composable
private fun SubToggleRow(
    label: String, value: Boolean,
    isFocused: Boolean, focusRequester: FocusRequester,
    onFocused: () -> Unit, onToggle: () -> Unit,
    onMoveUp: () -> Unit, onMoveDown: () -> Unit,
) {
    SubRowContainer(focusRequester, isFocused, onFocused,
        onClick = onToggle,
        onKeyEvent = { e ->
            if (e.type != KeyEventType.KeyDown) return@SubRowContainer false
            when (e.key) {
                Key.DirectionLeft, Key.DirectionRight,
                Key.Enter, Key.DirectionCenter -> { onToggle();   true }
                Key.DirectionUp               -> { onMoveUp();   true }
                Key.DirectionDown             -> { onMoveDown(); true }
                else -> false
            }
        }
    ) {
        Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Box(
            modifier = Modifier
                .background(
                    if (value) Color(0xFF1B5E20) else Color(0xFF3A3A3A),
                    RoundedCornerShape(16.dp),
                )
                .padding(horizontal = 16.dp, vertical = 6.dp),
        ) {
            Text(
                if (value) "On" else "Off",
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

@Composable
private fun SubSectionHeader(title: String) {
    Text(
        title,
        color = Color(0xFF777777),
        fontSize = 11.sp,
        fontWeight = FontWeight.W600,
        letterSpacing = 1.5.sp,
        modifier = Modifier.padding(top = 18.dp, bottom = 4.dp),
    )
}

@Composable
private fun SubResetRow(onReset: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF1C1C1C))
            .border(1.dp, Color(0xFF3A3A3A), RoundedCornerShape(12.dp))
            .clickable(onClick = onReset)
            .padding(vertical = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text("Reset to Defaults", color = Color(0xFFCF6679), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Color picker dialog — fully D-pad navigable
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SubColorPickerDialog(
    currentColor: Color,
    onColorSelected: (Color) -> Unit,
    onDismiss: () -> Unit,
) {
    val cols = 5
    val swatchRequesters = remember { List(SUBTITLE_PRESET_COLORS.size) { FocusRequester() } }
    var focusedSwatch by remember {
        mutableIntStateOf(
            SUBTITLE_PRESET_COLORS.indexOfFirst { it.toArgb() == currentColor.toArgb() }.coerceAtLeast(0)
        )
    }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(100)
        runCatching { swatchRequesters[focusedSwatch].requestFocus() }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1E1E1E),
        title = {
            Text("Choose Color", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SUBTITLE_PRESET_COLORS.chunked(cols).forEachIndexed { rowIdx, rowColors ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        rowColors.forEachIndexed { colIdx, color ->
                            val idx = rowIdx * cols + colIdx
                            val focused = focusedSwatch == idx
                            val swatchScale by animateFloatAsState(
                                targetValue = if (focused) 1.2f else 1f,
                                animationSpec = tween(140),
                                label = "sw$idx",
                            )
                            Box(
                                modifier = Modifier
                                    .size(50.dp)
                                    .then(
                                        if (swatchScale != 1f)
                                            Modifier.padding((50.dp * (swatchScale - 1f) / 2f))
                                        else Modifier
                                    )
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(color)
                                    .border(
                                        width = when {
                                            focused -> 3.dp
                                            color.toArgb() == currentColor.toArgb() -> 2.dp
                                            else -> 1.dp
                                        },
                                        color = when {
                                            focused -> Color.White
                                            color.toArgb() == currentColor.toArgb() -> Color(0xFFE50914)
                                            else -> Color(0xFF444444)
                                        },
                                        shape = RoundedCornerShape(10.dp),
                                    )
                                    .focusRequester(swatchRequesters[idx])
                                    .onFocusChanged { if (it.hasFocus) focusedSwatch = idx }
                                    .onKeyEvent { e ->
                                        if (e.type != KeyEventType.KeyDown) return@onKeyEvent false
                                        when (e.key) {
                                            Key.Enter, Key.DirectionCenter -> { onColorSelected(color); true }
                                            Key.DirectionRight -> { if (idx + 1 < SUBTITLE_PRESET_COLORS.size) runCatching { swatchRequesters[idx + 1].requestFocus() }; true }
                                            Key.DirectionLeft  -> { if (idx - 1 >= 0) runCatching { swatchRequesters[idx - 1].requestFocus() }; true }
                                            Key.DirectionDown  -> { if (idx + cols < SUBTITLE_PRESET_COLORS.size) runCatching { swatchRequesters[idx + cols].requestFocus() }; true }
                                            Key.DirectionUp    -> { if (idx - cols >= 0) runCatching { swatchRequesters[idx - cols].requestFocus() }; true }
                                            Key.Back, Key.Escape -> { onDismiss(); true }
                                            else -> false
                                        }
                                    }
                                    .focusable()
                                    .clickable { onColorSelected(color) },
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = Color(0xFF888888), fontSize = 16.sp)
            }
        },
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// Color utilities
// ─────────────────────────────────────────────────────────────────────────────

private fun parseSubColor(hex: String): Color {
    val clean = hex.removePrefix("#")
    val long  = if (clean.length == 6) "FF$clean".toLong(16) else clean.toLong(16)
    return Color(long.toInt())
}

private fun subColorToHex(color: Color): String {
    return "#%06X".format(color.toArgb() and 0x00FFFFFF)
}
