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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
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
// Color palette — matches mobile's _showColorPicker list
// ─────────────────────────────────────────────────────────────────────────────

private val PRESET_COLORS = listOf(
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
// Row types — one enum drives the entire focusable row list
// ─────────────────────────────────────────────────────────────────────────────

private enum class RowId {
    FontSize,
    TextColor,
    BgColor,
    BgOpacity,
    EdgeType,
    EdgeColor,
    TextShadow,
    ShadowColor,   // only shown when textShadow == true, like on mobile
    Position,
}

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

    // Re-read when cloud sync bumps revision
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

    // ── Computed visible row list ────────────────────────────────────────────
    // ShadowColor row appears only when textShadow is On, exactly like mobile
    val visibleRows: List<RowId> = remember(textShadow) {
        buildList {
            add(RowId.FontSize)
            add(RowId.TextColor)
            add(RowId.BgColor)
            add(RowId.BgOpacity)
            add(RowId.EdgeType)
            add(RowId.EdgeColor)
            add(RowId.TextShadow)
            if (textShadow) add(RowId.ShadowColor)
            add(RowId.Position)
        }
    }

    // One FocusRequester per slot (max 9 rows)
    val focusRequesters = remember { List(9) { FocusRequester() } }
    var focusedIndex by remember { mutableIntStateOf(0) }

    // ── Color picker state — kept OUTSIDE LazyColumn to avoid recomposition crash
    var showColorPicker by remember { mutableStateOf<String?>(null) }

    // ── Persist helper ───────────────────────────────────────────────────────
    fun save() {
        SubtitleSettingsRepository.save(
            context,
            TvSubtitleSettings(
                textColor         = subColorToHex(textColor),
                backgroundColor   = subColorToHex(bgColor),
                backgroundOpacity = bgOpacity,
                fontSize          = fontSize,
                textShadow        = textShadow,
                textShadowColor   = subColorToHex(shadowColor),
                edgeType          = edgeType,
                edgeColor         = subColorToHex(edgeColor),
                position          = position,
            )
        )
    }

    // ── Seed focus on open ───────────────────────────────────────────────────
    val listState = rememberLazyListState()
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(120)
        repeat(8) { attempt ->
            val ok = runCatching { focusRequesters[0].requestFocus() }
            if (ok.isSuccess) return@LaunchedEffect
            kotlinx.coroutines.delay(60L * (attempt + 1))
        }
    }

    // ── Root Box — catches Back before TvAppRoot's handleBack() ─────────────
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

        // ── Content list ─────────────────────────────────────────────────────
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 56.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                top = 40.dp, bottom = 60.dp
            ),
        ) {
            // Header
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
                Spacer(Modifier.height(24.dp))

                // ── Live preview ─────────────────────────────────────────────
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(130.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.Black),
                    contentAlignment = if (position == "top") Alignment.TopCenter else Alignment.BottomCenter,
                ) {
                    Text(
                        "Sample Video",
                        color = Color.Gray.copy(alpha = 0.35f),
                        modifier = Modifier.align(Alignment.Center),
                    )
                    Box(
                        modifier = Modifier.padding(10.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            "This is a sample subtitle",
                            color = textColor,
                            fontSize = fontSize.coerceIn(10f, 28f).sp,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .background(
                                    bgColor.copy(alpha = bgOpacity),
                                    RoundedCornerShape(4.dp),
                                )
                                .padding(horizontal = 14.dp, vertical = 6.dp),
                        )
                    }
                }
                Spacer(Modifier.height(28.dp))
            }

            // ── TEXT section ─────────────────────────────────────────────────
            item(key = "sec_text") { SectionHeader("TEXT") }

            item(key = RowId.TextColor.name) {
                val idx = visibleRows.indexOf(RowId.TextColor)
                ColorRow(
                    label        = "Text Color",
                    color        = textColor,
                    isFocused    = focusedIndex == idx,
                    focusRequester = focusRequesters[idx],
                    onFocused    = { focusedIndex = idx },
                    onSelect     = { showColorPicker = "textColor" },
                    onMoveUp     = { moveFocus(idx - 1, focusRequesters) },
                    onMoveDown   = { moveFocus(idx + 1, focusRequesters, visibleRows.size) },
                )
            }

            item(key = RowId.FontSize.name) {
                val idx = visibleRows.indexOf(RowId.FontSize)
                StepRow(
                    label        = "Font Size",
                    value        = "${fontSize.toInt()}sp",
                    isFocused    = focusedIndex == idx,
                    focusRequester = focusRequesters[idx],
                    onFocused    = { focusedIndex = idx },
                    onDecrement  = { fontSize = (fontSize - 2f).coerceIn(12f, 36f); save() },
                    onIncrement  = { fontSize = (fontSize + 2f).coerceIn(12f, 36f); save() },
                    onMoveUp     = { moveFocus(idx - 1, focusRequesters) },
                    onMoveDown   = { moveFocus(idx + 1, focusRequesters, visibleRows.size) },
                )
            }

            // ── BACKGROUND section ───────────────────────────────────────────
            item(key = "sec_bg") { SectionHeader("BACKGROUND") }

            item(key = RowId.BgColor.name) {
                val idx = visibleRows.indexOf(RowId.BgColor)
                ColorRow(
                    label        = "Background Color",
                    color        = bgColor,
                    isFocused    = focusedIndex == idx,
                    focusRequester = focusRequesters[idx],
                    onFocused    = { focusedIndex = idx },
                    onSelect     = { showColorPicker = "bgColor" },
                    onMoveUp     = { moveFocus(idx - 1, focusRequesters) },
                    onMoveDown   = { moveFocus(idx + 1, focusRequesters, visibleRows.size) },
                )
            }

            item(key = RowId.BgOpacity.name) {
                val idx = visibleRows.indexOf(RowId.BgOpacity)
                StepRow(
                    label        = "Opacity",
                    value        = "${(bgOpacity * 100).toInt()}%",
                    isFocused    = focusedIndex == idx,
                    focusRequester = focusRequesters[idx],
                    onFocused    = { focusedIndex = idx },
                    onDecrement  = { bgOpacity = (bgOpacity - 0.05f).coerceIn(0f, 1f); save() },
                    onIncrement  = { bgOpacity = (bgOpacity + 0.05f).coerceIn(0f, 1f); save() },
                    onMoveUp     = { moveFocus(idx - 1, focusRequesters) },
                    onMoveDown   = { moveFocus(idx + 1, focusRequesters, visibleRows.size) },
                )
            }

            // ── EDGE / SHADOW section ────────────────────────────────────────
            item(key = "sec_edge") { SectionHeader("EDGE / SHADOW") }

            item(key = RowId.EdgeType.name) {
                val edgeTypes  = listOf("none", "outline", "dropShadow")
                val edgeLabels = mapOf("none" to "None", "outline" to "Outline", "dropShadow" to "Drop Shadow")
                val idx = visibleRows.indexOf(RowId.EdgeType)
                CycleRow(
                    label        = "Edge Type",
                    value        = edgeLabels[edgeType] ?: edgeType,
                    isFocused    = focusedIndex == idx,
                    focusRequester = focusRequesters[idx],
                    onFocused    = { focusedIndex = idx },
                    onPrev       = { val i = edgeTypes.indexOf(edgeType); edgeType = edgeTypes[(i - 1 + edgeTypes.size) % edgeTypes.size]; save() },
                    onNext       = { val i = edgeTypes.indexOf(edgeType); edgeType = edgeTypes[(i + 1) % edgeTypes.size]; save() },
                    onMoveUp     = { moveFocus(idx - 1, focusRequesters) },
                    onMoveDown   = { moveFocus(idx + 1, focusRequesters, visibleRows.size) },
                )
            }

            item(key = RowId.EdgeColor.name) {
                val idx = visibleRows.indexOf(RowId.EdgeColor)
                ColorRow(
                    label        = "Edge Color",
                    color        = edgeColor,
                    isFocused    = focusedIndex == idx,
                    focusRequester = focusRequesters[idx],
                    onFocused    = { focusedIndex = idx },
                    onSelect     = { showColorPicker = "edgeColor" },
                    onMoveUp     = { moveFocus(idx - 1, focusRequesters) },
                    onMoveDown   = { moveFocus(idx + 1, focusRequesters, visibleRows.size) },
                )
            }

            item(key = RowId.TextShadow.name) {
                val idx = visibleRows.indexOf(RowId.TextShadow)
                ToggleRow(
                    label        = "Text Shadow",
                    value        = textShadow,
                    isFocused    = focusedIndex == idx,
                    focusRequester = focusRequesters[idx],
                    onFocused    = { focusedIndex = idx },
                    onToggle     = { textShadow = !textShadow; save() },
                    onMoveUp     = { moveFocus(idx - 1, focusRequesters) },
                    onMoveDown   = { moveFocus(idx + 1, focusRequesters, visibleRows.size) },
                )
            }

            // Shadow Color — only when shadow is On (matches mobile)
            if (textShadow) {
                item(key = RowId.ShadowColor.name) {
                    val idx = visibleRows.indexOf(RowId.ShadowColor)
                    ColorRow(
                        label        = "Shadow Color",
                        color        = shadowColor,
                        isFocused    = focusedIndex == idx,
                        focusRequester = focusRequesters[idx],
                        onFocused    = { focusedIndex = idx },
                        onSelect     = { showColorPicker = "shadowColor" },
                        onMoveUp     = { moveFocus(idx - 1, focusRequesters) },
                        onMoveDown   = { moveFocus(idx + 1, focusRequesters, visibleRows.size) },
                    )
                }
            }

            // ── POSITION section ─────────────────────────────────────────────
            item(key = "sec_pos") { SectionHeader("POSITION") }

            item(key = RowId.Position.name) {
                val idx = visibleRows.indexOf(RowId.Position)
                CycleRow(
                    label        = "Position",
                    value        = position.replaceFirstChar { it.uppercase() },
                    isFocused    = focusedIndex == idx,
                    focusRequester = focusRequesters[idx],
                    onFocused    = { focusedIndex = idx },
                    onPrev       = { position = if (position == "bottom") "top" else "bottom"; save() },
                    onNext       = { position = if (position == "bottom") "top" else "bottom"; save() },
                    onMoveUp     = { moveFocus(idx - 1, focusRequesters) },
                    onMoveDown   = { /* last row */ },
                )
            }

            // Reset button
            item(key = "reset") {
                Spacer(Modifier.height(24.dp))
                ResetRow(
                    onReset = {
                        val defaults = TvSubtitleSettings()
                        textColor   = parseSubColor(defaults.textColor)
                        bgColor     = parseSubColor(defaults.backgroundColor)
                        bgOpacity   = defaults.backgroundOpacity
                        fontSize    = defaults.fontSize
                        textShadow  = defaults.textShadow
                        shadowColor = parseSubColor(defaults.textShadowColor)
                        edgeType    = defaults.edgeType
                        edgeColor   = parseSubColor(defaults.edgeColor)
                        position    = defaults.position
                        SubtitleSettingsRepository.save(context, defaults)
                    }
                )
            }
        }

        // ── Color picker dialog — outside LazyColumn to avoid crash ──────────
        if (showColorPicker != null) {
            ColorPickerDialog(
                currentColor = when (showColorPicker) {
                    "textColor"   -> textColor
                    "bgColor"     -> bgColor
                    "shadowColor" -> shadowColor
                    "edgeColor"   -> edgeColor
                    else          -> Color.White
                },
                onColorSelected = { color ->
                    when (showColorPicker) {
                        "textColor"   -> textColor   = color
                        "bgColor"     -> bgColor     = color
                        "shadowColor" -> shadowColor = color
                        "edgeColor"   -> edgeColor   = color
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
// Focus helper
// ─────────────────────────────────────────────────────────────────────────────

private fun moveFocus(idx: Int, requesters: List<FocusRequester>, max: Int = Int.MAX_VALUE) {
    if (idx in 0 until minOf(requesters.size, max)) {
        runCatching { requesters[idx].requestFocus() }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared row base — TV focus style matching content cards:
//   • animated scale (1.02f on focus)
//   • 2dp white border with rounded corners
//   • subtle white glow via graphicsLayer shadowElevation
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SettingsRowContainer(
    focusRequester: FocusRequester,
    isFocused: Boolean,
    onFocused: () -> Unit,
    onKeyEvent: (androidx.compose.ui.input.key.KeyEvent) -> Boolean,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.02f else 1f,
        animationSpec = tween(180, easing = FastOutSlowInEasing),
        label = "rowScale",
    )
    val glowAlpha by animateFloatAsState(
        targetValue = if (isFocused) 0.25f else 0f,
        animationSpec = tween(180),
        label = "glowAlpha",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 5.dp)
            // Glow effect via shadow — matches ContentCard's white glow
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                shadowElevation = if (isFocused) 18f else 0f
                shape = RoundedCornerShape(12.dp)
                clip = true
                ambientShadowColor = Color.White
                spotShadowColor    = Color.White
            }
            .clip(RoundedCornerShape(12.dp))
            .background(if (isFocused) Color(0xFF242424) else Color(0xFF1A1A1A))
            // White border — matches content card focus ring
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White.copy(alpha = 0.85f) else Color.Transparent,
                shape = RoundedCornerShape(12.dp),
            )
            .focusRequester(focusRequester)
            .onFocusChanged { if (it.hasFocus) onFocused() }
            .onKeyEvent(onKeyEvent)
            .focusable()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 22.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        content()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row variants
// ─────────────────────────────────────────────────────────────────────────────

/** Left/Right to step a numeric value up/down */
@Composable
private fun StepRow(
    label: String,
    value: String,
    isFocused: Boolean,
    focusRequester: FocusRequester,
    onFocused: () -> Unit,
    onDecrement: () -> Unit,
    onIncrement: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
) {
    SettingsRowContainer(
        focusRequester = focusRequester,
        isFocused = isFocused,
        onFocused = onFocused,
        onKeyEvent = { event ->
            if (event.type != KeyEventType.KeyDown) return@SettingsRowContainer false
            when (event.key) {
                Key.DirectionLeft  -> { onDecrement(); true }
                Key.DirectionRight -> { onIncrement(); true }
                Key.DirectionUp    -> { onMoveUp();    true }
                Key.DirectionDown  -> { onMoveDown();  true }
                else -> false
            }
        },
    ) {
        Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("◀", color = if (isFocused) Color.White else Color(0xFF666666), fontSize = 13.sp)
            Spacer(Modifier.width(10.dp))
            Text(value, color = Color(0xFFCCCCCC), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.width(10.dp))
            Text("▶", color = if (isFocused) Color.White else Color(0xFF666666), fontSize = 13.sp)
        }
    }
}

/** Left/Right to cycle through options */
@Composable
private fun CycleRow(
    label: String,
    value: String,
    isFocused: Boolean,
    focusRequester: FocusRequester,
    onFocused: () -> Unit,
    onPrev: () -> Unit,
    onNext: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
) {
    SettingsRowContainer(
        focusRequester = focusRequester,
        isFocused = isFocused,
        onFocused = onFocused,
        onKeyEvent = { event ->
            if (event.type != KeyEventType.KeyDown) return@SettingsRowContainer false
            when (event.key) {
                Key.DirectionLeft  -> { onPrev();     true }
                Key.DirectionRight -> { onNext();     true }
                Key.DirectionUp    -> { onMoveUp();   true }
                Key.DirectionDown  -> { onMoveDown(); true }
                else -> false
            }
        },
    ) {
        Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("◀", color = if (isFocused) Color.White else Color(0xFF666666), fontSize = 13.sp)
            Spacer(Modifier.width(10.dp))
            Text(value, color = Color(0xFFCCCCCC), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.width(10.dp))
            Text("▶", color = if (isFocused) Color.White else Color(0xFF666666), fontSize = 13.sp)
        }
    }
}

/** Enter/OK opens color picker dialog */
@Composable
private fun ColorRow(
    label: String,
    color: Color,
    isFocused: Boolean,
    focusRequester: FocusRequester,
    onFocused: () -> Unit,
    onSelect: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
) {
    SettingsRowContainer(
        focusRequester = focusRequester,
        isFocused = isFocused,
        onFocused = onFocused,
        onClick = onSelect,
        onKeyEvent = { event ->
            if (event.type != KeyEventType.KeyDown) return@SettingsRowContainer false
            when (event.key) {
                Key.Enter, Key.DirectionCenter -> { onSelect();    true }
                Key.DirectionUp               -> { onMoveUp();    true }
                Key.DirectionDown             -> { onMoveDown();  true }
                else -> false
            }
        },
    ) {
        Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (isFocused) {
                Text("OK", color = Color(0xFF999999), fontSize = 13.sp)
                Spacer(Modifier.width(10.dp))
            }
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(color)
                    .border(
                        width = if (isFocused) 2.dp else 1.dp,
                        color = if (isFocused) Color.White else Color(0xFF555555),
                        shape = RoundedCornerShape(8.dp),
                    ),
            )
        }
    }
}

