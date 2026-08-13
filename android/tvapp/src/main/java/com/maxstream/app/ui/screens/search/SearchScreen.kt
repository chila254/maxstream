package com.maxstream.app.ui.screens.search

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.compose.ui.unit.dp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.navigation.NavController
import com.maxstream.app.R
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.di.Modules
import com.maxstream.app.ui.components.ContentCard
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@Composable
fun SearchScreen(navController: NavController) {
    var query by remember { mutableStateOf("") }
    var searchResults by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }
    var searchError by remember { mutableStateOf<String?>(null) }
    var debounceJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    val searchFieldFocusRequester = remember { FocusRequester() }

    LaunchedEffect(query) {
        debounceJob?.cancel()
        if (query.length < 2) {
            searchResults = emptyList()
            searchError = null
            isSearching = false
            return@LaunchedEffect
        }
        debounceJob = launch {
            delay(400)
            if (!isActive) return@launch
            isSearching = true
            searchError = null
            try {
                val results = Modules.catalogRepository.search(query)
                searchResults = results
            } catch (e: Exception) {
                searchError = e.message
                searchResults = emptyList()
            } finally {
                isSearching = false
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Background)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(48.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(text = "Search", style = MaterialTheme.typography.headlineLarge)
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                label = { Text("Search movies and series") },
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(searchFieldFocusRequester),
                singleLine = true
            )

            Spacer(modifier = Modifier.height(16.dp))

            if (isSearching) {
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                }
            } else if (searchError != null) {
                Text(text = "Error: $searchError", color = Color(0xFFCF6679))
            } else if (searchResults.isNotEmpty()) {
                LazyRow(
                    state = rememberLazyListState(),
                    contentPadding = PaddingValues(horizontal = 48.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(searchResults) { item ->
                        val isSeries = item.mediaType == "tv"
                        ContentCard(
                            posterUrl = item.posterUrl,
                            title = item.title,
                            rating = item.voteAverage.takeIf { it > 0 },
                            onClick = {
                                val route = if (isSeries) {
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
            } else if (query.isNotBlank() && !isSearching) {
                Text(text = "No results found", color = Color.White)
            }
        }
    }
}
