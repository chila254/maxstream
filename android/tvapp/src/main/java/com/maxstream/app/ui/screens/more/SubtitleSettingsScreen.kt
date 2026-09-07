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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
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
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.R
import com.maxstream.app.data.local.SubtitleSettingsRepository
import com.maxstream.app.data.local.TvSubtitleSettings

private val PRESET_COLORS = listOf(
    Color.White, Color.Yellow, Color(0xFF76FF03), Color(0xFF00E676),
    Color(0xFF00E5FF), Color(0xFF2979FF), Color(0xFFD500F9), Color.Red,
    Color(0xFFFF9100), Color.Gray, Color(0xFFFFD600), Color(0xFF00BFA5),
    Color(0xFFFF80AB), Color(0xFF651FFF), Color(0xFF795548),
)

private data class SettingRow(val label: String, val values: List<String>, val currentIndex: Int)

@Composable
fun SubtitleSettingsScreen(
    onBack: () -> Unit = {},
) {
    val context = LocalContext.current
    val saved = remember { SubtitleSettingsRepository.load(context) }

    var textColor by remember { mutableStateOf(parseColor(saved.textColor)) }
    var bgColor by remember { mutableStateOf(parseColor(saved.backgroundColor)) }
    var bgOpacity by remember { mutableFloatStateOf(saved.backgroundOpacity) }
    var fontSize by remember { mutableFloatStateOf(saved.fontSize) }
    var textShadow by remember { mutableStateOf(saved.textShadow) }
    var shadowColor by remember { mutableStateOf(parseColor(saved.textShadowColor)) }
    var edgeType by remember { mutableStateOf(saved.edgeType) }
    var edgeColor by remember { mutableStateOf(parseColor(saved.edgeColor)) }
    var position by remember { mutableStateOf(saved.position) }

    var showColorPicker by remember { mutableStateOf<String?>(null) }

    val focusRequesters = remember { List(8) { FocusRequester() } }
    var focusedIndex by remember { mutableStateOf(0) }

    fun save() {
        val settings = TvSubtitleSettings(
            textColor = colorToHex(textColor),
            backgroundColor = colorToHex(bgColor),
            backgroundOpacity = bgOpacity,
            fontSize = fontSize,
            textShadow = textShadow,
            textShadowColor = colorToHex(shadowColor),
            edgeType = edgeType,
            edgeColor = colorToHex(edgeColor),
            position = position,
        )
        SubtitleSettingsRepository.save(context, settings)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF121212))
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 48.dp, vertical = 40.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            Text(
                text = "Subtitle Settings",
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Customize how subtitles appear during playback",
                color = Color.Gray,
                fontSize = 14.sp,
            )
            Spacer(Modifier.height(24.dp))

            // Preview
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color.Black),
                contentAlignment = if (position == "top") Alignment.TopCenter else Alignment.BottomCenter,
            ) {
                Text(
                    text = "Sample Video",
                    color = Color.Gray.copy(alpha = 0.4f),
                    modifier = Modifier.align(Alignment.Center),
                )
                Box(
                    modifier = Modifier.padding(8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "This is a sample subtitle text",
                        color = textColor,
                        fontSize = fontSize.coerceIn(10f, 28f).sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .background(
                                bgColor.copy(alpha = bgOpacity),
                                RoundedCornerShape(4.dp)
                            )
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            // Font Size
            SettingRowComposable(
                label = "Font Size",
                value = "${fontSize.toInt()}sp",
                focusRequester = focusRequesters[0],
                isFocused = focusedIndex == 0,
                onFocused = { focusedIndex = 0 },
                onLeft = {
                    fontSize = (fontSize - 2f).coerceIn(12f, 36f)
                    save()
                },
                onRight = {
                    fontSize = (fontSize + 2f).coerceIn(12f, 36f)
                    save()
                },
            )

            // Text Color
            ColorSettingRow(
                label = "Text Color",
                color = textColor,
                focusRequester = focusRequesters[1],
                isFocused = focusedIndex == 1,
                onFocused = { focusedIndex = 1 },
                onSelect = { showColorPicker = "textColor" },
            )

            // Background Color
            ColorSettingRow(
                label = "Background Color",
                color = bgColor,
                focusRequester = focusRequesters[2],
                isFocused = focusedIndex == 2,
                onFocused = { focusedIndex = 2 },
                onSelect = { showColorPicker = "bgColor" },
            )

            // Background Opacity
            SettingRowComposable(
                label = "Background Opacity",
                value = "${(bgOpacity * 100).toInt()}%",
                focusRequester = focusRequesters[3],
                isFocused = focusedIndex == 3,
                onFocused = { focusedIndex = 3 },
                onLeft = {
                    bgOpacity = (bgOpacity - 0.05f).coerceIn(0f, 1f)
                    save()
                },
                onRight = {
                    bgOpacity = (bgOpacity + 0.05f).coerceIn(0f, 1f)
                    save()
                },
            )

            // Edge Type
            val edgeTypes = listOf("none", "outline", "dropShadow")
            val edgeLabels = mapOf("none" to "None", "outline" to "Outline", "dropShadow" to "Drop Shadow")
            SettingRowComposable(
                label = "Edge Type",
                value = edgeLabels[edgeType] ?: edgeType,
                focusRequester = focusRequesters[4],
                isFocused = focusedIndex == 4,
                onFocused = { focusedIndex = 4 },
                onLeft = {
                    val idx = edgeTypes.indexOf(edgeType)
                    edgeType = edgeTypes[(idx - 1 + edgeTypes.size) % edgeTypes.size]
                    save()
                },
                onRight = {
                    val idx = edgeTypes.indexOf(edgeType)
                    edgeType = edgeTypes[(idx + 1) % edgeTypes.size]
                    save()
                },
            )

            // Edge Color
            ColorSettingRow(
                label = "Edge Color",
                color = edgeColor,
                focusRequester = focusRequesters[5],
                isFocused = focusedIndex == 5,
                onFocused = { focusedIndex = 5 },
                onSelect = { showColorPicker = "edgeColor" },
            )

            // Text Shadow
            SettingRowComposable(
                label = "Text Shadow",
                value = if (textShadow) "On" else "Off",
                focusRequester = focusRequesters[6],
                isFocused = focusedIndex == 6,
                onFocused = { focusedIndex = 6 },
                onLeft = { textShadow = !textShadow; save() },
                onRight = { textShadow = !textShadow; save() },
            )

            // Position
            SettingRowComposable(
                label = "Position",
                value = position.replaceFirstChar { it.uppercase() },
                focusRequester = focusRequesters[7],
                isFocused = focusedIndex == 7,
                onFocused = { focusedIndex = 7 },
                onLeft = {
                    position = if (position == "bottom") "top" else "bottom"
                    save()
                },
                onRight = {
                    position = if (position == "bottom") "top" else "bottom"
                    save()
                },
            )
        }

        // Back button
        Text(
            text = "< Back",
            color = Color.Gray,
            fontSize = 16.sp,
            modifier = Modifier
                .padding(24.dp)
                .clickable { onBack() }
                .padding(8.dp),
        )

        // Color picker dialog
        if (showColorPicker != null) {
            AlertDialog(
                onDismissRequest = { showColorPicker = null },
                containerColor = Color(0xFF1E1E1E),
                title = {
                    Text("Choose Color", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                },
                text = {
                    Column {
                        val rows = PRESET_COLORS.chunked(5)
                        for (row in rows) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.padding(vertical = 4.dp),
                            ) {
                                for (color in row) {
                                    Box(
                                        modifier = Modifier
                                            .size(48.dp)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(color)
                                            .border(2.dp, Color.Gray, RoundedCornerShape(8.dp))
                                            .clickable {
                                                when (showColorPicker) {
                                                    "textColor" -> textColor = color
                                                    "bgColor" -> bgColor = color
                                                    "shadowColor" -> shadowColor = color
                                                    "edgeColor" -> edgeColor = color
                                                }
                                                save()
                                                showColorPicker = null
                                            },
                                    )
                                }
                            }
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showColorPicker = null }) {
                        Text("Cancel", color = Color.Gray, fontSize = 16.sp)
                    }
                },
            )
        }
    }
}

