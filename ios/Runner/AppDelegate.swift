import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.maxstream/stream_extractor",
            binaryMessenger: controller.binaryMessenger
        )

        let streamExtractor = StreamExtractor()

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "extractStream":
                guard let args = call.arguments as? [String: Any],
                      let url = args["url"] as? String else {
                    result(FlutterError(
                        code: "INVALID_ARGS",
                        message: "URL cannot be null",
                        details: nil
                    ))
                    return
                }

                let timeout = args["timeout"] as? Int ?? 30

                DispatchQueue.global(qos: .userInitiated).async {
                    let extractResult = streamExtractor.extractStream(
                        embedUrl: url,
                        timeout: timeout
                    )
                    result(extractResult)
                }

            case "isAvailable":
                result(true)

            case "clearCache":
                do {
                    try streamExtractor.clearCache()
                    result(nil)
                } catch {
                    result(FlutterError(
                        code: "CACHE_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }

            case "dispose":
                do {
                    try streamExtractor.dispose()
                    result(nil)
                } catch {
                    result(FlutterError(
                        code: "DISPOSE_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

/**
 * Stream extraction using WKWebView
 * Extracts M3U8 URLs from embed pages by rendering and parsing JavaScript
 */
class StreamExtractor: NSObject, WKScriptMessageHandler {
    private var webView: WKWebView?
    private var extractionCallback: ((String) -> Void)?
    private let semaphore = DispatchSemaphore(value: 0)
    private var extractionResult: [String: Any?]?

    func extractStream(embedUrl: String, timeout: Int) -> [String: Any?] {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        DispatchQueue.main.async {
            self.createWebView()

            let request = URLRequest(url: URL(string: embedUrl)!)
            self.webView?.navigationDelegate = self
            self.webView?.load(request)

            // Timeout mechanism
            DispatchQueue.global().asyncAfter(deadline: .now() + TimeInterval(timeout)) {
                if self.extractionResult == nil {
                    self.extractionResult = [
                        "success": false,
                        "error": "Extraction timeout after \(timeout) seconds"
                    ]
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.wait()

        return extractionResult ?? [
            "success": false,
            "error": "Unknown error"
        ]
    }

    private func createWebView() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "StreamExtractor")

        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        config.preferences = preferences

        webView = WKWebView(frame: .zero, configuration: config)
        webView?.isOpaque = false
        webView?.backgroundColor = UIColor.clear
    }

    private func extractStreams() {
        guard let webView = webView else {
            extractionResult = ["success": false, "error": "WebView not initialized"]
            return
        }

        let extractionScript = """
            (function() {
                let streams = [];
                
                // Method 1: Look for M3U8 URLs in scripts
                const scripts = document.querySelectorAll('script');
                for (const script of scripts) {
                    const content = script.textContent || '';
                    const matches = content.match(/https?:\\/\\/[^\\s"']*\\.m3u8[^\\s"']*/g);
                    if (matches) {
                        streams.push(...matches);
                    }
                }
                
                // Method 2: Look for video/source tags
                const videos = document.querySelectorAll('video, source');
                for (const video of videos) {
                    const src = video.getAttribute('src');
                    if (src && (src.includes('.m3u8') || src.includes('stream'))) {
                        streams.push(src);
                    }
                }
                
                // Method 3: Look in iframes
                const iframes = document.querySelectorAll('iframe');
                for (const iframe of iframes) {
                    const src = iframe.getAttribute('src');
                    if (src && !src.startsWith('javascript:') && (src.includes('player') || src.includes('stream'))) {
                        streams.push(src);
                    }
                }
                
                // Method 4: Look for common player patterns
                const html = document.documentElement.outerHTML;
                const patterns = [
                    /file["\s]*:[\s]*["']([^"']*\\.m3u8[^"']*)["']/g,
                    /src["\s]*:[\s]*["']([^"']*\\.m3u8[^"']*)["']/g,
                    /stream["\s]*:[\s]*["']([^"']*\\.m3u8[^"']*)["']/g,
                    /manifest["\s]*:[\s]*["']([^"']*\\.m3u8[^"']*)["']/g,
                ];
                
                for (const pattern of patterns) {
                    let match;
                    while ((match = pattern.exec(html)) !== null) {
                        if (match[1]) {
                            streams.push(match[1]);
                        }
                    }
                }
                
                // Remove duplicates
                streams = [...new Set(streams)];
                
                // Filter valid URLs
                const validStreams = streams.filter(s => {
                    try {
                        new URL(s);
                        return true;
                    } catch {
                        return false;
                    }
                });
                
                // Return result
                if (validStreams.length > 0) {
                    return {
                        success: true,
                        streamUrl: validStreams[0],
                        source: 'native_ios_webview',
                        count: validStreams.length
                    };
                } else {
                    return {
                        success: false,
                        error: 'No M3U8 streams found in page'
                    };
                }
            })();
        """

        webView.evaluateJavaScript(extractionScript) { result, error in
            if let error = error {
                self.extractionResult = [
                    "success": false,
                    "error": "JavaScript evaluation failed: \(error.localizedDescription)"
                ]
                return
            }

            if let result = result as? [String: Any?] {
                self.extractionResult = result
            } else {
                self.extractionResult = [
                    "success": false,
                    "error": "Failed to parse JavaScript result"
                ]
            }
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Handle messages from JavaScript if needed
    }

    func clearCache() throws {
        let websiteDataTypes = NSSet(array: [
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache
        ])

        WKWebsiteDataStore.default().removeData(
            ofTypes: websiteDataTypes as! Set<String>,
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) {}
    }

    func dispose() throws {
        DispatchQueue.main.async {
            self.webView?.navigationDelegate = nil
            self.webView = nil
        }
    }
}

extension StreamExtractor: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        // Wait for JavaScript to execute
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.extractStreams()
        }
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        extractionResult = [
            "success": false,
            "error": "Failed to load page: \(error.localizedDescription)"
        ]
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        extractionResult = [
            "success": false,
            "error": "Failed to load page: \(error.localizedDescription)"
        ]
    }
}
