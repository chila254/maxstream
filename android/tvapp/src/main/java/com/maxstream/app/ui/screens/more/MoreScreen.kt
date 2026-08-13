package com.maxstream.app.ui.screens.more

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.maxstream.app.R
import com.maxstream.app.data.local.SessionManager
import com.maxstream.app.ui.navigation.Screen
import com.maxstream.app.ui.theme.Background

@Composable
fun MoreScreen(navController: NavController, onReturnToSidebar: () -> Unit = {}) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var userName by remember { mutableStateOf("MaxStream User") }
    var userEmail by remember { mutableStateOf("user@maxstream.app") }
    var focusedIndex by remember { mutableStateOf(0) }
    val menuItems = listOf("Help & Support", "About MaxStream", "Join Community", "Sign Out")

    LaunchedEffect(Unit) {
        val email = SessionManager.email(context)
        if (email.isNotBlank()) {
            userName = email.substringBefore("@")
            userEmail = email
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Background)) {
        Column(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 48.dp)
                    .padding(horizontal = 48.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    modifier = Modifier
                        .size(120.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF222222)),
                    contentAlignment = Alignment.Center
                ) {
                    androidx.compose.material3.Icon(
                        painter = painterResource(id = R.drawable.ic_home),
                        contentDescription = "Profile",
                        tint = Color.White,
                        modifier = Modifier.size(60.dp)
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = userName,
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold
                )
                if (userEmail.isNotBlank()) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = userEmail,
                        color = Color(0xFFB3B3B3),
                        fontSize = 14.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(32.dp))

            Column(
                modifier = Modifier.padding(horizontal = 48.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                menuItems.forEachIndexed { index, title ->
                    val isDestructive = index == menuItems.lastIndex
                    val isFocused = index == focusedIndex
                    val focusRequester = remember { FocusRequester() }

                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = if (isFocused) Color(0xFF2A2A2A) else Color(0xFF1A1A1A),
                        modifier = Modifier
                            .fillMaxWidth()
                            .focusRequester(focusRequester)
                            .onFocusChanged { focusState ->
                                if (focusState.hasFocus) {
                                    focusedIndex = index
                                }
                            }
                    ) {
                        TextButton(
                            onClick = {
                                if (index == 3) {
                                    SessionManager.signOut(context)
                                    navController.navigate(Screen.Login.route) {
                                        popUpTo(navController.graph.startDestinationId) { inclusive = true }
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp)
                        ) {
                            Text(
                                text = title,
                                color = if (isDestructive) Color(0xFFCF6679) else Color.White,
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Medium,
                                modifier = Modifier.weight(1f)
                            )
                            androidx.compose.material3.Icon(
                                painter = painterResource(id = R.drawable.ic_more),
                                contentDescription = null,
                                tint = Color.Gray,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}
