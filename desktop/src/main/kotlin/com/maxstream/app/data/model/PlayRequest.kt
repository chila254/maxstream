package com.maxstream.app.data.model

/** What the player needs to start playback for a title or one episode. */
data class PlayRequest(
    val itemId: String,
    val mediaType: String,
    val title: String,
    val season: Int = 1,
    val episode: Int = 1,
)