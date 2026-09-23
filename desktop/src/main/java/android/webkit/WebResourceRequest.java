package android.webkit;

import java.net.URI;
import java.util.Collections;
import java.util.Map;

/**
 * Desktop substitute for android.webkit.WebResourceRequest. The shared
 * extractors only ever read getUrl(); desktop never produces real requests.
 */
public interface WebResourceRequest {
    URI getUrl();

    default boolean isForMainFrame() {
        return true;
    }

    default boolean isRedirect() {
        return false;
    }

    default boolean hasGesture() {
        return false;
    }

    default String getMethod() {
        return "GET";
    }

    default Map<String, String> getRequestHeaders() {
        return Collections.emptyMap();
    }
}