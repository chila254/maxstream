package android.content;

/**
 * Desktop substitute for android.content.Context. Only getSystemService matters
 * to the shared extractors; on the JVM it hands back a low-RAM ActivityManager
 * so WebView-based extractors are skipped (no embedded browser engine).
 */
public interface Context {
    String ACTIVITY_SERVICE = "activity";
    String WINDOW_SERVICE = "window";
    String CONNECTIVITY_SERVICE = "connectivity";
    String PACKAGE_SERVICE = "package";

    default Object getSystemService(String name) {
        if (ACTIVITY_SERVICE.equals(name)) {
            return new android.app.ActivityManager();
        }
        return null;
    }

    default String getPackageName() {
        return "com.maxstream.app.desktop";
    }
}