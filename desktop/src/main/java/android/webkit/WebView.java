package android.webkit;

import android.content.Context;
import java.awt.EventQueue;

/**
 * Desktop substitute for android.webkit.WebView.
 *
 * There is no embedded browser engine on the desktop JVM, so this class is a
 * structural stand-in that lets the shared TV extractors compile and run.
 * Since the desktop ActivityManager shim reports a low-RAM device, the extractor
 * skips WebView paths before they render (exactly like cheap TV boxes); this
 * stand-in only surfaces onPageFinished so any configured fallback resumes
 * instead of hanging until timeout.
 */
public class WebView {

    public static class Settings {
        public boolean javaScriptEnabled;
        public boolean blockNetworkImage;
        public int cacheMode;
        public boolean domStorageEnabled;
        public boolean loadsImagesAutomatically;
        public boolean mediaPlaybackRequiresUserGesture;
        public String userAgentString;

        public Settings() {
            this.javaScriptEnabled = false;
            this.blockNetworkImage = false;
            this.cacheMode = WebSettings.LOAD_DEFAULT;
            this.domStorageEnabled = false;
            this.loadsImagesAutomatically = true;
            this.mediaPlaybackRequiresUserGesture = true;
            this.userAgentString =
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                            + "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";
        }
    }

    private final Settings mSettings = new Settings();
    private WebViewClient mWebViewClient = new WebViewClient();
    private String mLastUrl = "";

    public WebView(Context context) {
    }

    public Settings getSettings() {
        return mSettings;
    }

    public WebViewClient getWebViewClient() {
        return mWebViewClient;
    }

    public void setWebViewClient(WebViewClient client) {
        mWebViewClient = client;
    }

    public void addJavascriptInterface(Object object, String name) {
    }

    public void loadUrl(String url) {
        mLastUrl = url;
        // Desktop has no JS engine; surface page-finish so extractors that wait
        // on it resume cleanly (with whatever they captured, usually null).
        EventQueue.invokeLater(
                new Runnable() {
                    @Override
                    public void run() {
                        getWebViewClient().onPageFinished(WebView.this, mLastUrl);
                    }
                });
    }

    public String getUrl() {
        return mLastUrl;
    }

    public void stopLoading() {
    }

    public void destroy() {
    }

    public void post(Runnable action) {
        EventQueue.invokeLater(action);
    }

    public void evaluateJavascript(String script, Object resultCallback) {
    }
}