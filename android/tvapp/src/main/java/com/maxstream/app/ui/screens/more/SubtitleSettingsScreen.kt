package com.maxstream.app.ui.screens.more

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Surface
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.local.SubtitleSettingsRepository
import com.maxstream.app.data.local.TvSubtitleSettings

// ─────────────────────────────────────────────────────────────────────────────
// Color palette — same 15 colors as mobile
// ─────────────────────────────────────────────────────────────────────────────

private val SUBTITLE_COLORS = listOf(
    Color.White,
    Color.Yellow,
    Color(0xFFCCFF90), Color(0xFF69F0AE), Color(0xFF18FFFF),
    Color(0xFF448AFF), Color(0xFFE040FB), Color(0xFFF44336),
    Color(0xFFFF9800), Color(0xFF9E9E9E), Color(0xFFFFD740),
    Color(0xFF1DE9B6), Color(0xFFFF4081), Color(0xFF651FFF),
    Color(0xFF795548),
)

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun SubtitleSettingsScreen(onBack: () -> Unit = {}) {

    // BackHandler is the correct TV pattern — no onKeyEvent on a Box needed.
    BackHandler { onBack() }

    val context = LocalContext.current
    val cloudRevision by SubtitleSettingsRepository.cloudRevision.collectAsState()

    // ── State ────────────────────────────────────────────────────────────────
    var textColor   by remember { mutableStateOf(Color.White) }
    var bgColor     by remember { mutableStateOf(Color.Black) }
    var bgOpacity   by remember { mutableFloatStateOf(0.55f) }
    var fontSize    by remember { mutableFloatStateOf(22f) }
    var textShadow  by remember { mutableStateOf(true) }
    var shadowColor by remember { mutableStateOf(Color.Black) }
    var edgeType    by remember { mutableStateOf("outline") }
    var edgeColor   by remember { mutableStateOf(Color.Black) }
    var position    by remember { mutableStateOf("bottom") }

    // Reload whenever cloud sync delivers an update
    LaunchedEffect(cloudRevision) {
        SubtitleSettingsRepository.invalidateCache()
        val s = SubtitleSettingsRepository.load(context)
        textColor   = subParseColor(s.textColor)
        bgColor     = subParseColor(s.backgroundColor)
        bgOpacity   = s.backgroundOpacity
        fontSize    = s.fontSize
        textShadow  = s.textShadow
        shadowColor = subParseColor(s.textShadowColor)
        edgeType    = s.edgeType
        edgeColor   = subParseColor(s.edgeColor)
        position    = s.position
    }

    // ── Save — plain function, reads state directly (Compose tracks it) ──────
    // This is the correct pattern: a regular function that reads the current
    // Compose state. No rememberUpdatedState or remembered lambda needed.
    fun save() {
        SubtitleSettingsRepository.save(
            context,
            TvSubtitleSettings(
                textColor         = subHex(textColor),
                backgroundColor   = subHex(bgColor),
                backgroundOpacity = bgOpacity,
                fontSize          = fontSize,
                textShadow        = textShadow,
                textShadowColor   = subHex(shadowColor),
                edgeType          = edgeType,
                edgeColor         = subHex(edgeColor),
                position          = position,
            )
        )
    }

    // ── Color picker — top-level state so the dialog is NOT inside LazyColumn
    var colorPickerTarget by remember { mutableStateOf<String?>(null) }

    // ── Layout ───────────────────────────────────────────────────────────────
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0F0F0F))
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 56.dp),
            contentPadding = PaddingValues(top = 40.dp, bottom = 60.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
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
                Spacer(Modifier.height(20.dp))

                // Live preview
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(110.dp)
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
                Spacer(Modifier.height(20.dp))
            }

            // ═══════════ TEXT ═══════════
            item(key = "hdr_text") { SubHeader("TEXT") }

            item(key = "row_textColor") {
                SubColorRow(
                    label = "Text Color",
                    color = textColor,
                    onSelect = { colorPickerTarget = "textColor" },
                )
            }

            item(key = "row_fontSize") {
                SubStepRow(
                    label = "Font Size",
                    value = "${fontSize.toInt()}sp",
                    onDecrement = { fontSize = (fontSize - 2f).coerceIn(12f, 36f); save() },
                    onIncrement = { fontSize = (fontSize + 2f).coerceIn(12f, 36f); save() },
                )
            }

            // ═══════════ BACKGROUND ═══════════
            item(key = "hdr_bg") { SubHeader("BACKGROUND") }

            item(key = "row_bgColor") {
                SubColorRow(
                    label = "Background Color",
                    color = bgColor,
                    onSelect = { colorPickerTarget = "bgColor" },
                )
            }

            item(key = "row_bgOpacity") {
                SubStepRow(
                    label = "Opacity",
                    value = "${(bgOpacity * 100).toInt()}%",
                    onDecrement = { bgOpacity = (bgOpacity - 0.05f).coerceIn(0f, 1f); save() },
                    onIncrement = { bgOpacity = (bgOpacity + 0.05f).coerceIn(0f, 1f); save() },
                )
            }

            // ═══════════ EDGE / SHADOW ═══════════
            item(key = "hdr_edge") { SubHeader("EDGE / SHADOW") }

            item(key = "row_edgeType") {
                val types  = listOf("none", "outline", "dropShadow")
                val labels = mapOf("none" to "None", "outline" to "Outline", "dropShadow" to "Drop Shadow")
                SubCycleRow(
                    label = "Edge Type",
                    value = labels[edgeType] ?: edgeType,
                    onPrev = { val i = types.indexOf(edgeType); edgeType = types[(i - 1 + types.size) % types.size]; save() },
                    onNext = { val i = types.indexOf(edgeType); edgeType = types[(i + 1) % types.size]; save() },
                )
            }

            item(key = "row_edgeColor") {
                SubColorRow(
                    label = "Edge Color",
                    color = edgeColor,
                    onSelect = { colorPickerTarget = "edgeColor" },
                )
            }

            item(key = "row_textShadow") {
                SubToggleRow(
                    label = "Text Shadow",
                    value = textShadow,
                    onToggle = { textShadow = !textShadow; save() },
                )
            }

            if (textShadow) {
                item(key = "row_shadowColor") {
                    SubColorRow(
                        label = "Shadow Color",
                        color = shadowColor,
                        onSelect = { colorPickerTarget = "shadowColor" },
                    )
                }
            }

            // ═══════════ POSITION ═══════════
            item(key = "hdr_pos") { SubHeader("POSITION") }

            item(key = "row_position") {
                SubCycleRow(
                    label = "Position",
                    value = position.replaceFirstChar { it.uppercase() },
                    onPrev = { position = if (position == "bottom") "top" else "bottom"; save() },
                    onNext = { position = if (position == "bottom") "top" else "bottom"; save() },
                )
            }

            // Reset
            item(key = "reset") {
                Spacer(Modifier.height(16.dp))
                SubResetButton {
                    val d = TvSubtitleSettings()
                    textColor   = subParseColor(d.textColor)
                    bgColor     = subParseColor(d.backgroundColor)
                    bgOpacity   = d.backgroundOpacity
                    fontSize    = d.fontSize
                    textShadow  = d.textShadow
                    shadowColor = subParseColor(d.textShadowColor)
                    edgeType    = d.edgeType
                    edgeColor   = subParseColor(d.edgeColor)
                    position    = d.position
                    SubtitleSettingsRepository.save(context, d)
                }
            }
        }

        // Color picker dialog — always outside LazyColumn
        val pickerTarget = colorPickerTarget
        if (pickerTarget != null) {
            val current = when (pickerTarget) {
                "textColor"   -> textColor
                "bgColor"     -> bgColor
                "shadowColor" -> shadowColor
                else          -> edgeColor
            }
            SubColorPickerDialog(
                currentColor = current,
                onColorSelected = { color ->
                    when (pickerTarget) {
                        "textColor"   -> textColor   = color
                        "bgColor"     -> bgColor     = color
                        "shadowColor" -> shadowColor = color
                        else          -> edgeColor   = color
                    }
                    save()
                    colorPickerTarget = null
                },
                onDismiss = { colorPickerTarget = null },
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row composables — Surface + focusable + clickable, same pattern as other
// working TV settings screens. Compose handles Up/Down traversal automatically
// when items are in a LazyColumn; no manual FocusRequester chains needed.
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SubRowSurface(
    onClick: (() -> Unit)? = null,
    onLeft: (() -> Unit)? = null,
    onRight: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    var focused by remember { mutableStateOf(false) }

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .onFocusChanged { focused = it.isFocused }
            .border(
                width = if (focused) 2.dp else 0.dp,
                color = if (focused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(12.dp),
            )
            // D-pad left/right for step/cycle rows — only intercept if handlers given
            .then(
                if (onLeft != null || onRight != null) {
                    Modifier.onPreviewKeyEvent { event ->
                        if (event.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        when (event.key) {
                            Key.DirectionLeft  -> { onLeft?.invoke();  onLeft  != null }
                            Key.DirectionRight -> { onRight?.invoke(); onRight != null }
                            else -> false
                        }
                    }
                } else Modifier
            )
            .focusable()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        color = if (focused) Color(0xFF2A2A2A) else Color(0xFF1C1C1C),
        shape = RoundedCornerShape(12.dp),
    ) {
        content()
    }
}

@Composable
private fun SubStepRow(
    label: String,
    value: String,
    onDecrement: () -> Unit,
    onIncrement: () -> Unit,
) {
    SubRowSurface(onLeft = onDecrement, onRight = onIncrement) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("◀", color = Color(0xFF888888), fontSize = 13.sp)
                Spacer(Modifier.width(10.dp))
                Text(value, color = Color(0xFFDDDDDD), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.width(10.dp))
                Text("▶", color = Color(0xFF888888), fontSize = 13.sp)
            }
        }
    }
}

