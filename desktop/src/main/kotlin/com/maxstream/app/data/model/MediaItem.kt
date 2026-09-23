package com.maxstream.app.data.model

/** A catalog entry shared by the desktop UI. Independent from the TV/mobile
 *  models — the desktop client has its own data shape so a native backend can
 *  be wired in later without coupling to the TV app's Flutter-derived JSON. */
data class MediaItem(
    val id: String,
    val title: String,
    val mediaType: String, // "movie" | "tv"
    val overview: String,
    val year: Int? = null,
    val genres: List<String> = emptyList(),
    val rating: Double = 0.0,
    /** 0.0..1.0 — how much the user has watched (Continue Watching). */
    val progress: Float = 0f,
) {
    val displayYear: String get() = year?.toString() ?: ""
    val typeLabel: String get() = if (mediaType == "tv") "Series" else "Movie"
}