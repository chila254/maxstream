package com.maxstream.app.ui.screens.more

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.repository.UpdateRepository

@Composable
fun UpdatesScreen(onBack: () -> Unit = {}) {
    BackHandler { onBack() }

    val context = LocalContext.current
    val currentVersion = remember { UpdateRepository.currentVersion(context) }

    var updateInfo by remember { mutableStateOf<UpdateRepository.UpdateInfo?>(null)
    }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        loading = true
        error = null
        updateInfo = try {
            UpdateRepository.checkForUpdate(context)
        } catch (e: Exception) {
            error = e.message ?: "Failed to check for updates"
            null
        } finally {
            loading = false
        }
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
                text = "Updates",
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Current version: $currentVersion",
                color = Color.Gray,
                fontSize = 14.sp,
            )
            Spacer(Modifier.height(24.dp))

            if (loading) {
                Text(text = "Checking for updates...", color = Color.Gray, fontSize = 16.sp)
            } else if (error != null) {
                Text(text = "Error: $error", color = Color.Red, fontSize = 16.sp)
            } else if (updateInfo != null) {
                val info = updateInfo!!
                Text(text = "Update Available", color = Color(0xFF4CAF50), fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                Text(text = "Version ${info.version}", color = Color.White, fontSize = 16.sp)
                Spacer(Modifier.height(16.dp))

                if (info.changelog.isNotEmpty()) {
                    Text(text = "Changelog", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    Text(text = info.changelog, color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp, lineHeight = 22.sp)
                    Spacer(Modifier.height(16.dp))
                }

                if (info.downloadUrl.isNotEmpty()) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color(0xFF4CAF50))
                            .clickable {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(info.downloadUrl))
                                context.startActivity(intent)
                            }
                            .padding(horizontal = 24.dp, vertical = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(text = "Download Update", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    }
                }
            } else {
                Text(text = "You're up to date!", color = Color(0xFF4CAF50), fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                Text(text = "Version $currentVersion is the latest release.", color = Color.Gray, fontSize = 16.sp)
            }
        }
    }
}