@Composable
private fun SubCycleRow(
    label: String,
    value: String,
    onPrev: () -> Unit,
    onNext: () -> Unit,
) {
    SubRowSurface(onLeft = onPrev, onRight = onNext) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("◀", color = Color(0xFF888888), fontSize = 13.sp)
                Spacer(Modifier.width(10.dp))
                Text(value, color = Color(0xFFDDDDDD), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.width(10.dp))
                Text("▶", color = Color(0xFF888888), fontSize = 13.sp)
            }
        }
    }
}

@Composable
private fun SubColorRow(
    label: String,
    color: Color,
    onSelect: () -> Unit,
) {
    SubRowSurface(onClick = onSelect) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Press OK", color = Color(0xFF777777), fontSize = 12.sp)
                Spacer(Modifier.width(10.dp))
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(color)
                        .border(1.dp, Color(0xFF555555), RoundedCornerShape(6.dp)),
                )
            }
        }
    }
}

@Composable
private fun SubToggleRow(
    label: String,
    value: Boolean,
    onToggle: () -> Unit,
) {
    SubRowSurface(onClick = onToggle) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
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
}

@Composable
private fun SubHeader(title: String) {
    Text(
        title,
        color = Color(0xFF777777),
        fontSize = 11.sp,
        fontWeight = FontWeight.W600,
        letterSpacing = 1.5.sp,
        modifier = Modifier.padding(top = 16.dp, bottom = 2.dp),
    )
}

