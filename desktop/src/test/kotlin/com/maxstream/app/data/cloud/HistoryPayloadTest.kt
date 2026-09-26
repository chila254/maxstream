package com.maxstream.app.data.cloud

import com.maxstream.app.data.WatchStateStore
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * database.rules.json only allows watch_history writes when `isWatched` is
 * present and false — a regression here means every cloud progress push is
 * silently denied while the UI looks like it synced.
 */
class HistoryPayloadTest {

    private fun state(
        mediaType: String = "movie",
        season: Int = 1,
        episode: Int = 1,
        poster: String? = null,
        year: Int? = null,
    ) = WatchStateStore.WatchState(
        itemId = "tt42",
        mediaType = mediaType,
        season = season,
        episode = episode,
        positionMs = 5_000L,
        lengthMs = 20_000L,
        updatedAt = 1_700_000_000_000L,
        title = "Some Title",
        posterPath = poster,
        backdropPath = "/bd.jpg",
        year = year,
        rating = 8.2,
    )

    @Test
    fun payloadAlwaysCarriesIsWatchedFalse() {
        val payload = CloudSync.historyPayload(state())
        assertTrue(payload.has("isWatched"))
        assertFalse(payload.getBoolean("isWatched"))
    }

    @Test
    fun payloadMapsProgressFields() {
        val payload = CloudSync.historyPayload(state(mediaType = "tv", season = 2, episode = 7))
        assertEquals("tt42", payload.getString("itemId"))
        assertEquals("tv", payload.getString("mediaType"))
        assertEquals(2, payload.getInt("season"))
        assertEquals(7, payload.getInt("episode"))
        assertEquals(5_000L, payload.getLong("positionMs"))
        assertEquals(20_000L, payload.getLong("lengthMs"))
        assertEquals(0.25, payload.getDouble("progress"), 1e-6)
        assertEquals("Some Title", payload.getString("title"))
        assertEquals(8.2, payload.getDouble("rating"), 1e-6)
    }

    @Test
    fun optionalMetadataNeverWritesJsonNull() {
        val payload = CloudSync.historyPayload(state(poster = null, year = null))
        assertEquals("", payload.getString("posterPath"))
        assertEquals(0, payload.getInt("year"))
        assertFalse(payload.isNull("posterPath"))
        assertFalse(payload.isNull("year"))
    }

    @Test
    fun historyKeyMatchesMobileConvention() {
        assertEquals("movie_tt42", CloudSync.historyKey(state(mediaType = "movie")))
        assertEquals("tv_tt42_2_7", CloudSync.historyKey(state(mediaType = "tv", season = 2, episode = 7)))
    }
}
