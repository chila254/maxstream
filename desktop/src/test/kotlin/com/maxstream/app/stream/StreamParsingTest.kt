package com.maxstream.app.stream

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Contract tests for the extractors' raw result maps → UI models: failed rows
 * must never become playable streams, and multi-audio/separateAudio metadata
 * has to survive the round trip into the player.
 */
class StreamParsingTest {

    private fun streamMap(
        url: String = "https://cdn.example/master.m3u8",
        server: String = "VidLink",
        extra: Map<String, Any> = emptyMap(),
    ): Map<String, Any> = buildMap {
        put("url", url)
        put("server", server)
        put(
            "headers",
            mapOf("Referer" to "https://site.example/", "User-Agent" to "UA"),
        )
        put(
            "qualities",
            listOf(
                mapOf("label" to "1080p", "url" to "$url?h=1080", "height" to 1080),
                mapOf("label" to "720p", "url" to "$url?h=720", "height" to 720),
            ),
        )
        put(
            "subtitles",
            listOf(mapOf("label" to "English", "url" to "https://s.example/e.vtt", "default" to true)),
        )
        put(
            "audioTracks",
            listOf(
                mapOf("label" to "English", "language" to "en", "default" to true),
                mapOf("label" to "Hindi", "language" to "hi"),
            ),
        )
        put("separateAudio", false)
        putAll(extra)
    }

    @Test
    fun parsesStreamWithAudioAndAvailabilityFields() {
        val parsed = parseStreams(listOf(streamMap()))
        assertEquals(1, parsed.size)
        val s = parsed[0]
        assertEquals("VidLink", s.server)
        assertEquals("https://site.example/", s.referer)
        assertEquals(2, s.qualities.size)
        assertEquals(1080, s.qualities[0].height)
        assertTrue(s.subtitles[0].isDefault)
        assertEquals(2, s.audioTracks.size)
        assertEquals("en", s.audioTracks[0].language)
        assertTrue(s.audioTracks[0].isDefault)
        assertFalse(s.separateAudio)
    }

    @Test
    fun failedRowsAreNeverPlayableButSurfaceAsFailedServers() {
        val raw = listOf(
            streamMap(url = "https://ok.example/x.m3u8", server = "Good"),
            streamMap(url = "", server = "Bad", extra = mapOf("available" to false, "error" to "timeout")),
        )

        val playable = parseStreams(raw)
        assertEquals(1, playable.size)
        assertEquals("Good", playable[0].server)

        val failed = parseFailedServers(raw)
        assertEquals(1, failed.size)
        assertEquals("Bad", failed[0].name)
        assertEquals("timeout", failed[0].error)
    }

    @Test
    fun duplicateUrlsCollapseToSingleRow() {
        val raw = listOf(streamMap(server = "A"), streamMap(server = "A"))
        // parseStreams maps rows as given; dedupe is resolveStreams' job, but
        // failed rows are explicitly distinctBy'd.
        assertEquals(2, parseStreams(raw).size)

        val failedRaw = listOf(
            mapOf("url" to "", "server" to "A", "available" to false, "error" to "x"),
            mapOf("url" to "", "server" to "A", "available" to false, "error" to "y"),
        )
        assertEquals(1, parseFailedServers(failedRaw).size)
    }

    @Test
    fun separateAudioFlagCarriesThrough() {
        val parsed = parseStreams(listOf(streamMap(extra = mapOf("separateAudio" to true))))
        assertTrue(parsed[0].separateAudio)
    }

    @Test
    fun garbageInputYieldsEmptyList() {
        assertTrue(parseStreams(null).isEmpty())
        assertTrue(parseStreams("nope").isEmpty())
        assertTrue(parseStreams(listOf(42, "x", null)).isEmpty())
        assertTrue(parseFailedServers(null).isEmpty())
    }

    @Test
    fun missingHeadersDefaultToEmptyMap() {
        val parsed = parseStreams(
            listOf(mapOf("url" to "https://c.example/v.mp4", "source" to "Filemoon")),
        )
        assertEquals("Filemoon", parsed[0].server) // falls back to `source`
        assertTrue(parsed[0].headers.isEmpty())
        assertTrue(parsed[0].audioTracks.isEmpty())
    }

    @Test
    fun audioTrackDisplayFormatsLanguage() {
        assertEquals(
            "English (en)",
            ResolvedAudioTrack("English", "en").display(),
        )
        assertEquals("Hindi", ResolvedAudioTrack("Hindi", "Hindi").display())
        assertEquals("Audio", ResolvedAudioTrack("Audio", "und").display())
    }
}
