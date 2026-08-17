package com.maxstream.app.ui.screens.splash

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.R
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.theme.Primary
import kotlinx.coroutines.delay

/**
 * Splash screen — no NavController dependency.
 * Calls [onComplete] after a brief delay; the caller (MainActivity's NavHost)
 * decides where to navigate next.
 */
@Composable
fun SplashScreen(onComplete: () -> Unit) {
    LaunchedEffect(Unit) {
        delay(1800)
        onComplete()
    }

    val pulse = rememberInfiniteTransition(label = "splashPulse")
    val scale by pulse.animateFloat(
        initialValue = 1f,
        targetValue = 1.08f,
        animationSpec = infiniteRepeatable(
            animation = tween(900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "splashScale",
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            // Logo mark — enlarged to match the Dart splash (which uses ~200dp)
            Image(
                painter = painterResource(R.drawable.maxstream_logo),
                contentDescription = "MaxStream logo",
                modifier = Modifier
                    .scale(scale)
                    .size(240.dp),
            )

            Spacer(Modifier.height(24.dp))

            Text(
                text = "MaxStream TV",
                color = Color.White,
                fontSize = 44.sp,
                fontWeight = FontWeight.W900,
                letterSpacing = 0.sp,
            )

            Spacer(Modifier.height(48.dp))

            CircularProgressIndicator(
                color = Primary,
                strokeWidth = 4.dp,
                modifier = Modifier.size(48.dp),
            )
        }
    }
}
