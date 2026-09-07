package com.maxstream.app.data.local

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import org.json.JSONObject

data class TvSubtitleSettings(
    val textColor: String = "#FFFFFF",
    val backgroundColor: String = "#000000",
    val backgroundOpacity: Float = 0.55f,
    val fontSize: Float = 22f,
    val fontFamily: String = "",
    val textShadow: Boolean = true,
    val textShadowColor: String = "#000000",
    val edgeType: String = "outline",
    val edgeColor: String = "#000000",
    val position: String = "bottom",
    val subtitleOffsetMs: Float = 0f,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("textColor", textColor)
        put("backgroundColor", backgroundColor)
        put("backgroundOpacity", backgroundOpacity.toDouble())
        put("fontSize", fontSize.toDouble())
        put("fontFamily", fontFamily)
        put("textShadow", textShadow)
        put("textShadowColor", textShadowColor)
        put("edgeType", edgeType)
        put("edgeColor", edgeColor)
        put("position", position)
        put("subtitleOffsetMs", subtitleOffsetMs.toDouble())
    }

    companion object {
        fun fromJson(json: JSONObject): TvSubtitleSettings = TvSubtitleSettings(
            textColor = json.optString("textColor", "#FFFFFF"),
            backgroundColor = json.optString("backgroundColor", "#000000"),
            backgroundOpacity = json.optDouble("backgroundOpacity", 0.55).toFloat(),
            fontSize = json.optDouble("fontSize", 22.0).toFloat(),
            fontFamily = json.optString("fontFamily", ""),
            textShadow = json.optBoolean("textShadow", true),
            textShadowColor = json.optString("textShadowColor", "#000000"),
            edgeType = json.optString("edgeType", "outline"),
            edgeColor = json.optString("edgeColor", "#000000"),
            position = json.optString("position", "bottom"),
            subtitleOffsetMs = json.optDouble("subtitleOffsetMs", 0.0).toFloat(),
        )
    }
}

object SubtitleSettingsRepository {
    private const val TAG = "SubtitleSettingsRepo"
    private const val PREFS = "maxstream_tv_subtitle_settings"
    private const val KEY_JSON = "settings_json"

    private var cached: TvSubtitleSettings? = null

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(context: Context): TvSubtitleSettings {
        cached?.let { return it }
        val raw = prefs(context).getString(KEY_JSON, null)
        val settings = if (raw != null) {
            try {
                TvSubtitleSettings.fromJson(JSONObject(raw))
            } catch (e: Exception) {
                Log.w(TAG, "Failed to parse saved settings, using defaults")
                TvSubtitleSettings()
            }
        } else {
            TvSubtitleSettings()
        }
        cached = settings
        return settings
    }

    fun save(context: Context, settings: TvSubtitleSettings) {
        cached = settings
        prefs(context).edit().putString(KEY_JSON, settings.toJson().toString()).apply()
        pushToCloud()
    }

    fun invalidateCache() {
        cached = null
    }

    private fun pushToCloud() {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val settings = cached ?: return
        try {
            val data = settings.toJson()
            data.put("updatedAt", com.google.firebase.database.ServerValue.timestamp)
            FirebaseDatabase.getInstance()
                .reference
                .child("users")
                .child(uid)
                .child("user_preferences")
                .child("subtitle_settings")
                .setValue(data)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to push subtitle settings to cloud: ${e.message}")
        }
    }

    fun pullFromCloud(context: Context, onComplete: (() -> Unit)? = null) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        try {
            val ref = FirebaseDatabase.getInstance()
                .reference
                .child("users")
                .child(uid)
                .child("user_preferences")
                .child("subtitle_settings")

            ref.get().addOnSuccessListener { snapshot ->
                val value = snapshot.value
                if (value is Map<*, *>) {
                    try {
                        val json = JSONObject()
                        for ((k, v) in value) {
                            json.put(k.toString(), v)
                        }
                        val settings = TvSubtitleSettings.fromJson(json)
                        cached = settings
                        prefs(context).edit().putString(KEY_JSON, settings.toJson().toString()).apply()
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to parse cloud settings: ${e.message}")
                    }
                }
                onComplete?.invoke()
            }.addOnFailureListener { e ->
                Log.w(TAG, "Failed to pull subtitle settings: ${e.message}")
                onComplete?.invoke()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Pull failed: ${e.message}")
            onComplete?.invoke()
        }
    }
}
