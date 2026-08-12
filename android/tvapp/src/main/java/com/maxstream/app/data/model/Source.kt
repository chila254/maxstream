package com.maxstream.app.data.model

/**
 * A resolved playback source returned by the extraction layer.
 *
 * Maps directly from [com.maxstream.app.StreamExtractor.resolveStream],
 * which returns a `Map<String, Any>` with keys: url, source, server, type,
 * headers, referer, qualities, subtitles, separateAudio.
 */
data class Source(
    val url: String,
    val server: String,
    val type: String, // "direct_m3u8" | "direct_video" | ...
    val headers: Map<String, String> = emptyMap(),
    val qualities: List<Quality> = emptyList(),
    val subtitles: List<Subtitle> = emptyList(),
    val separateAudio: Boolean = false,
) {
    val isHls: Boolean get() = type == "direct_m3u8" || url.contains(".m3u8", ignoreCase = true)

    companion object
}

data class Quality(
    val label: String,
    val url: String,
    val height: Int,
    val codec: String = "",
) {
    fun toBundle() = android.os.Bundle().apply {
        putString("label", label)
        putString("url", url)
        putInt("height", height)
        putString("codec", codec)
    }

    companion object {
        fun fromBundle(b: android.os.Bundle) = Quality(
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
    fun toBundle() = android.os.Bundle().apply {
        putString("label", label)
        putString("url", url)
        putBoolean("isDefault", isDefault)
        putString("source", source)
    }

    companion object {
        fun fromBundle(b: android.os.Bundle) = Subtitle(
            label = b.getString("label").orEmpty(),
            url = b.getString("url").orEmpty(),
            isDefault = b.getBoolean("isDefault", false),
            source = b.getString("source").orEmpty(),
        )
    }
}

fun Source.toBundle(): android.os.Bundle = android.os.Bundle().apply {
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

fun Source.Companion.fromBundle(b: android.os.Bundle): Source {
    @Suppress("UNCHECKED_CAST")
    val headers = (b.getSerializable("headers") as? HashMap<String, String>) ?: HashMap()
    val qualities = b.getParcelableArrayList<android.os.Bundle>("qualities").orEmpty()
        .map { Quality.fromBundle(it) }
    val subtitles = b.getParcelableArrayList<android.os.Bundle>("subtitles").orEmpty()
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

