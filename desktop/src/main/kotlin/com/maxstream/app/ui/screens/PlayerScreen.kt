package com.maxstream.app.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ClosedCaption
import androidx.compose.material.icons.filled.Dns
import androidx.compose.material.icons.filled.Fullscreen
import androidx.compose.material.icons.filled.FullscreenExit
import androidx.compose.material.icons.filled.HighQuality
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.VolumeDown
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.awt.SwingPanel
import androidx.compose.ui.window.WindowPlacement
import androidx.compose.ui.window.WindowState
import com.maxstream.app.data.AppPrefs
import com.maxstream.app.data.WatchStateStore
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.model.PlayRequest
import com.maxstream.app.data.repository.MediaRepository
import com.maxstream.app.player.PlayerController
import com.maxstream.app.stream.ResolvedStream
import com.maxstream.app.stream.StreamResolver
import com.maxstream.app.stream.parseStreams
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.file.Files
import java.nio.file.Path
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Desktop player with VLC-style overlay controls:
 * - Space / Backspace toggle play-pause (focus stays on Compose, not AWT).
 * - F toggles window fullscreen; Esc leaves fullscreen first, then goes back.
 * - Controls stay visible while paused or while a menu is open; auto-hide
 *   ~1s while playing (VLC fullscreen-controller timeout).
 * - Entering maximizes the window (unless already fullscreen); leaving
 *   restores the previous placement via Shell.
 */
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
fun PlayerScreen(
    request: PlayRequest,
    repository: MediaRepository,
    onBack: () -> Unit,
    windowState: WindowState? = null,
) {
    val controller = remember { PlayerController() }
    val scope = rememberCoroutineScope()
    val focusRequester = remember { FocusRequester() }

    var streams by remember { mutableStateOf<List<ResolvedStream>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var selectedIndex by remember { mutableIntStateOf(-1) }

    var positionMs by remember { mutableLongStateOf(0L) }
    var lengthMs by remember { mutableLongStateOf(0L) }
    var sliderFrac by remember { mutableFloatStateOf(0f) }
    var playing by remember { mutableStateOf(false) }
    var controlsVisible by remember { mutableStateOf(true) }
    var seeking by remember { mutableStateOf(false) }
    var volume by remember { mutableIntStateOf(80) }
    var muted by remember { mutableStateOf(false) }
    var lastSaved by remember { mutableLongStateOf(0L) }
    var menuOpen by remember { mutableStateOf(false) }
    var lastActivityAt by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var isFullscreen by remember {
        mutableStateOf(windowState?.placement == WindowPlacement.Fullscreen)
    }

    fun revealControls() {
        lastActivityAt = System.currentTimeMillis()
        controlsVisible = true
    }

    fun toggleFullscreen() {
        val state = windowState ?: return
        if (state.placement == WindowPlacement.Fullscreen) {
            state.placement = WindowPlacement.Maximized
            isFullscreen = false
        } else {
            state.placement = WindowPlacement.Fullscreen
            isFullscreen = true
        }
        revealControls()
    }

    val resume = remember(request.itemId, request.season, request.episode) {
        WatchStateStore.resumeFor(request.itemId, request.season, request.episode)
    }
    var resumeApplied by remember { mutableStateOf(false) }
    var resumeShownUntil by remember { mutableLongStateOf(0L) }

    val playUrl: (String, ResolvedStream) -> Unit = { url, stream ->
        controller.play(url, stream.referer, stream.userAgent, stream.origin)
        positionMs = 0L
        lengthMs = 0L
        sliderFrac = 0f
        resumeApplied = false
        stream.subtitles.firstOrNull()?.let { sub ->
            scope.launch {
                val file = downloadSubtitle(sub.url)
                if (file != null) controller.setSubtitleFile(file)
            }
        }
    }

    /** Settings → Default quality: pick nearest matching rendition (or best). */
    fun preferredQualityUrl(stream: ResolvedStream): String {
        val qualities = stream.qualityMatch()
        val target = AppPrefs.defaultQualityHeight()
        if (target <= 0 || qualities.isEmpty()) return qualities.firstOrNull()?.url ?: stream.url
        val exact = qualities.firstOrNull { it.height == target }
        if (exact != null) return exact.url
        return qualities.minByOrNull { kotlin.math.abs(it.height - target) }?.url
            ?: qualities.firstOrNull()?.url
            ?: stream.url
    }

    val playStream: (Int) -> Unit = { index ->
        if (index in streams.indices) {
            selectedIndex = index
            val stream = streams[index]
            playUrl(preferredQualityUrl(stream), stream)
        }
    }

    val selectQuality: (com.maxstream.app.stream.ResolvedQuality) -> Unit = { q ->
        streams.getOrNull(selectedIndex)?.let { stream -> playUrl(q.url, stream) }
    }

    fun seekBy(deltaMs: Long) {
        if (lengthMs <= 0L) return
        val next = (positionMs + deltaMs).coerceIn(0L, lengthMs)
        controller.setTime(next)
        positionMs = next
        sliderFrac = next.toFloat() / lengthMs
        revealControls()
    }

    fun adjustVolume(delta: Int) {
        volume = (volume + delta).coerceIn(0, 100)
        muted = volume == 0
        controller.setVolume(volume)
        controller.setMute(muted)
        revealControls()
    }

    fun toggleMute() {
        muted = !muted
        controller.setMute(muted)
        revealControls()
    }

    fun togglePlayPause() {
        controller.togglePlayPause()
        revealControls()
    }

    LaunchedEffect(request.itemId, request.season, request.episode) {
        loading = true
        error = null
        controlsVisible = true
        resumeApplied = false
        val parsed = withContext(Dispatchers.IO) {
            parseStreams(
                StreamResolver.resolveAll(
                    request.itemId,
                    request.mediaType == "movie",
                    request.season,
                    request.episode,
                    request.title,
                ),
            )
        }
        streams = parsed
        if (parsed.isEmpty()) {
            loading = false
            error = "No playable source could be resolved for this title."
        } else {
            playStream(0)
            delay(600)
            loading = false
            runCatching { focusRequester.requestFocus() }
        }
    }

    LaunchedEffect(Unit) {
        while (true) {
            if (positionMs <= 0L) positionMs = controller.time()
            lengthMs = controller.length()
            playing = controller.isPlaying
            if (!seeking) {
                val p = controller.time()
                if (p > 0L) positionMs = p
                if (lengthMs > 0L) sliderFrac = (positionMs.toFloat() / lengthMs).coerceIn(0f, 1f)
            }
            if (!resumeApplied && resume != null && resume.positionMs > 30_000L && lengthMs > 0L) {
                controller.setTime(resume.positionMs.coerceAtMost((lengthMs - 5_000L).coerceAtLeast(0L)))
                resumeApplied = true
                resumeShownUntil = System.currentTimeMillis() + 3_000L
            }
            if (playing && lengthMs > 0L && positionMs - lastSaved >= 10_000L) {
                lastSaved = positionMs
                repository.saveProgress(itemFrom(request), request.season, request.episode, positionMs, lengthMs)
            }
            delay(600)
        }
    }

    // Auto-hide only while playing and no menu/seek is open (VLC: ~1s).
    LaunchedEffect(controlsVisible, playing, loading, menuOpen, seeking) {
        if (!controlsVisible || loading || menuOpen || seeking) return@LaunchedEffect
        while (controlsVisible && !loading && !menuOpen && !seeking) {
            delay(150)
            if (!playing) {
                // Paused → keep controls up (browser/mpv pattern).
                lastActivityAt = System.currentTimeMillis()
                continue
            }
            if (System.currentTimeMillis() - lastActivityAt >= 1000L) {
                controlsVisible = false
            }
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            if (lengthMs > 0L) {
                scope.launch {
                    repository.saveProgress(itemFrom(request), request.season, request.episode, positionMs, lengthMs)
                }
            }
            controller.release()
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(focusRequester)
            .focusable()
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.Spacebar, Key.Backspace -> {
                        togglePlayPause()
                        true
                    }
                    Key.F -> {
                        toggleFullscreen()
                        true
                    }
                    Key.Escape -> {
                        val state = windowState
                        when {
                            state?.placement == WindowPlacement.Fullscreen -> {
                                state.placement = WindowPlacement.Maximized
                                isFullscreen = false
                                revealControls()
                                true
                            }
                            else -> {
                                onBack()
                                true
                            }
                        }
                    }
                    Key.M -> {
                        toggleMute()
                        true
                    }
                    Key.I -> {
                        revealControls()
                        true
                    }
                    Key.DirectionLeft -> {
                        if (event.isCtrlPressed) seekBy(-60_000L) else seekBy(-10_000L)
                        true
                    }
                    Key.DirectionRight -> {
                        if (event.isCtrlPressed) seekBy(60_000L) else seekBy(10_000L)
                        true
                    }
                    Key.DirectionUp -> {
                        adjustVolume(+5)
                        true
                    }
                    Key.DirectionDown -> {
                        adjustVolume(-5)
                        true
                    }
                    else -> false
                }
            },
    ) {
        Surface(color = Color.Black, modifier = Modifier.fillMaxSize()) {}
        SwingPanel(
            factory = { controller.component },
            modifier = Modifier.fillMaxSize(),
            update = {},
        )

        // Pointer layer: reveal on move; click toggles controls (not play).
        Box(
            Modifier
                .fillMaxSize()
                .onPointerEvent(PointerEventType.Move) { revealControls() }
                .onPointerEvent(PointerEventType.Enter) { revealControls() }
                .onPointerEvent(PointerEventType.Press) {
                    runCatching { focusRequester.requestFocus() }
                    revealControls()
                }
                .clickable(
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() },
                ) { controlsVisible = !controlsVisible },
        )

        // ── Top chrome ───────────────────────────────────────────────────────
        AnimatedVisibility(visible = controlsVisible) {
            Surface(color = Color.Transparent, modifier = Modifier.fillMaxWidth()) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .background(Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.75f), Color.Transparent)))
                        .onPointerEvent(PointerEventType.Move) { revealControls() }
                        .onPointerEvent(PointerEventType.Enter) { revealControls() },
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                    ) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = Color.White)
                        }
                        Column(Modifier.weight(1f).padding(start = 6.dp)) {
                            Text(
                                request.title,
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 16.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            if (request.mediaType == "tv") {
                                Text(
                                    "Season ${request.season} • Episode ${request.episode}",
                                    color = Color.White.copy(alpha = 0.8f),
                                    fontSize = 13.sp,
                                )
                            }
                        }
                        IconButton(onClick = { toggleFullscreen() }) {
                            Icon(
                                if (isFullscreen || windowState?.placement == WindowPlacement.Fullscreen)
                                    Icons.Default.FullscreenExit
                                else Icons.Default.Fullscreen,
                                contentDescription = "Fullscreen",
                                tint = Color.White,
                            )
                        }
                    }
                }
            }
        }

        // ── Bottom chrome: seek + transport + menus (VLC order) ─────────────
        AnimatedVisibility(visible = controlsVisible, modifier = Modifier.align(Alignment.BottomCenter)) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.85f))))
                    .onPointerEvent(PointerEventType.Move) { revealControls() }
                    .onPointerEvent(PointerEventType.Enter) { revealControls() }
                    .padding(horizontal = 18.dp, vertical = 12.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { togglePlayPause() }) {
                        Icon(
                            if (playing) Icons.Default.Pause else Icons.Default.PlayArrow,
                            "Play/Pause",
                            tint = Color.White,
                            modifier = Modifier.width(26.dp).height(26.dp),
                        )
                    }
                    Text(fmtPlayer(positionMs), color = Color.White, fontSize = 12.sp)

                    Slider(
                        value = sliderFrac,
                        onValueChange = { seeking = true; sliderFrac = it; revealControls() },
                        onValueChangeFinished = {
                            controller.setPosition(sliderFrac)
                            positionMs = (sliderFrac * lengthMs).toLong()
                            seeking = false
                            revealControls()
                        },
                        modifier = Modifier.weight(1f).padding(horizontal = 12.dp),
                    )

                    Text(fmtPlayer(lengthMs), color = Color.White, fontSize = 12.sp)

                    IconButton(onClick = { toggleMute() }) {
                        Icon(
                            when {
                                muted || volume == 0 -> Icons.Default.VolumeOff
                                volume < 50 -> Icons.Default.VolumeDown
                                else -> Icons.Default.VolumeUp
                            },
                            "Mute",
                            tint = Color.White,
                        )
                    }
                    Slider(
                        value = volume.toFloat(),
                        onValueChange = { volume = it.toInt(); revealControls() },
                        onValueChangeFinished = {
                            muted = volume == 0
                            controller.setVolume(volume)
                            controller.setMute(muted)
                        },
                        modifier = Modifier.width(100.dp),
                    )
                    IconButton(onClick = { toggleFullscreen() }) {
                        Icon(
                            if (windowState?.placement == WindowPlacement.Fullscreen)
                                Icons.Default.FullscreenExit
                            else Icons.Default.Fullscreen,
                            contentDescription = "Fullscreen",
                            tint = Color.White,
                        )
                    }
                }

                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(top = 4.dp),
                ) {
                    val currentStream = streams.getOrNull(selectedIndex)
                    val qualities = currentStream?.qualityMatch().orEmpty()
                    val subs = currentStream?.subtitles.orEmpty()

                    PlayerMenu(
                        icon = Icons.Default.Dns,
                        label = if (streams.size > 1) "Server (${selectedIndex + 1}/${streams.size})" else "Server",
                        enabled = streams.isNotEmpty(),
                        onMenuState = { menuOpen = it },
                        onInteract = { revealControls() },
                    ) {
                        if (streams.isEmpty()) {
                            DropdownMenuItem(
                                text = { Text("Resolving…", color = Color.White.copy(alpha = 0.6f)) },
                                onClick = {},
                            )
                        }
                        streams.forEachIndexed { index, stream ->
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        buildString {
                                            append(stream.server)
                                            if (index == selectedIndex) append("  ✓")
                                        },
                                        color = Color.White,
                                    )
                                },
                                onClick = { playStream(index) },
                            )
                        }
                    }

                    PlayerMenu(
                        icon = Icons.Default.HighQuality,
                        label = if (qualities.size > 1) "Quality (${qualities.size})" else "Quality",
                        enabled = qualities.isNotEmpty(),
                        onMenuState = { menuOpen = it },
                        onInteract = { revealControls() },
                    ) {
                        if (qualities.isEmpty()) {
                            DropdownMenuItem(
                                text = { Text("Default stream", color = Color.White.copy(alpha = 0.6f)) },
                                onClick = {},
                            )
                        }
                        qualities.forEach { q ->
                            DropdownMenuItem(
                                text = { Text(q.label.ifBlank { "${q.height}p" }, color = Color.White) },
                                onClick = { selectQuality(q) },
                            )
                        }
                    }

                    PlayerMenu(
                        icon = Icons.Default.ClosedCaption,
                        label = if (subs.isNotEmpty()) "Subtitles (${subs.size})" else "Subtitles",
                        enabled = true,
                        onMenuState = { menuOpen = it },
                        onInteract = { revealControls() },
                    ) {
                        DropdownMenuItem(
                            text = { Text("Off", color = Color.White) },
                            onClick = { controller.disableSubtitles() },
                        )
                        subs.forEach { sub ->
                            DropdownMenuItem(
                                text = { Text(sub.label, color = Color.White) },
                                onClick = {
                                    scope.launch {
                                        val f = downloadSubtitle(sub.url)
                                        if (f != null) controller.setSubtitleFile(f)
                                    }
                                },
                            )
                        }
                        if (subs.isEmpty()) {
                            DropdownMenuItem(
                                text = { Text("No tracks for this source", color = Color.White.copy(alpha = 0.55f)) },
                                onClick = {},
                            )
                        }
                    }

                    Spacer(Modifier.weight(1f))
                    Text(
                        "Space / Backspace play-pause  •  F fullscreen  •  Esc back",
                        color = Color.White.copy(alpha = 0.45f),
                        fontSize = 11.sp,
                        modifier = Modifier.align(Alignment.CenterVertically).padding(start = 8.dp),
                    )
                }
            }
        }

        // ── Resume chip ─────────────────────────────────────────────────────
        if (resumeApplied && System.currentTimeMillis() < resumeShownUntil) {
            Surface(
                color = Color.Black.copy(alpha = 0.6f),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.align(Alignment.TopStart).padding(top = 64.dp, start = 24.dp),
            ) {
                Text(
                    "Resumed from ${fmtPlayer(resume?.positionMs ?: 0L)}",
                    color = Color.White,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                )
            }
        }

        // ── Loading / error overlays ───────────────────────────────────────
        if (loading) {
            Box(
                Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator(color = Color.White, strokeWidth = 3.dp)
                    Spacer(Modifier.height(16.dp))
                    Text(
                        "Finding streams…",
                        color = Color.White,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        request.title,
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 13.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
        if (error != null) {
            Surface(
                color = Color.Black.copy(alpha = 0.85f),
                modifier = Modifier.fillMaxSize(),
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.align(Alignment.Center),
                ) {
                    Text(error.orEmpty(), color = Color.White, fontSize = 15.sp)
                    Spacer(Modifier.height(16.dp))
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.Refresh, "Back", tint = Color.White)
                    }
                    Text("Go back", color = Color.White.copy(alpha = 0.7f), fontSize = 13.sp)
                }
            }
        }
    }
}

