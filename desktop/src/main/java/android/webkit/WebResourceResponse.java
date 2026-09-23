package android.webkit;

import java.io.InputStream;
import java.util.Collections;
import java.util.Map;

/** Desktop substitute for android.webkit.WebResourceResponse. */
public class WebResourceResponse {
    private final String mMimeType;
    private final String mEncoding;
    private final InputStream mData;
    private int mStatusCode;
    private String mReasonPhrase;
    private Map<String, String> mResponseHeaders;

    public WebResourceResponse(String mimeType, String encoding, InputStream data) {
        this.mMimeType = mimeType;
        this.mEncoding = encoding;
        this.mData = data;
        this.mReasonPhrase = "OK";
        this.mResponseHeaders = Collections.emptyMap();
    }

    public WebResourceResponse(
            String mimeType,
            String encoding,
            int statusCode,
            String reasonPhrase,
            Map<String, String> responseHeaders,
            InputStream data) {
        this(mimeType, encoding, data);
        this.mStatusCode = statusCode;
        this.mReasonPhrase = reasonPhrase;
        this.mResponseHeaders = responseHeaders;
    }

    public InputStream getData() {
        return mData;
    }

    public int getStatusCode() {
        return mStatusCode;
    }

    public String getReasonPhrase() {
        return mReasonPhrase;
    }

    public Map<String, String> getResponseHeaders() {
        return mResponseHeaders;
    }
}