package android.util

/**
 * Desktop substitute for android.util.Log. The shared TV extractors log through
 * this object so the JVM port keeps the same call sites; output goes to stderr.
 */
object Log {
    private fun prefix(tag: String) = "[$tag] "

    fun v(tag: String, msg: String) = trace(tag, msg)
    fun v(tag: String, msg: String, tr: Throwable) = trace(tag, msg, tr)

    fun d(tag: String, msg: String) = trace(tag, msg)
    fun d(tag: String, msg: String, tr: Throwable) = trace(tag, msg, tr)

    fun i(tag: String, msg: String) = trace(tag, msg)
    fun i(tag: String, msg: String, tr: Throwable) = trace(tag, msg, tr)

    fun w(tag: String, msg: String) {
        System.err.println(prefix(tag) + msg)
    }

    fun w(tag: String, msg: String, tr: Throwable) {
        System.err.println(prefix(tag) + msg + "\n" + tr)
    }

    fun w(tag: String, tr: Throwable) {
        System.err.println(prefix(tag) + tr)
    }

    fun e(tag: String, msg: String) {
        System.err.println(prefix(tag) + msg)
    }

    fun e(tag: String, msg: String, tr: Throwable) {
        System.err.println(prefix(tag) + msg + "\n" + tr)
    }

    fun e(tag: String, tr: Throwable) {
        System.err.println(prefix(tag) + tr)
    }

    fun wtf(tag: String, msg: String) = e(tag, msg)
    fun wtf(tag: String, msg: String, tr: Throwable) = e(tag, msg, tr)

    private fun trace(tag: String, msg: String, tr: Throwable? = null) {
        if (tr == null) {
            System.err.println(prefix(tag) + msg)
        } else {
            System.err.println(prefix(tag) + msg + "\n" + tr)
        }
    }
}