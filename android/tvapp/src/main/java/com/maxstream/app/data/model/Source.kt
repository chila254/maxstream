package com.maxstream.app.data.model

import android.os.Bundle

data class Source(
    val url: String,
    val server: String,
    val type: String,
    val headers: Map<String, String> = emptyMap(),
    val qualities: List<Quality> = emptyList(),
    val subtitles: List<Subtitle> = emptyList(),
    val separateAudio: Boolean = false,
) {
    val isHls: Boolean get() = type == "direct_m3u8" || url.contains(".m3u8", ignoreCase = true)

    companion object {
        fun fromBundle(b: Bundle): Source {
            @Suppress("UNCHECKED_CAST")
            val headers = (b.getSerializable("headers") as? HashMap<String, String>) ?: HashMap()
            val qualities = b.getParcelableArrayList<Bundle>("qualities").orEmpty()
                .map { Quality.fromBundle(it) }
            val subtitles = b.getParcelableArrayList<Bundle>("subtitles").orEmpty()
                .map { Subtitle.fromBundle(it) }
            return Source(
                url = b.getString("url").orEmpty(),
                server = b.getString("server").orEmpty(),
                type = b.getString("type").orEmpty(),
                headers = headers,
                qualities = qualities,
                subtitles = subtitles,
                separateAudio = b.getBoolean("separateAudio", false),
            )
        }
    }
}

data class Quality(
    val label: String,
    val url: String,
    val height: Int,
    val codec: String = "",
) {
    fun toBundle() = Bundle().apply {
        putString("label", label)
        putString("url", url)
        putInt("height", height)
        putString("codec", codec)
    }

    companion object {
        fun fromBundle(b: Bundle) = Quality(
            label = b.getString("label").orEmpty(),
            url = b.getString("url").orEmpty(),
            height = b.getInt("height", 0),
            codec = b.getString("codec").orEmpty(),
        )
    }
}

data class Subtitle(
    val label: String,
    val url: String,
    val isDefault: Boolean = false,
    val source: String = "",
) {
    fun toBundle() = Bundle().apply {
        putString("label", label)
        putString("url", url)
        putBoolean("isDefault", isDefault)
        putString("source", source)
    }

    companion object {
        fun fromBundle(b: Bundle) = Subtitle(
            label = b.getString("label").orEmpty(),
            url = b.getString("url").orEmpty(),
            isDefault = b.getBoolean("isDefault", false),
            source = b.getString("source").orEmpty(),
        )
    }
}

fun Source.toBundle(): Bundle = Bundle().apply {
    putString("url", url)
    putString("server", server)
    putString("type", type)
    putSerializable("headers", HashMap(headers))
    putParcelableArrayList(
        "qualities",
        ArrayList(qualities.map { it.toBundle() }),
    )
    putParcelableArrayList(
        "subtitles",
        ArrayList(subtitles.map { it.toBundle() }),
    )
    putBoolean("separateAudio", separateAudio)
}
