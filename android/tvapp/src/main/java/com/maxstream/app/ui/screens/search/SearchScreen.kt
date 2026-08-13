package com.maxstream.app.ui.screens.search

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.di.Modules
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.components.TvKeyboard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.tv.TvKeyboardFocusManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@Composable
fun SearchScreen(
    navController: NavController,
    onReturnToSidebar: () -> Unit = {},
    isVisible: Boolean = true,
) {
    var query         by remember { mutableStateOf("") }
    var results       by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var isSearching   by remember { mutableStateOf(false) }
    var searchError   by remember { mutableStateOf<String?>(null) }
    var resultsKey    by remember { mutableStateOf("") }

    // Use a coroutineScope-scoped Job instead of GlobalScope — no leak
    val scope = rememberCoroutineScope()
    var debounceJob by remember { mutableStateOf<Job?>(null) }

    val keyboardFocusManager = remember { TvKeyboardFocusManager() }
    val keyboardFocusRequester = remember { FocusRequester() }
    val resultsFocusRequester  = remember { FocusRequester() }

    // Debounced search — triggered on query change, cancelled on next change
    LaunchedEffect(query) {
        debounceJob?.cancel()
        if (query.length < 2) {
            results = emptyList(); searchError = null; isSearching = false; resultsKey = ""
            return@LaunchedEffect
        }
        debounceJob = scope.launch {
            delay(400)
            if (!isActive) return@launch
            isSearching = true; searchError = null
            try {
                results = Modules.catalogRepository.search(query)
                resultsKey = query
            } catch (e: Exception) {
                searchError = e.message; results = emptyList(); resultsKey = ""
            } finally {
                isSearching = false
            }
        }
    }

    // Seed keyboard focus when this tab becomes visible — retry pattern
    LaunchedEffect(isVisible) {
        if (!isVisible) return@LaunchedEffect
        repeat(6) { attempt ->
            delay(50L * (attempt + 1))
            val ok = runCatching { keyboardFocusRequester.requestFocus() }
            if (ok.isSuccess) return@LaunchedEffect
        }
    }

    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
    ) {
        // ── Left panel: heading + keyboard ────────────────────────────────
        Column(
            modifier = Modifier
                .width(380.dp)
                .fillMaxHeight()
                .padding(horizontal = 34.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "Search",
                color = Color.White,
                fontSize = 34.sp,
                fontWeight = FontWeight.W800,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Find movies and series",
                color = Color.White.copy(alpha = 0.55f),
                fontSize = 15.sp,
            )
            Spacer(modifier = Modifier.height(24.dp))

            TvKeyboard(
                onInput  = { text -> query = text },
                onSubmit = { /* already searching via debounce */ },
                initialText = query,
                focusManager = keyboardFocusManager,
                focusRequester = keyboardFocusRequester,
                onMoveRight = {
                    // Move focus from keyboard to results panel
                    keyboardFocusManager.focusOnContent()
                    runCatching { resultsFocusRequester.requestFocus() }
                },
                onMoveLeft = onReturnToSidebar,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Spacer(modifier = Modifier.width(8.dp))

        // ── Right panel: results ──────────────────────────────────────────
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(end = 34.dp, top = 24.dp)
                .focusRequester(resultsFocusRequester)
                .focusable(),
        ) {
            androidx.compose.animation.AnimatedVisibility(
                visible = resultsKey.isNotEmpty() || isSearching,
                enter = fadeIn(tween(350)) + scaleIn(tween(350), initialScale = 0.98f),
                exit  = fadeOut(tween(180)),
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    isSearching -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Color(0xFFE50914))
                    }
                    searchError != null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(text = searchError ?: "Error", color = Color.Red)
                            Spacer(Modifier.height(12.dp))
                            Text("Please try again", color = Color.White)
                        }
                    }
                    results.isEmpty() && query.length >= 2 ->
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text(text = "No matches for \"$query\"", color = Color.White)
                        }
                    else -> {
                        val grouped = results.groupBy {
                            if (it.mediaType == "tv") "TV Series" else "Movies"
                        }
                        val sections = listOf("Movies", "TV Series")

                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(top = 8.dp, bottom = 56.dp),
                            verticalArrangement = Arrangement.spacedBy(14.dp),
                        ) {
                            item {
                                Text(
                                    text = "Results for \"$query\"",
                                    color = Color.White,
                                    fontSize = 26.sp,
                                    fontWeight = FontWeight.W800,
                                    modifier = Modifier.padding(bottom = 12.dp),
                                )
                            }
                            sections.forEach { section ->
                                val sectionItems = grouped[section] ?: return@forEach
                                if (sectionItems.isEmpty()) return@forEach
                                item {
                                    Column {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            modifier = Modifier.padding(bottom = 12.dp),
                                        ) {
                                            Box(
                                                modifier = Modifier
                                                    .size(width = 4.dp, height = 23.dp)
                                                    .background(Color(0xFFE50914), RoundedCornerShape(4.dp))
                                            )
                                            Spacer(Modifier.width(10.dp))
                                            Text(
                                                text = section,
                                                color = Color.White,
                                                fontSize = 20.sp,
                                                fontWeight = FontWeight.W700,
                                            )
                                        }
                                        SearchResultRow(
                                            items = sectionItems,
                                            navController = navController,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SearchResultRow(
    items: List<MediaItem>,
    navController: NavController,
) {
    var focusedIndex by remember { mutableStateOf(-1) }

    LazyRow(
        contentPadding = PaddingValues(horizontal = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        items(items, key = { it.id }) { item ->
            val idx = items.indexOf(item)
            ContentCard(
                posterUrl = item.posterUrl,
                title = item.title,
                rating = item.voteAverage.takeIf { it > 0 },
                isFocused = focusedIndex == idx,
                onFocusChanged = { focused ->
                    if (focused) focusedIndex = idx
                    else if (focusedIndex == idx) focusedIndex = -1
                },
                onClick = {
                    val route = if (item.mediaType == "tv")
                        Screen.Series.createRoute(item.id.toString())
                    else
                        Screen.Details.createRoute(item.id.toString())
                    navController.navigate(route)
                },
                modifier = Modifier.height(180.dp),
            )
        }
    }
}
