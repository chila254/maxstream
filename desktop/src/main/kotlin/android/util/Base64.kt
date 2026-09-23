package android.util

/**
 * Desktop substitute for android.util.Base64. Behavior mirrors Android's
 * streaming-free convenience API: whitespace/newlines are always tolerated on
 * decode, missing padding is filled, and URL_SAFE/NO_WRAP/NO_PADDING flags are
 * honoured for both encoders and decoders.
 */
object Base64 {
    const val DEFAULT = 0
    const val NO_PADDING = 1
    const val NO_WRAP = 2
    const val CRLF = 4
    const val URL_SAFE = 8
    const val NO_CLOSE = 16

    fun encodeToString(input: ByteArray, flags: Int): String {
        val urlSafe = flags and URL_SAFE != 0
        val encoder = if (urlSafe) java.util.Base64.getUrlEncoder() else java.util.Base64.getEncoder()
        var out = encoder.encodeToString(input)
        if (flags and NO_PADDING != 0) out = out.trimEnd('=')
        if (flags and NO_WRAP != 0) out = out.replace("\r", "").replace("\n", "")
        return out
    }

    fun decode(str: String, flags: Int): ByteArray {
        val cleaned = buildString(str.length) {
            str.forEach { c -> if (!c.isWhitespace()) append(c) }
        }
        var normalized = cleaned.replace('-', '+').replace('_', '/')
        while (normalized.length % 4 != 0) normalized += "="
        val decoder = java.util.Base64.getDecoder()
        return try {
            decoder.decode(normalized)
        } catch (e: IllegalArgumentException) {
            // Android is lenient about the trailing padding; retry strictly.
            val unpadded = normalized.trimEnd('=')
            decoder.decode(unpadded)
        }
    }

    fun decode(bytes: ByteArray, flags: Int): ByteArray =
        decode(String(bytes, Charsets.UTF_8), flags)
}