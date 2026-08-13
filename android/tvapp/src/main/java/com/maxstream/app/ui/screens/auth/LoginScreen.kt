package com.maxstream.app.ui.screens.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.layout.size
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.maxstream.app.data.local.SessionManager
import com.maxstream.app.data.repository.AuthRepository
import com.maxstream.app.ui.components.TvKeyboard
import com.maxstream.app.ui.theme.Background
import com.maxstream.app.ui.theme.Primary
import com.maxstream.app.ui.tv.TvKeyboardFocusManager
import kotlinx.coroutines.launch

/**
 * TV-optimised login screen.
 * Uses [TvKeyboard] for email and password entry.
 * Two modes: EMAIL then PASSWORD — pressing DONE on each advances to the next.
 * Calls [onLoginSuccess] on successful auth.
 */
@Composable
fun LoginScreen(onLoginSuccess: () -> Unit) {
    val context = LocalContext.current
    val scope   = rememberCoroutineScope()

    var email       by remember { mutableStateOf("") }
    var password    by remember { mutableStateOf("") }
    var isEmailMode by remember { mutableStateOf(true) }  // true = typing email
    var isLoading   by remember { mutableStateOf(false) }
    var errorMsg    by remember { mutableStateOf<String?>(null) }

    val emailKeyboardFocusManager    = remember { TvKeyboardFocusManager() }
    val passwordKeyboardFocusManager = remember { TvKeyboardFocusManager() }
    val emailKeyboardRequester   = remember { FocusRequester() }
    val passwordKeyboardRequester = remember { FocusRequester() }
    val loginButtonRequester      = remember { FocusRequester() }

    // Start with email keyboard focused
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(120)
        runCatching { emailKeyboardRequester.requestFocus() }
    }

    fun doLogin() {
        if (email.isBlank() || password.isBlank()) {
            errorMsg = "Please enter email and password"
            return
        }
        scope.launch {
            isLoading = true; errorMsg = null
            try {
                val result = AuthRepository.signInWithEmail(email.trim(), password)
                if (result.isSuccess) {
                    AuthRepository.completeSignIn(context, email.trim())
                    onLoginSuccess()
                } else {
                    errorMsg = result.exceptionOrNull()?.message ?: "Login failed"
                }
            } catch (e: Exception) {
                errorMsg = e.message ?: "Login failed"
            } finally {
                isLoading = false
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        Row(modifier = Modifier.fillMaxSize()) {
            // ── Left panel: branding ───────────────────────────────────────
            Box(
                modifier = Modifier
                    .width(320.dp)
                    .fillMaxHeight()
                    .background(Color(0xFF0D0D0D)),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .size(72.dp)
                            .clip(RoundedCornerShape(18.dp))
                            .background(Color(0xFFE50914)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("M", color = Color.White, fontSize = 38.sp, fontWeight = FontWeight.Black)
                    }
                    Spacer(Modifier.height(20.dp))
                    Text("MAXSTREAM", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.W900, letterSpacing = 4.sp)
                    Spacer(Modifier.height(8.dp))
                    Text("Stream Everything", color = Color.White.copy(alpha = 0.5f), fontSize = 14.sp)
                }
            }

            // ── Right panel: keyboard entry ────────────────────────────────
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .padding(48.dp),
                verticalArrangement = Arrangement.Center,
            ) {
                Text("Sign In", color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                Text(
                    "Use your MaxStream account",
                    color = Color.White.copy(alpha = 0.5f),
                    fontSize = 15.sp,
                )
                Spacer(Modifier.height(32.dp))

                // Field indicator
                Row(
                    modifier = Modifier.fillMaxWidth(0.6f),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FieldTab(label = "Email",    isActive = isEmailMode,   onClick = { isEmailMode = true })
                    FieldTab(label = "Password", isActive = !isEmailMode,  onClick = { isEmailMode = false })
                }

                Spacer(Modifier.height(24.dp))

                // Keyboard — switches between email and password mode
                AnimatedVisibility(visible = isEmailMode, enter = fadeIn(tween(220)), exit = fadeOut(tween(180))) {
                    TvKeyboard(
                        onInput = { email = it },
                        onSubmit = {
                            isEmailMode = false
                            runCatching { passwordKeyboardRequester.requestFocus() }
                        },
                        initialText = email,
                        focusManager = emailKeyboardFocusManager,
                        focusRequester = emailKeyboardRequester,
                        onMoveRight = {
                            isEmailMode = false
                            runCatching { passwordKeyboardRequester.requestFocus() }
                        },
                        onMoveLeft = { /* already at left edge of content */ },
                        modifier = Modifier.fillMaxWidth(0.8f),
                    )
                }
                AnimatedVisibility(visible = !isEmailMode, enter = fadeIn(tween(220)), exit = fadeOut(tween(180))) {
                    TvKeyboard(
                        onInput = { password = it },
                        onSubmit = { doLogin() },
                        initialText = password,
                        focusManager = passwordKeyboardFocusManager,
                        focusRequester = passwordKeyboardRequester,
                        onMoveRight = { runCatching { loginButtonRequester.requestFocus() } },
                        onMoveLeft = {
                            isEmailMode = true
                            runCatching { emailKeyboardRequester.requestFocus() }
                        },
                        modifier = Modifier.fillMaxWidth(0.8f),
                    )
                }

                Spacer(Modifier.height(28.dp))

                // Error message
                if (errorMsg != null) {
                    Text(text = errorMsg!!, color = Color(0xFFE50914), fontSize = 14.sp)
                    Spacer(Modifier.height(12.dp))
                }

                // Login button
                Button(
                    onClick = { doLogin() },
                    modifier = Modifier
                        .focusRequester(loginButtonRequester)
                        .focusable(),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE50914)),
                    enabled = !isLoading,
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        Text("Sign In", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun FieldTab(label: String, isActive: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(if (isActive) Color(0xFFE50914) else Color(0xFF2A2A2A))
            .border(
                width = 1.dp,
                color = if (isActive) Color(0xFFE50914) else Color.White.copy(alpha = 0.15f),
                shape = RoundedCornerShape(6.dp),
            )
            .focusable()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = if (isActive) Color.White else Color.White.copy(alpha = 0.5f),
            fontSize = 13.sp,
            fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

// PairingScreen is defined in PairingScreen.kt
