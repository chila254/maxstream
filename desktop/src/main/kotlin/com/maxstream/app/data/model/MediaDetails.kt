package com.maxstream.app.data.model

/**
 * Full detail payload for a title — the merge of TMDB credits/videos/seasons
 * and watch providers that the details screen renders.
 */
data class MediaDetails(
    val item: MediaItem,
    val cast: List<CastMember> = emptyList(),
    val trailers: List<Trailer> = emptyList(),
    val seasons: List<Season> = emptyList(),
    val providers: List<StreamingProvider> = emptyList(),
)

data class CastMember(
    val name: String,
    val character: String,
    val profilePath: String? = null,
)

data class Trailer(
    val name: String,
    val site: String, // "YouTube"
    val key: String,
) {
    // TmdbClient already filters to YouTube-only trailers, so both branches
    // of the old if/else built the same URL.
    val watchUrl: String get() = "https://www.youtube.com/watch?v=$key"
}

data class Season(
    val seasonNumber: Int,
    val name: String = "Season $seasonNumber",
    val episodeCount: Int = 0,
    val overview: String = "",
)

data class StreamingProvider(
    val name: String,
    val providerId: Int,
    val logoPath: String? = null,
)