@Composable
private fun SubResetButton(onReset: () -> Unit) {
    var focused by remember { mutableStateOf(false) }
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .onFocusChanged { focused = it.isFocused }
            .border(
                width = if (focused) 2.dp else 1.dp,
                color = if (focused) Color(0xFFCF6679) else Color(0xFF3A3A3A),
                shape = RoundedCornerShape(12.dp),
            )
            .focusable()
            .clickable(onClick = onReset),
        color = Color(0xFF1C1C1C),
        shape = RoundedCornerShape(12.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Color picker dialog
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SubColorPickerDialog(
    currentColor: Color,
    onColorSelected: (Color) -> Unit,
    onDismiss: () -> Unit,
) {
    BackHandler { onDismiss() }

    val cols = 5
    val focusRequesters = remember { List(SUBTITLE_COLORS.size) { FocusRequester() } }
    var focusedSwatch by remember {
        mutableIntStateOf(
            SUBTITLE_COLORS.indexOfFirst { it.toArgb() == currentColor.toArgb() }.coerceAtLeast(0)
        )
    }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(80)
        runCatching { focusRequesters[focusedSwatch].requestFocus() }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1E1E1E),
        title = {
            Text("Choose Color", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SUBTITLE_COLORS.chunked(cols).forEachIndexed { rowIdx, rowColors ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        rowColors.forEachIndexed { colIdx, color ->
                            val idx = rowIdx * cols + colIdx
                            val swFocused = focusedSwatch == idx
                            val scale by animateFloatAsState(
                                targetValue = if (swFocused) 1.2f else 1f,
                                label = "sw$idx",
                            )
                            Box(
                                modifier = Modifier
                                    .size(50.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(color)
                                    .border(
                                        width = when {
                                            swFocused -> 3.dp
                                            color.toArgb() == currentColor.toArgb() -> 2.dp
                                            else -> 1.dp
                                        },
                                        color = when {
                                            swFocused -> Color.White
                                            color.toArgb() == currentColor.toArgb() -> Color(0xFFE50914)
                                            else -> Color(0xFF444444)
                                        },
                                        shape = RoundedCornerShape(10.dp),
                                    )
                                    .focusRequester(focusRequesters[idx])
                                    .onFocusChanged { if (it.hasFocus) focusedSwatch = idx }
                                    .onPreviewKeyEvent { e ->
                                        if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                                        when (e.key) {
                                            Key.Enter, Key.DirectionCenter -> { onColorSelected(color); true }
                                            Key.DirectionRight -> { if (idx + 1 < SUBTITLE_COLORS.size) runCatching { focusRequesters[idx + 1].requestFocus() }; true }
                                            Key.DirectionLeft  -> { if (idx - 1 >= 0) runCatching { focusRequesters[idx - 1].requestFocus() }; true }
                                            Key.DirectionDown  -> { if (idx + cols < SUBTITLE_COLORS.size) runCatching { focusRequesters[idx + cols].requestFocus() }; true }
                                            Key.DirectionUp    -> { if (idx - cols >= 0) runCatching { focusRequesters[idx - cols].requestFocus() }; true }
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

private fun subParseColor(hex: String): Color {
    val c = hex.removePrefix("#")
    return Color(if (c.length == 6) "FF$c".toLong(16).toInt() else c.toLong(16).toInt())
}

private fun subHex(color: Color): String = "#%06X".format(color.toArgb() and 0x00FFFFFF)
