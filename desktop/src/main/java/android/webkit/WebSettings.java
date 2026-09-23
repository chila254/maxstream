package android.webkit;

/** Constants for WebView.Settings#cacheMode used by the shared extractors. */
public final class WebSettings {
    public static final int LOAD_DEFAULT = -1;
    public static final int LOAD_NORMAL = 0;
    public static final int LOAD_CACHE_ELSE_NETWORK = 1;
    public static final int LOAD_NO_CACHE = 2;

    private WebSettings() {
    }
}