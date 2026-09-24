package com.maxstream.app.player

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/**
 * Extracts the VLC runtime bundled inside the application JAR to a writable
 * location on first launch, then points JNA / vlcj at it so the app plays video
 * without a separate VLC install.
 *
 * The bundle lives under `src/main/resources/vlc` (populated at build time by the
 * `:desktop:syncVlcRuntime` Gradle task) and is listed in `vlc/FILES.txt`.
 */
object VlcRuntime {
    private const val RESOURCE_ROOT = "vlc"
    private const val DIR_PROP = "maxstream.vlc.dir"

    /** Directory the bundled libvlc was extracted to, if present. */
    val bundledDir: File?
        get() = System.getProperty(DIR_PROP)
            ?.let { File(it) }
            ?.takeIf { File(it, "libvlc.dll").exists() }

    /**
     * Extracts the bundled runtime (if needed) and configures the process to use
     * it. Safe to call more than once and safe to call when nothing is bundled.
     */
    fun ensure() {
        if (bundledDir != null) return

        val base = System.getenv("LOCALAPPDATA") ?: System.getProperty("user.home")
        val target = File(base, "MaxStream${File.separator}vlc")

        val version = readResource("$RESOURCE_ROOT/VERSION.txt")?.trim() ?: "missing"
        val marker = File(target, "VERSION.txt")
        val installed = if (marker.exists()) marker.readText().trim() else ""

        // Re-extract when nothing is there or the bundled version changed.
        if (version != "missing" &&
            (!File(target, "libvlc.dll").exists() || installed != version)
        ) {
            extract(target, version, marker)
        }

        if (File(target, "libvlc.dll").exists()) {
            System.setProperty(DIR_PROP, target.absolutePath)
            // Make libvlc/libvlccore loadable by JNA regardless of discovery.
            val existing = System.getProperty("jna.library.path")
            System.setProperty(
                "jna.library.path",
                if (existing.isNullOrBlank()) target.absolutePath
                else target.absolutePath + File.pathSeparator + existing,
            )
        }
    }

    private fun extract(target: File, version: String, marker: File) {
        val list = readResource("$RESOURCE_ROOT/FILES.txt") ?: return
        val loader = javaClass.classLoader
        for (line in list.lineSequence()) {
            val rel = line.trim().replace('\\', '/')
            if (rel.isEmpty()) continue
            val dest = File(target, rel)
            dest.parentFile?.mkdirs()
            val input = loader.getResourceAsStream("$RESOURCE_ROOT/$rel") ?: continue
            input.use { stream ->
                Files.copy(stream, dest.toPath(), StandardCopyOption.REPLACE_EXISTING)
            }
        }
        marker.parentFile?.mkdirs()
        marker.writeText(version)
    }

    private fun readResource(name: String): String? =
        javaClass.classLoader.getResourceAsStream(name)
            ?.use { it.readBytes().decodeToString() }
}
