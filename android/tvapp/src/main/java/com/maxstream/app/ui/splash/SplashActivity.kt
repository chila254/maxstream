package com.maxstream.app.ui.splash

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.appcompat.app.AppCompatActivity
import com.maxstream.app.data.local.SessionManager
import com.maxstream.app.ui.auth.LoginActivity
import com.maxstream.app.ui.shell.MainActivity

/** Native port of [TvSplashScreen] — routes to login or the main shell. */
class SplashActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.tv_splash)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        Handler(Looper.getMainLooper()).postDelayed({
            val target = if (SessionManager.isLoggedIn(this)) MainActivity::class.java else LoginActivity::class.java
            startActivity(Intent(this, target))
            finish()
        }, 1500)
    }
}
