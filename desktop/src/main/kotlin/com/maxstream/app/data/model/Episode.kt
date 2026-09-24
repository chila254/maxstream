package com.maxstream.app.data.model

/** An episode within a series, as surfaced to the desktop player UI. */
data class Episode(
    val id: String,
    val season: Int,
    val number: Int,
    val title: String,
    val overview: String = "",
    val stillPath: String? = null,
    val runtimeMinutes: Int? = null,
    val airDate: String? = null,
) {
    val label: String get() = "S${season}E${number}"
    val sortKey: Int get() = season * 1000 + number
}
