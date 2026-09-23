package com.maxstream.app.stream

/** A playable variant offered by one server (from StreamExtractor's result maps). */
data class ResolvedStream(
    val url: String,
    val server: String,
    val headers: Map<String, String> = emptyMap(),
    val qualities: List<ResolvedQuality> = emptyList(),
    val subtitles: List<ResolvedSubtitle> = emptyList(),
) {
    val referer: String? get() = headers["Referer"]
    val userAgent: String? get() = headers["User-Agent"]
    val origin: String? get() = headers["Origin"]

    fun qualityMatch(): List<ResolvedQuality> =
        qualities.sortedByDescending { it.height } // 0/unknown sorts last
}

data class ResolvedQuality(
    val label: String,
    val url: String,
    val height: Int,
)

data class ResolvedSubtitle(
    val label: String,
    val url: String,
    val isDefault: Boolean = false,
)

@Suppress("UNCHECKED_CAST")
fun parseStreams(raw: Any?): List<ResolvedStream> {
    val list = raw as? List<*> ?: return emptyList()
    return list.mapNotNull { item ->
        val m = item as? Map<*, *> ?: return@mapNotNull null
        val url = m["url"] as? String ?: return@mapNotNull null
        val headers = (m["headers"] as? Map<*, *>)?.mapKeys { it.key.toString() } as? Map<String, String>
            ?: emptyMap()
        val qualities = (m["qualities"] as? List<*>)?.mapNotNull { q ->
            val qm = q as? Map<*, *> ?: return@mapNotNull null
            val qu = qm["url"] as? String ?: return@mapNotNull null
            ResolvedQuality(
                label = qm["label"] as? String ?: "",
                url = qu,
                height = (qm["height"] as? Number)?.toInt() ?: 0,
            )
        } ?: emptyList()
        val subtitles = (m["subtitles"] as? List<*>)?.mapNotNull { s ->
            val sm = s as? Map<*, *> ?: return@mapNotNull null
            val su = sm["url"] as? String ?: return@mapNotNull null
            ResolvedSubtitle(
                label = sm["label"] as? String ?: "Subtitles",
                url = su,
                isDefault = sm["default"] as? Boolean ?: false,
            )
        } ?: emptyList()
        ResolvedStream(
            url = url,
            server = m["server"] as? String ?: m["source"] as? String ?: "Server",
            headers = headers,
            qualities = qualities,
            subtitles = subtitles,
        )
    }
}