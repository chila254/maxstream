package com.maxstream.app.data

import org.json.JSONObject
import java.nio.file.Files
import java.nio.file.Paths

/**
 * Local user preferences (theme + default quality) persisted under
 * ~/.maxstream/preferences.json so Settings choices survive restarts.
 */
object AppPrefs {

    /** Material dark/light choice from Settings or the sidebar toggle. */
    var darkTheme: Boolean = true
        private set

    /** Settings → Streaming → Default quality label ("Auto", "720p", …). */
    var defaultQuality: String = "Auto"
        private set

    fun restore() {
        try {
            val f = file()
            if (Files.exists(f)) {
                val o = JSONObject(Files.readString(f))
                darkTheme = o.optBoolean("darkTheme", true)
                defaultQuality = o.optString("defaultQuality", "Auto").ifBlank { "Auto" }
            }
        } catch (e: Exception) {
            System.err.println("AppPrefs: could not read preferences, using defaults: $e")
        }
    }

    fun setDarkTheme(value: Boolean) {
        darkTheme = value
        persist()
    }

    fun setDefaultQuality(value: String) {
        defaultQuality = value.ifBlank { "Auto" }
        persist()
    }

    /** Target height for the preferred quality; 0 = Auto (highest available). */
    fun defaultQualityHeight(): Int = when (defaultQuality) {
        "480p" -> 480
        "720p" -> 720
        "1080p" -> 1080
        "4K" -> 2160
        else -> 0
    }

    private fun persist() {
        try {
            com.maxstream.app.core.AtomicFiles.write(
                file(),
                JSONObject()
                    .put("darkTheme", darkTheme)
                    .put("defaultQuality", defaultQuality)
                    .toString(),
            )
        } catch (e: Exception) {
            System.err.println("AppPrefs: failed to persist preferences: $e")
        }
    }

    private fun file() = Paths.get(System.getProperty("user.home"), ".maxstream", "preferences.json")
}
