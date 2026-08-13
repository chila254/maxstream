package com.maxstream.app.ui.screens.watchlist

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.material3.Text
import androidx.navigation.NavController

@Composable
fun WatchlistScreen(navController: NavController) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(com.maxstream.app.ui.theme.Background),
        contentAlignment = Alignment.Center
    ) {
        Column(modifier = Modifier.padding(48.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(text = "Watchlist", style = com.maxstream.app.ui.theme.MaterialTheme.typography.headlineLarge)
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