/** Left/Right or OK to toggle On/Off */
@Composable
private fun ToggleRow(
    label: String,
    value: Boolean,
    isFocused: Boolean,
    focusRequester: FocusRequester,
    onFocused: () -> Unit,
    onToggle: () -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
) {
    SettingsRowContainer(
        focusRequester = focusRequester,
        isFocused = isFocused,
        onFocused = onFocused,
        onClick = onToggle,
        onKeyEvent = { event ->
            if (event.type != KeyEventType.KeyDown) return@SettingsRowContainer false
            when (event.key) {
                Key.DirectionLeft, Key.DirectionRight,
                Key.Enter, Key.DirectionCenter -> { onToggle();   true }
                Key.DirectionUp               -> { onMoveUp();   true }
                Key.DirectionDown             -> { onMoveDown(); true }
                else -> false
            }
        },
    ) {
        Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        // Pill toggle indicator
        Box(
            modifier = Modifier
                .background(
                    color = if (value) Color(0xFF2E7D32) else Color(0xFF424242),
                    shape = RoundedCornerShape(20.dp),
                )
                .padding(horizontal = 14.dp, vertical = 6.dp),
        ) {
            Text(
                if (value) "On" else "Off",
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

/** Section header label — matches mobile's _buildSectionHeader */
@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        color = Color(0xFF888888),
        fontSize = 11.sp,
        fontWeight = FontWeight.W600,
        letterSpacing = 1.4.sp,
        modifier = Modifier.padding(top = 20.dp, bottom = 6.dp),
    )
}

/** Reset to defaults button */
@Composable
private fun ResetRow(onReset: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF1A1A1A))
            .border(1.dp, Color(0xFF333333), RoundedCornerShape(12.dp))
            .clickable(onClick = onReset)
            .padding(vertical = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            "Reset to Defaults",
            color = Color(0xFFCF6679),
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Color picker dialog — D-pad navigable grid of color swatches
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ColorPickerDialog(
    currentColor: Color,
    onColorSelected: (Color) -> Unit,
    onDismiss: () -> Unit,
) {
    // 5 columns × 3 rows = 15 colors — matches mobile's grid
    val cols = 5
    val focusRequesters = remember { List(PRESET_COLORS.size) { FocusRequester() } }
    var focusedSwatch by remember { mutableIntStateOf(
        PRESET_COLORS.indexOfFirst { it.toArgb() == currentColor.toArgb() }.coerceAtLeast(0)
    ) }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(80)
        runCatching { focusRequesters[focusedSwatch].requestFocus() }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor  = Color(0xFF1E1E1E),
        title = {
            Text(
                "Choose Color",
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                PRESET_COLORS.chunked(cols).forEachIndexed { rowIdx, rowColors ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        rowColors.forEachIndexed { colIdx, color ->
                            val swatchIdx = rowIdx * cols + colIdx
                            val swatchFocused = focusedSwatch == swatchIdx
                            val swatchScale by animateFloatAsState(
                                targetValue = if (swatchFocused) 1.18f else 1f,
                                animationSpec = tween(160),
                                label = "swatchScale$swatchIdx",
                            )
                            Box(
                                modifier = Modifier
                                    .size(52.dp)
                                    .scale(swatchScale)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(color)
                                    .border(
                                        width  = when {
                                            swatchFocused -> 3.dp
                                            color.toArgb() == currentColor.toArgb() -> 2.dp
                                            else -> 1.dp
                                        },
                                        color  = when {
                                            swatchFocused -> Color.White
                                            color.toArgb() == currentColor.toArgb() -> Color(0xFFE50914)
                                            else -> Color(0xFF555555)
                                        },
                                        shape  = RoundedCornerShape(10.dp),
                                    )
                                    .focusRequester(focusRequesters[swatchIdx])
                                    .onFocusChanged { if (it.hasFocus) focusedSwatch = swatchIdx }
                                    .onKeyEvent { event ->
                                        if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                                        when (event.key) {
                                            Key.Enter, Key.DirectionCenter -> {
                                                onColorSelected(color); true
                                            }
                                            Key.DirectionRight -> {
                                                val next = swatchIdx + 1
                                                if (next < PRESET_COLORS.size) runCatching { focusRequesters[next].requestFocus() }
                                                true
                                            }
                                            Key.DirectionLeft -> {
                                                val prev = swatchIdx - 1
                                                if (prev >= 0) runCatching { focusRequesters[prev].requestFocus() }
                                                true
                                            }
                                            Key.DirectionDown -> {
                                                val below = swatchIdx + cols
                                                if (below < PRESET_COLORS.size) runCatching { focusRequesters[below].requestFocus() }
                                                true
                                            }
                                            Key.DirectionUp -> {
                                                val above = swatchIdx - cols
                                                if (above >= 0) runCatching { focusRequesters[above].requestFocus() }
                                                true
                                            }
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
                Text("Cancel", color = Color(0xFF999999), fontSize = 16.sp)
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
    val argb = color.toArgb()
    return "#%06X".format(argb and 0x00FFFFFF)
}
