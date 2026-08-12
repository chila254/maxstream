package com.maxstream.app.core

/**
 * Compile-time configuration shared by the native TV app.
 * The TMDB key mirrors the one used by the legacy Flutter client so the same
 * catalogue is served; replace via `./gradlew -PTMDB_API_KEY=...` if needed.
 */
object Constants {
    const val TMDB_API_KEY = "3b65c5fdee212a85a4e4ef208d31d74e"
    const val TMDB_BASE_URL = "https://api.themoviedb.org/3"
    const val TMDB_IMAGE_BASE = "https://image.tmdb.org/t/p"

    const val POSTER_SIZE = "w500"
    const val BACKDROP_SIZE = "w1280"
    const val PROFILE_SIZE = "w185"
    const val ORIGINAL_SIZE = "original"

    /** Default request timeout (seconds) for metadata + stream resolution. */
    const val NETWORK_TIMEOUT_SECONDS = 20L
}
