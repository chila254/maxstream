package com.maxstream.app.util

import android.content.Context
import androidx.compose.ui.graphics.Color
import com.maxstream.app.data.local.ProfileScope

/** Kids profile UI theme — brighter, more playful colors. */
object KidsTheme {
    fun isKids(context: Context): Boolean =
        ProfileScope.activeProfile(context)?.isKids == true

    // ── Accent Colors ──────────────────────────────────────────────
    fun primary(context: Context) = if (isKids(context)) Color(0xFF10B981) else Color(0xFFE50914)
    fun secondary(context: Context) = if (isKids(context)) Color(0xFF06B6D4) else Color(0xFFE50914)
    fun accent(context: Context) = if (isKids(context)) Color(0xFFF59E0B) else Color(0xFFE50914)

    // ── Background ─────────────────────────────────────────────────
    fun background(context: Context) = if (isKids(context)) Color(0xFF0A1628) else Color(0xFF0D0D0D)
    fun surface(context: Context) = if (isKids(context)) Color(0xFF0F2035) else Color(0xFF1A1A1A)
    fun cardBg(context: Context) = if (isKids(context)) Color(0xFF132A42) else Color(0xFF1C1C1E)

    // ── Text ───────────────────────────────────────────────────────
    fun textPrimary(context: Context) = Color.White
    fun textSecondary(context: Context) = if (isKids(context)) Color(0xFF94D2BD) else Color(0xFFAAAAAA)

    // ── Navigation ─────────────────────────────────────────────────
    fun navSelected(context: Context) = if (isKids(context)) Color(0xFF10B981) else Color(0xFFE50914)
    fun navUnselected(context: Context) = if (isKids(context)) Color(0xFF4A7C6F) else Color(0xFF666666)

    // ── Profile Colors ─────────────────────────────────────────────
    fun profileColors(context: Context) = if (isKids(context)) listOf(
        Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFFF59E0B),
        Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF3B82F6),
    ) else listOf(
        Color(0xFFE50914), Color(0xFF6366F1), Color(0xFF8B5CF6),
        Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF10B981),
    )
}
