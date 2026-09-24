package com.maxstream.app.player

import uk.co.caprica.vlcj.factory.discovery.provider.DiscoveryDirectoryProvider
import java.io.File

/**
 * Points vlcj at the VLC runtime bundled with the app.
 *
 * vlcj sorts directory providers by [priority] ascending (lowest first), so
 * returning -100 makes this the first candidate — the bundled runtime always
 * wins over an installed VLC.
 *
 * Registered via META-INF/services (see resources/META-INF/services/...). The
 * path is supplied by [VlcRuntime.ensure], which must run before the player is
 * created.
 */
class BundledVlcDirectoryProvider : DiscoveryDirectoryProvider {
    override fun priority(): Int = -100

    override fun directories(): Array<String> {
        val dir = bundledPath() ?: return arrayOf()
        return arrayOf(dir)
    }

    override fun supported(): Boolean {
        val dir = bundledPath() ?: return false
        return File(dir, "libvlc.dll").exists()
    }

    private fun bundledPath(): String? =
        System.getProperty("maxstream.vlc.dir")?.takeIf { it.isNotBlank() }
}
