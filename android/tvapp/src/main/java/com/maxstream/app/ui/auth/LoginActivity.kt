package com.maxstream.app.ui.auth

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.maxstream.app.R
import com.maxstream.app.data.repository.AuthRepository
import com.maxstream.app.ui.shell.MainActivity
import kotlinx.coroutines.launch

class LoginActivity : AppCompatActivity() {
    private var tab = 0

    private lateinit var codeField: EditText
    private lateinit var emailField: EditText
    private lateinit var passwordField: EditText
    private lateinit var submit: Button
    private lateinit var errorView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.tv_login)
        codeField = findViewById(R.id.codeField)
        emailField = findViewById(R.id.emailField)
        passwordField = findViewById(R.id.passwordField)
        submit = findViewById(R.id.submit)
        errorView = findViewById(R.id.error)

        findViewById<Button>(R.id.tabCode).setOnClickListener { selectTab(0) }
        findViewById<Button>(R.id.tabSignIn).setOnClickListener { selectTab(1) }
        findViewById<Button>(R.id.tabSignUp).setOnClickListener { selectTab(2) }
        submit.setOnClickListener { onSubmit() }
        selectTab(0)
    }

    private fun selectTab(index: Int) {
        tab = index
        codeField.visibility = if (index == 0) View.VISIBLE else View.GONE
        emailField.visibility = if (index == 0) View.GONE else View.VISIBLE
        passwordField.visibility = if (index == 0) View.GONE else View.VISIBLE
        submit.text = when (index) {
            0 -> "Sign In with Code"
            1 -> "Sign In"
            else -> "Create Account"
        }
        errorView.visibility = View.GONE
    }

    private fun onSubmit() {
        errorView.visibility = View.GONE
        lifecycleScope.launch {
            val result = when (tab) {
                0 -> {
                    val codeResult = AuthRepository.authenticateWithDeviceCode(codeField.text.toString())
                    if (codeResult.isSuccess) {
                        val email = codeResult.getOrNull()?.email.orEmpty()
                        if (email.isNotBlank()) AuthRepository.signInWithEmail(email, "").map { email }
                        else Result.failure(IllegalArgumentException("Empty code"))
                    } else {
                        Result.failure(codeResult.exceptionOrNull() ?: IllegalStateException("Invalid code"))
                    }
                }
                1 -> AuthRepository.signInWithEmail(emailField.text.toString(), passwordField.text.toString())
                    .map { emailField.text.toString() }
                else -> AuthRepository.signUpWithEmail(emailField.text.toString(), passwordField.text.toString())
                    .map { emailField.text.toString() }
            }
            result.onSuccess { email ->
                AuthRepository.completeSignIn(this@LoginActivity, email)
                startActivity(Intent(this@LoginActivity, MainActivity::class.java))
                finish()
            }.onFailure {
                errorView.text = it.message ?: "Authentication failed"
                errorView.visibility = View.VISIBLE
            }
        }
    }
}
