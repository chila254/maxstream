package com.maxstream.app.core

import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption

/**
 * Crash-safe text persistence: write to a sibling temp file, then atomically
 * move it over the target. A crash mid-write can no longer truncate/corrupt
 * the destination (the old direct `Files.writeString` could, and the loaders
 * treated parse failures as "start fresh", silently discarding user data).
 */
object AtomicFiles {

    fun write(target: Path, content: String) {
        val parent = target.parent
        if (parent != null) Files.createDirectories(parent)
        val tmp = target.resolveSibling(target.fileName.toString() + ".tmp")
        Files.writeString(tmp, content)
        try {
            Files.move(
                tmp,
                target,
                StandardCopyOption.REPLACE_EXISTING,
                StandardCopyOption.ATOMIC_MOVE,
            )
        } catch (_: AtomicMoveNotSupportedException) {
            // Filesystem without atomic moves — still safer than an in-place write.
            Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING)
        }
    }
}