@Composable
private fun SettingRowComposable(
    label: String,
    value: String,
    focusRequester: FocusRequester,
    isFocused: Boolean,
    onFocused: () -> Unit,
    onLeft: () -> Unit,
    onRight: () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.01f else 1f,
        animationSpec = tween(200, easing = FastOutSlowInEasing),
        label = "rowScale",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .scale(scale)
            .clip(RoundedCornerShape(8.dp))
            .background(if (isFocused) Color(0xFF2A2A2A) else Color(0xFF1A1A1A))
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White.copy(alpha = 0.3f) else Color.Transparent,
                shape = RoundedCornerShape(8.dp),
            )
            .focusRequester(focusRequester)
            .onFocusChanged { if (it.hasFocus) onFocused() }
            .focusable()
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionLeft -> { onLeft(); true }
                    Key.DirectionRight -> { onRight(); true }
                    else -> false
                }
            }
            .padding(horizontal = 20.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text = label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(text = value, color = Color.Gray, fontSize = 14.sp)
            Spacer(Modifier.width(8.dp))
            Icon(
                painter = painterResource(R.drawable.ic_more),
                contentDescription = null,
                tint = Color.Gray,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}

@Composable
private fun ColorSettingRow(
    label: String,
    color: Color,
    focusRequester: FocusRequester,
    isFocused: Boolean,
    onFocused: () -> Unit,
    onSelect: () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.01f else 1f,
        animationSpec = tween(200, easing = FastOutSlowInEasing),
        label = "colorRowScale",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .scale(scale)
            .clip(RoundedCornerShape(8.dp))
            .background(if (isFocused) Color(0xFF2A2A2A) else Color(0xFF1A1A1A))
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White.copy(alpha = 0.3f) else Color.Transparent,
                shape = RoundedCornerShape(8.dp),
            )
            .focusRequester(focusRequester)
            .onFocusChanged { if (it.hasFocus) onFocused() }
            .focusable()
            .onKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown && event.key == Key.Enter) {
                    onSelect(); true
                } else false
            }
            .clickable(onClick = onSelect)
            .padding(horizontal = 20.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text = label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(color)
                .border(1.dp, Color.Gray, RoundedCornerShape(8.dp)),
        )
    }
}

private fun parseColor(hex: String): Color {
    val clean = hex.removePrefix("#")
    val colorLong = if (clean.length == 6) {
        "FF$clean".toLong(16)
    } else {
        clean.toLong(16)
    }
    return Color(colorLong.toInt())
}

private fun colorToHex(color: Color): String {
    return "#${Integer.toHexString(color.hashCode()).takeLast(6).uppercase().padStart(6, '0')}"
}
