package com.maxstream.app.ui.screens.search

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import com.maxstream.app.R
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.di.Modules
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.components.TvKeyboard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.tv.TvFocusManager
import com.maxstream.app.ui.tv.TvKeyboardFocusManager
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@Composable
fun SearchScreen(navController: NavController, onReturnToSidebar: () -> Unit = {}) {
    var query by remember { mutableStateOf("") }
    var searchResults by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }
    var searchError by remember { mutableStateOf<String?>(null) }
    var debounceJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    var resultsKey by remember { mutableStateOf("") }
    val keyboardFocusManager = remember { TvKeyboardFocusManager() }

    LaunchedEffect(query) {
        debounceJob?.cancel()
        if (query.length < 2) {
            searchResults = emptyList()
            searchError = null
            isSearching = false
            resultsKey = ""
            return@LaunchedEffect
        }
        debounceJob = kotlinx.coroutines.GlobalScope.launch(kotlinx.coroutines.Dispatchers.Main) {
            delay(400)
            if (!isActive) return@launch
            isSearching = true
            searchError = null
            try {
                val results = Modules.catalogRepository.search(query)
                searchResults = results
                resultsKey = query
            } catch (e: Exception) {
                searchError = e.message
                searchResults = emptyList()
                resultsKey = ""
            } finally {
                isSearching = false
            }
        }
    }

    val hasResults = searchResults.isNotEmpty()
    val isLoading = isSearching

    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
    ) {
        Column(
            modifier = Modifier
                .width(350.dp)
                .padding(34.dp, 24.dp, 0.dp, 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "MAXSTREAM",
                color = Color(0xFFE50914),
                fontSize = 15.sp,
                fontWeight = FontWeight.W900,
                letterSpacing = 3.sp
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Search",
                color = Color.White,
                fontSize = 34.sp,
                fontWeight = FontWeight.W800
            )
            Spacer(modifier = Modifier.height(5.dp))
            Text(
                text = "Find movies and series",
                color = Color.White.copy(alpha = 0.55f),
                fontSize = 15.sp
            )
            Spacer(modifier = Modifier.height(24.dp))

            TvKeyboard(
                onInput = { text -> query = text },
                onSubmit = {},
                initialText = query,
                focusManager = keyboardFocusManager,
                onMoveRight = {
                    keyboardFocusManager.focusOnContent()
                },
                onMoveLeft = {
                    onReturnToSidebar()
                },
                modifier = Modifier.fillMaxWidth()
            )
        }

        Spacer(modifier = Modifier.width(34.dp))

        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(end = 34.dp)
        ) {
            androidx.compose.animation.AnimatedVisibility(
                visible = resultsKey.isNotEmpty() || isLoading,
                enter = fadeIn(tween(350)) + scaleIn(tween(350), initialScale = 0.98f),
                exit = fadeOut(tween(180)),
                modifier = Modifier.fillMaxSize()
            ) {
                if (isLoading) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Color(0xFFE50914))
                    }
                } else if (searchError != null) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(text = searchError ?: "Error", color = Color.Red)
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(text = "Please try again", color = Color.White)
                        }
                    }
                } else if (searchResults.isEmpty() && query.length >= 2) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(text = "No matches for \"$query\"", color = Color.White)
                    }
                } else if (hasResults) {
                    val grouped = searchResults.groupBy { it.mediaType.replaceFirstChar { c -> c.uppercase() } }
                    val sections = listOf("Movies", "TV Series") + grouped.keys.filter { it !in listOf("Movies", "TV Series") }
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(top = 24.dp, bottom = 56.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        item {
                            Text(
                                text = "Results for \"$query\"",
                                color = Color.White,
                                fontSize = 29.sp,
                                fontWeight = FontWeight.W800,
                                modifier = Modifier.padding(bottom = 15.dp)
                            )
                        }
                        sections.forEach { section ->
                            val sectionItems = grouped[section] ?: emptyList()
                            if (sectionItems.isNotEmpty()) {
                                item {
                                    Column {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            modifier = Modifier.padding(bottom = 12.dp)
                                        ) {
                                            Box(
                                                modifier = Modifier
                                                    .size(width = 4.dp, height = 23.dp)
                                                    .background(Color(0xFFE50914), RoundedCornerShape(4.dp))
                                            )
                                            Spacer(modifier = Modifier.width(10.dp))
                                            Text(
                                                text = section,
                                                color = Color.White,
                                                fontSize = 21.sp,
                                                fontWeight = FontWeight.W700
                                            )
                                        }

                                        LazyRow(
                                            contentPadding = PaddingValues(horizontal = 4.dp),
                                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                                        ) {
                                            items(sectionItems) { item ->
                                                ContentCard(
                                                    posterUrl = item.posterUrl,
                                                    title = item.title,
                                                    rating = item.voteAverage.takeIf { it > 0 },
                                                    onClick = {
                                                        val route = if (item.mediaType == "tv") {
                                                            Screen.Series.createRoute(item.id.toString())
                                                        } else {
                                                            Screen.Details.createRoute(item.id.toString())
                                                        }
                                                        navController.navigate(route)
                                                    },
                                                    modifier = Modifier.height(180.dp)
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
    }
}
