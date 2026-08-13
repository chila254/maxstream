package com.maxstream.app.ui.screens.home

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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.navigation.NavController
import androidx.lifecycle.compose.observeAsState
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.ui.theme.SurfaceVariant
import com.maxstream.app.ui.viewmodel.HomeViewModel
import coil.compose.AsyncImage
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape

@Composable
fun HomeScreen(navController: NavController) {
    val viewModel = androidx.lifecycle.viewmodel.compose.viewModel<HomeViewModel>()
    val trendingMovies by viewModel.trendingMovies.observeAsState(emptyList())
    val trendingSeries by viewModel.trendingSeries.observeAsState(emptyList())
    val popularMovies by viewModel.popularMovies.observeAsState(emptyList())
    val popularSeries by viewModel.popularSeries.observeAsState(emptyList())
    val topRatedMovies by viewModel.topRatedMovies.observeAsState(emptyList())
    val topRatedSeries by viewModel.topRatedSeries.observeAsState(emptyList())

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        item { Text(text = "MaxStream", style = MaterialTheme.typography.headlineLarge, modifier = Modifier.padding(horizontal = 48.dp)) }
        if (trendingMovies.isNotEmpty()) item { contentRow("Trending Movies", trendingMovies, navController) }
        if (trendingSeries.isNotEmpty()) item { contentRow("Trending Series", trendingSeries, navController) }
        if (popularMovies.isNotEmpty()) item { contentRow("Popular Movies", popularMovies, navController) }
        if (popularSeries.isNotEmpty()) item { contentRow("Popular Series", popularSeries, navController) }
        if (topRatedMovies.isNotEmpty()) item { contentRow("Top Rated Movies", topRatedMovies, navController) }
        if (topRatedSeries.isNotEmpty()) item { contentRow("Top Rated Series", topRatedSeries, navController) }
    }
}

@Composable
private fun contentRow(title: String, items: List<MediaItem>, navController: NavController) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(text = title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(horizontal = 48.dp))
        Spacer(modifier = Modifier.height(12.dp))
        LazyRow(
            contentPadding = PaddingValues(horizontal = 48.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(items) { item ->
                Card(
                    onClick = {
                        val json = java.net.URLEncoder.encode(
                            com.google.gson.Gson().toJson(item),
                            "UTF-8"
                        )
                        navController.navigate(com.maxstream.app.ui.navigation.Screen.Details.createRoute(json))
                    },
                    modifier = Modifier.height(180.dp),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Box(modifier = Modifier.background(SurfaceVariant)) {
                        AsyncImage(
                            model = item.posterUrl,
                            contentDescription = item.title,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                }
            }
        }
    }
}
