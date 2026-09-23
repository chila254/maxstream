package android.webkit;

/**
 * Desktop substitute for android.webkit.WebViewClient. Deliberately a Java type:
 * the shared Kotlin extractors override these methods with both nullable and
 * non-null parameter types, which is only legal against Java platform types.
 */
public class WebViewClient {

    public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
        return null;
    }

    public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
        return false;
    }

    @Deprecated
    public boolean shouldOverrideUrlLoading(WebView view, String url) {
        return false;
    }

    public void onPageStarted(WebView view, String url) {
    }

    public void onPageFinished(WebView view, String url) {
    }

    public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
    }
}