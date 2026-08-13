package com.maxstream.app.ui.screens.details

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Card
import androidx.tv.material3.CardDefaults
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import androidx.navigation.NavController
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.ui.theme.SurfaceVariant
import com.maxstream.app.ui.viewmodel.DetailsViewModel
import coil.compose.AsyncImage
import androidx.compose.foundation.shape.RoundedCornerShape

@Composable
fun DetailsScreen(navController: NavController, itemJson: String) {
    val viewModel = androidx.lifecycle.viewmodel.compose.viewModel<DetailsViewModel>()
    val item = remember(itemJson) {
        try {
            com.google.gson.Gson().fromJson(java.net.URLDecoder.decode(itemJson, "UTF-8"), MediaItem::class.java)
        } catch (e: Exception) { null }
    } ?: return

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Box(modifier = Modifier.fillMaxWidth().height(300.dp)) {
                AsyncImage(
                    model = item.backdropUrl.ifBlank { item.posterUrl },
                    contentDescription = item.title,
                    modifier = Modifier.fillMaxSize(),
                )
                Column(modifier = Modifier.align(Alignment.BottomStart).padding(24.dp)) {
                    Text(text = item.title, style = MaterialTheme.typography.headlineLarge)
                    Text(text = "${item.releaseDate.take(4)} • ${if (item.isMovie) "Movie" else "TV Series"}", style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
        item {
            Column(modifier = Modifier.padding(horizontal = 48.dp)) {
                Text(text = item.overview.ifBlank { "No overview available." }, style = MaterialTheme.typography.bodyLarge)
                Spacer(modifier = Modifier.height(16.dp))
                Card(
                    onClick = { viewModel.resolve() },
                    modifier = Modifier.fillMaxWidth(),
                    shape = CardDefaults.shape(RoundedCornerShape(12.dp)),
                ) {
                    Box(modifier = Modifier.background(MaterialTheme.colorScheme.primary).padding(16.dp)) {
                        Text(text = "Play", color = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.align(Alignment.Center))
                    }
                }
            }
        }
    }
}
