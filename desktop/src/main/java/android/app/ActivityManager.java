package android.app;

/**
 * Desktop substitute for android.app.ActivityManager. Reports a low-RAM device
 * so the shared extractor bails before constructing a WebView — mirroring the
 * guard already in place for cheap TV boxes.
 */
public class ActivityManager {

    /** Desktop has no JS engine — treat every check as "low RAM". */
    public boolean isLowRamDevice() {
        return true;
    }

    public long getMemoryClass() {
        return 128;
    }

    public static class MemoryInfo {
        public long totalMem;
        public long availMem;
        public long threshold;
        public boolean isLowMemory;

        public MemoryInfo() {
            this.totalMem = 8L * 1024 * 1024 * 1024;
            this.availMem = 6L * 1024 * 1024 * 1024;
        }
    }

    public void getMemoryInfo(MemoryInfo outInfo) {
        outInfo.totalMem = this.memoryInfoTotal;
        outInfo.availMem = this.memoryInfoAvail;
    }

    private long memoryInfoTotal = 8L * 1024 * 1024 * 1024;
    private long memoryInfoAvail = 6L * 1024 * 1024 * 1024;
}