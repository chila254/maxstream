package android.webkit;

import java.util.HashMap;
import java.util.Map;

/**
 * Desktop substitute for android.webkit.CookieManager. Teeny in-memory jar used
 * by extractors that want the page's cookies attached to media requests.
 */
public class CookieManager {
    private static final CookieManager SINGLETON = new CookieManager();

    private final Map<String, String> cookies = new HashMap<String, String>();

    public static CookieManager getInstance() {
        return SINGLETON;
    }

    public void setCookie(String url, String value) {
        cookies.put(url, value);
    }

    public String getCookie(String url) {
        return cookies.get(url);
    }

    public void setAcceptCookie(boolean accept) {
    }

    public boolean acceptCookie() {
        return true;
    }

    public void setAcceptThirdPartyCookies(WebView webView, boolean accept) {
    }

    public void flush() {
    }
}