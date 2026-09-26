package com.maxstream.app.data

import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Regression tests for the stale-cache data-loss bug: the store used to freeze
 * the startup snapshot as its only persistence source, so saves made during a
 * session were silently dropped when any later save rewrote the file.
 */
class WatchStateStoreTest {

    private lateinit var dir: Path

    private fun state(
        id: String,
        pos: Long = 1_000L,
        updated: Long = 10L,
        season: Int = 1,
        episode: Int = 1,
        mediaType: String = "movie",
    ) = WatchStateStore.WatchState(
        itemId = id,
        mediaType = mediaType,
        season = season,
        episode = episode,
        positionMs = pos,
        lengthMs = 10_000L,
        updatedAt = updated,
        title = "Title-$id",
        posterPath = "/p.jpg",
        year = 2021,
        rating = 7.1,
    )

    @BeforeTest
    fun setUp() {
        dir = Files.createTempDirectory("maxstream-wss-test")
        WatchStateStore.baseDir = dir
        WatchStateStore.resetForTesting()
    }

    @AfterTest
    fun tearDown() {
        WatchStateStore.resetForTesting()
        dir.toFile().deleteRecursively()
    }

    @Test
    fun savesDuringSessionRemainVisibleToLaterReads() {
        WatchStateStore.save(state("m1", pos = 5_000, updated = 1))
        WatchStateStore.save(state("m2", pos = 7_000, updated = 2))
        WatchStateStore.save(state("m1", pos = 9_000, updated = 3))

        assertEquals(9_000, WatchStateStore.resumeFor("m1", 1, 1)?.positionMs)
        assertEquals(7_000, WatchStateStore.resumeFor("m2", 1, 1)?.positionMs)
        assertEquals(2, WatchStateStore.all().size)
    }

    @Test
    fun stateSurvivesReloadFromDisk() {
        WatchStateStore.save(state("m1", pos = 4_200, updated = 30))
        WatchStateStore.resetForTesting() // simulate process restart

        val loaded = WatchStateStore.resumeFor("m1", 1, 1)
        assertNotNull(loaded)
        assertEquals(4_200, loaded.positionMs)
        assertEquals("Title-m1", loaded.title)
        assertEquals(2021, loaded.year)
    }

    @Test
    fun clearAllWipesMemoryAndDisk() {
        WatchStateStore.save(state("m1"))
        WatchStateStore.clearAll()

        assertTrue(WatchStateStore.all().isEmpty())
        WatchStateStore.resetForTesting()
        assertTrue(WatchStateStore.all().isEmpty())
        assertNull(WatchStateStore.resumeFor("m1", 1, 1))
    }

    @Test
    fun corruptFileIsPreservedAsideNotDestroyed() {
        Files.writeString(dir.resolve("watchstate.json"), "{definitely not json")
        WatchStateStore.resetForTesting()

        assertTrue(WatchStateStore.all().isEmpty())
        assertTrue(Files.exists(dir.resolve("watchstate.json.corrupt")))
    }

    @Test
    fun mergeIncomingKeepsNewestPerEntry() {
        WatchStateStore.save(state("m1", pos = 1_000, updated = 100))
        val merged = WatchStateStore.mergeIncoming(
            listOf(
                state("m1", pos = 9_999, updated = 50), // older → ignored
                state("m1", pos = 2_222, updated = 200), // newer → wins
                state("m2", pos = 3_000, updated = 10), // missing → added
            ),
        )

        assertEquals(2, merged)
        assertEquals(2_222, WatchStateStore.resumeFor("m1", 1, 1)?.positionMs)
        assertEquals(3_000, WatchStateStore.resumeFor("m2", 1, 1)?.positionMs)
    }

    @Test
    fun episodesAreKeyedSeparately() {
        WatchStateStore.save(state("tv1", season = 1, episode = 1, pos = 111))
        WatchStateStore.save(state("tv1", season = 1, episode = 2, pos = 222))

        assertEquals(111, WatchStateStore.resumeFor("tv1", 1, 1)?.positionMs)
        assertEquals(222, WatchStateStore.resumeFor("tv1", 1, 2)?.positionMs)
        assertNull(WatchStateStore.resumeFor("tv1", 2, 1))
    }

    @Test
    fun progressFractionIsClamped() {
        assertEquals(0f, state("a", pos = 0).progress)
        assertEquals(1f, WatchStateStore.WatchState(
            itemId = "b", mediaType = "movie", season = 1, episode = 1,
            positionMs = 20_000L, lengthMs = 10_000L, updatedAt = 1,
        ).progress)
        assertEquals(0f, state("c", pos = 500).copy(lengthMs = 0L).progress)
    }
}
