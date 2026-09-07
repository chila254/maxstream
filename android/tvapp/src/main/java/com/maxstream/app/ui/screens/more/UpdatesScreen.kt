package com.maxstream.app.ui.screens.more

import android.content.Intent
import android.net.Uri
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URL

private data class UpdateInfo(
    val versionName: String = "",
    val tagName: String = "",
    val body: String = "",
    val downloadUrl: String = "",
)

@Composable
fun UpdatesScreen(
    onBack: () -> Unit = {},
) {
    val context = LocalContext.current
    val currentVersion = remember {
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.6.0"
        }.getOrDefault("1.6.0")
    }

    var updateInfo by remember { mutableStateOf<UpdateInfo?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        loading = true
        error = null
        try {
            val json = withContext(Dispatchers.IO) {
                URL("https://api.github.com/repos/chila254/maxstream/releases/latest").readText()
            }
            val obj = JSONObject(json)
            val tagName = obj.optString("tag_name", "")
            val versionName = tagName.removePrefix("v")
            val body = obj.optString("body", "")
            val assets = obj.optJSONArray("assets")
            var downloadUrl = ""
            if (assets != null) {
                for (i in 0 until assets.length()) {
                    val asset = assets.optJSONObject(i) ?: continue
                    val name = asset.optString("name", "")
                    if (name.endsWith(".apk") && (name.contains("arm64") || name.contains("universal"))) {
                        downloadUrl = asset.optString("browser_download_url", "")
                        break
                    }
                }
            }
            updateInfo = UpdateInfo(versionName, tagName, body, downloadUrl)
        } catch (e: Exception) {
            error = e.message ?: "Failed to check for updates"
        } finally {
            loading = false
        }
    }

    // Bug fix #1: Make the overlay Box focusable so its onKeyEvent fires before
    // the TvAppRoot Back handler (which would call handleBack() → open sidebar).
    val overlayFocusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        runCatching { overlayFocusRequester.requestFocus() }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF121212))
            .focusRequester(overlayFocusRequester)
            .focusable()
            .onKeyEvent { event ->
                if (event.type == KeyEventType.KeyDown && (event.key == Key.Back || event.key == Key.Escape)) {
                    onBack(); true
                } else false
            }
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
                val hasUpdate = info.versionName.isNotEmpty() && info.versionName != currentVersion

                if (hasUpdate) {
                    Text(text = "Update Available", color = Color(0xFF4CAF50), fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Text(text = "Version ${info.tagName}", color = Color.White, fontSize = 16.sp)
                    Spacer(Modifier.height(16.dp))

                    if (info.body.isNotEmpty()) {
                        Text(text = "Changelog", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(8.dp))
                        Text(text = info.body, color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp, lineHeight = 22.sp)
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
}
