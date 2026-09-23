package android.text

/**
 * Desktop substitute for android.text.Html.fromHtml. Only the subset the shared
 * extractors rely on is implemented: tag stripping, <br/> handling and HTML
 * entity decoding (numeric + the common named ones).
 */
object Html {
    const val FROM_HTML_MODE_LEGACY = 0

    private val SCRIPT_STYLE = Regex(
        "<(script|style|noscript)[^>]*>.*?</\\1>",
        setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
    )
    private val BLOCK_END = Regex("<br\\s*/?>", RegexOption.IGNORE_CASE)
    private val TAG = Regex("<[^>]+>")
    private val NUMERIC_ENTITY = Regex("&#(\\d+);")

    fun fromHtml(source: String, flags: Int = 0): CharSequence {
        if (source.isEmpty()) return ""
        var s = source
        s = s.replace(SCRIPT_STYLE, "")
        s = s.replace(BLOCK_END, "\n")
        s = s.replace(TAG, "")
        s = s.replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&#39;", "'")
            .replace("&apos;", "'")
            .replace("&nbsp;", " ")
            .replace("&hellip;", "\u2026")
        s = s.replace(NUMERIC_ENTITY) { m ->
            m.groupValues[1].toIntOrNull()?.toChar()?.toString() ?: m.value
        }
        return s
    }
}