@Composable
private fun PlayerMenu(
    icon: ImageVector,
    label: String,
    enabled: Boolean,
    onMenuState: (Boolean) -> Unit = {},
    onInteract: () -> Unit = {},
    content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    LaunchedEffect(open) { onMenuState(open) }
    Box {
        Surface(
            color = Color.White.copy(alpha = 0.10f),
            shape = RoundedCornerShape(6.dp),
            modifier = Modifier.clickable(enabled = enabled) {
                open = true
                onInteract()
            },
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            ) {
                Icon(icon, null, tint = if (enabled) Color.White else Color.White.copy(alpha = 0.4f), modifier = Modifier.width(16.dp).height(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    label,
                    color = if (enabled) Color.White else Color.White.copy(alpha = 0.4f),
                    fontSize = 13.sp,
                )
            }
        }
        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
            containerColor = Color(0xFF1E1E1E),
        ) {
            content()
        }
    }
}

private fun itemFrom(request: PlayRequest) = MediaItem(
    id = request.itemId,
    title = request.title,
    mediaType = request.mediaType,
    overview = "",
)

private fun fmtPlayer(ms: Long): String {
    val totalSec = ms / 1000
    val h = totalSec / 3600
    val m = (totalSec % 3600) / 60
    val s = totalSec % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%02d:%02d".format(m, s)
}

private val subHttp: HttpClient by lazy { HttpClient.newBuilder().followRedirects(HttpClient.Redirect.NORMAL).build() }

/** Downloads a subtitle to a temp file (VLC peels them off URLs we control only). */
private suspend fun downloadSubtitle(url: String): String? = withContext(Dispatchers.IO) {
    runCatching {
        val req = HttpRequest.newBuilder(URI(url)).GET()
            .header("User-Agent", "Mozilla/5.0").build()
        val resp = subHttp.send(req, HttpResponse.BodyHandlers.ofByteArray())
        if (resp.statusCode() !in 200..299) return@runCatching null
        val ext = when (url.substringAfterLast('.', "").lowercase()) {
            "vtt" -> ".vtt"
            "srt" -> ".srt"
            else -> ".vtt"
        }
        val tmp: Path = Files.createTempFile("maxstream-sub", ext)
        Files.write(tmp, resp.body())
        tmp.toString()
    }.getOrNull()
}
