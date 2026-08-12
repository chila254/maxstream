package com.maxstream.app.ui.auth

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.maxstream.app.R
import kotlin.random.Random

/** Native port of [TvPairingScreen] — generates a device pairing code. */
class PairingActivity : AppCompatActivity() {
    private lateinit var codeView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.tv_pairing)
        codeView = findViewById(R.id.code)
        findViewById<Button>(R.id.generate).setOnClickListener { regenerate() }
        findViewById<Button>(R.id.copy).setOnClickListener { copy() }
        regenerate()
    }

    private fun regenerate() {
        val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        val code = (1..6).map { chars[Random.nextInt(chars.length)] }.joinToString("")
        codeView.text = code
    }

    private fun copy() {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("MaxStream TV Code", codeView.text.toString()))
    }
}
