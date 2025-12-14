import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

/// Represents a resolved streaming URL ready for playback
class ResolvedStream {
  final String url;
  final String quality;
  final String source;
  final String type; // 'hls' or 'mp4'
  final Map<String, String>? headers;
  final bool isPlayable;

  ResolvedStream({
    required this.url,
    required this.quality,
    required this.source,
    required this.type,
    this.headers,
    this.isPlayable = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'quality': quality,
      'source': source,
      'type': type,
      'headers': headers,
      'isPlayable': isPlayable,
    };
  }
}

/// Stream Resolver Service
/// Resolves embed URLs to playable streaming URLs using WebView
class StreamResolverService {
  static const String _tag = 'StreamResolverService';

  static WebViewController? _webViewController;
  static Completer<String?>? _urlCompleter;
  static bool _isInitialized = false;

  /// Initialize the WebView controller
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('$_tag: Initializing WebView');

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              debugPrint('$_tag: Page HTML loaded: $url');
              debugPrint('$_tag: Waiting for JavaScript content to load...');
              // Wait a bit for JavaScript to initialize, then extract
              Future.delayed(const Duration(milliseconds: 500), () {
                _extractStreamFromPage();
              });
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('$_tag: 🔴 WebView error: ${error.description}');
              _urlCompleter?.completeError(error.description);
            },
          ),
        )
        ..addJavaScriptChannel(
          'StreamExtractor',
          onMessageReceived: (JavaScriptMessage message) {
            final msgPreview = message.message.length > 100 ? message.message.substring(0, 100) : message.message;
            debugPrint('$_tag: 📨 JavaScript message received: $msgPreview');
            if (message.message.isNotEmpty && !_urlCompleter!.isCompleted) {
              _urlCompleter?.complete(message.message);
            }
          },
        );

      _isInitialized = true;
      debugPrint('$_tag: ✓ WebView initialized successfully');
    } catch (e) {
      debugPrint('$_tag: ❌ Error initializing WebView: $e');
      rethrow;
    }
  }

  /// Resolve an embed URL to a playable stream URL
  ///
  /// [embedUrl] - The embed URL from a streaming provider
  /// [source] - Name of the source (VidSrc, VidSrc Pro, etc.)
  /// [quality] - Quality label
  /// [timeout] - Maximum time to wait for resolution (default 15 seconds)
  ///
  /// Returns ResolvedStream if successful, null if timeout or error
  static Future<ResolvedStream?> resolveStream(
    String embedUrl, {
    required String source,
    required String quality,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      debugPrint('$_tag: ═══════════════════════════════════════════');
      debugPrint('$_tag: Starting stream resolution');
      debugPrint('$_tag: Source: $source');
      debugPrint('$_tag: Quality: $quality');
      debugPrint('$_tag: Embed URL: $embedUrl');
      debugPrint('$_tag: Timeout: ${timeout.inSeconds}s');
      debugPrint('$_tag: ═══════════════════════════════════════════');

      // Initialize if not already done
      if (!_isInitialized) {
        debugPrint('$_tag: WebView not initialized, initializing...');
        await initialize();
      }

      if (_webViewController == null) {
        throw Exception('WebView controller not initialized');
      }

      // Create completer for stream URL extraction
      _urlCompleter = Completer<String?>();

      // Load the embed URL
      debugPrint('$_tag: Loading embed URL in WebView...');
      await _webViewController!.loadRequest(Uri.parse(embedUrl));

      // Wait for stream URL with timeout
      debugPrint(
        '$_tag: Waiting for stream extraction (max ${timeout.inSeconds}s)...',
      );
      final streamUrl = await _urlCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint(
            '$_tag: ⚠️  Stream resolution TIMEOUT for $source after ${timeout.inSeconds}s',
          );
          return null;
        },
      );

      _urlCompleter = null;

      if (streamUrl == null || streamUrl.isEmpty) {
        debugPrint('$_tag: ❌ No stream URL extracted from $source');
        return null;
      }

      debugPrint('$_tag: ✓ Stream URL successfully extracted');
      debugPrint('$_tag: Stream URL: $streamUrl');

      // Determine stream type
      final type = _detectStreamType(streamUrl);
      debugPrint('$_tag: Detected stream type: $type');

      debugPrint('$_tag: ✓ Stream resolved from $source ($quality)');

      return ResolvedStream(
        url: streamUrl,
        quality: quality,
        source: source,
        type: type,
        headers: _getHeadersForSource(source),
        isPlayable: true,
      );
    } catch (e) {
      debugPrint('$_tag: ❌ ERROR: $e');
      return null;
    }
  }

  /// Extract stream URL from the loaded page
  static Future<void> _extractStreamFromPage() async {
    if (_webViewController == null) return;

    try {
      // JavaScript injection to extract stream URLs from providers like VidSrc.to
      // VidSrc.to loads streams dynamically via JavaScript
      const String extractionScript = '''
        (function() {
          let streamUrl = null;
          let attempts = 0;
          const maxAttempts = 8;
          let debugMessages = [];
          
          function sendStreamUrl(url) {
            if (url && url.trim()) {
              console.log('Stream URL found: ' + url);
              StreamExtractor.postMessage(url);
            }
          }
          
          function extractStream() {
            attempts++;
            console.log('Extraction attempt ' + attempts + '/' + maxAttempts);
            
            // VIDSRC.TO SPECIFIC: Check for player initialization
            try {
              if (window.player && window.player.source) {
                console.log('Found window.player.source (VidSrc pattern)');
                streamUrl = window.player.source;
                return true;
              }
              if (window.__player && window.__player.src) {
                console.log('Found window.__player.src (VidSrc pattern)');
                streamUrl = window.__player.src;
                return true;
              }
              if (window.source && window.source.src) {
                console.log('Found window.source.src (VidSrc pattern)');
                streamUrl = window.source.src;
                return true;
              }
            } catch (e) {
              console.log('Error checking VidSrc patterns: ' + e);
            }
            
            // 1. Try to find HLS/DASH manifests in script tags
            const scripts = document.querySelectorAll('script');
            for (let script of scripts) {
              const text = script.textContent || '';
              
              // Look for m3u8 URLs
              const m3u8Match = text.match(/https?:\\/\\/[^\\s"'<>]+\\.m3u8[^\\s"'<>]*/i);
              if (m3u8Match) {
                console.log('Found m3u8 in script: ' + m3u8Match[0]);
                streamUrl = m3u8Match[0];
                return true;
              }
              
              // Look for mpd URLs
              const mpdMatch = text.match(/https?:\\/\\/[^\\s"'<>]+\\.mpd[^\\s"'<>]*/i);
              if (mpdMatch) {
                console.log('Found mpd in script: ' + mpdMatch[0]);
                streamUrl = mpdMatch[0];
                return true;
              }
              
              // Look for blob URLs
              const blobMatch = text.match(/blob:[^\\s"'<>]+/i);
              if (blobMatch) {
                console.log('Found blob URL in script: ' + blobMatch[0]);
                streamUrl = blobMatch[0];
                return true;
              }
            }
            
            // 2. Try to find in video/audio tags
            const videoElements = document.querySelectorAll('video, audio');
            for (let video of videoElements) {
              // Check src attribute
              if (video.src && video.src.trim()) {
                console.log('Found src in video tag: ' + video.src);
                streamUrl = video.src;
                return true;
              }
              
              // Check source children
              const sources = video.querySelectorAll('source');
              for (let source of sources) {
                const src = source.src || source.getAttribute('src') || source.getAttribute('data-src');
                if (src && src.trim()) {
                  console.log('Found source tag: ' + src);
                  streamUrl = src;
                  return true;
                }
              }
            }
            
            // 3. Try data attributes commonly used by player libraries
            const mediaContainers = document.querySelectorAll('[data-src], [data-url], [data-file]');
            for (let container of mediaContainers) {
              let url = container.getAttribute('data-src') || 
                       container.getAttribute('data-url') || 
                       container.getAttribute('data-file');
              if (url && (url.includes('.m3u8') || url.includes('.mp4') || url.includes('.mpd') || url.includes('blob:'))) {
                console.log('Found in data attribute: ' + url);
                streamUrl = url;
                return true;
              }
            }
            
            // 4. Try to find in window/global objects (common in JS players)
            try {
              if (window.config && window.config.url) {
                console.log('Found in window.config.url: ' + window.config.url);
                streamUrl = window.config.url;
                return true;
              }
              if (window.playerConfig && window.playerConfig.src) {
                console.log('Found in window.playerConfig.src: ' + window.playerConfig.src);
                streamUrl = window.playerConfig.src;
                return true;
              }
              if (window.player && window.player.config && window.player.config.sources && window.player.config.sources[0]) {
                console.log('Found in window.player.config.sources: ' + window.player.config.sources[0].src);
                streamUrl = window.player.config.sources[0].src;
                return true;
              }
            } catch (e) {
              console.log('Error accessing window objects: ' + e);
            }
            
            // 5. Try common player library patterns
            try {
              // Plyr player
              if (window.plyr && window.plyr.media) {
                const src = window.plyr.media.src || window.plyr.media.currentSrc;
                if (src) {
                  console.log('Found in Plyr: ' + src);
                  streamUrl = src;
                  return true;
                }
              }
              
              // HLS.js
              if (window.hlsPlayer && window.hlsPlayer.media && window.hlsPlayer.media.src) {
                console.log('Found in HLS.js: ' + window.hlsPlayer.media.src);
                streamUrl = window.hlsPlayer.media.src;
                return true;
              }
              
              // Shaka Player
              if (window.player && window.player.getAssetUri) {
                const uri = window.player.getAssetUri();
                if (uri) {
                  console.log('Found in Shaka: ' + uri);
                  streamUrl = uri;
                  return true;
                }
              }
            } catch (e) {
              console.log('Error checking player libraries: ' + e);
            }
            
            // 6. Try iframe sources
            const iframes = document.querySelectorAll('iframe');
            for (let iframe of iframes) {
              const src = iframe.src;
              if (src && src.includes('stream')) {
                console.log('Found iframe with stream: ' + src);
                streamUrl = src;
                return true;
              }
            }
            
            // 7. Look for links with streaming extensions
            const links = document.querySelectorAll('a[href*=".m3u8"], a[href*=".mp4"], a[href*=".mpd"]');
            for (let link of links) {
              const href = link.getAttribute('href');
              if (href && href.trim()) {
                console.log('Found link: ' + href);
                streamUrl = href;
                return true;
              }
            }
            
            // 8. Final check: look in all attributes for URLs
            const allElements = document.querySelectorAll('*');
            for (let i = 0; i < Math.min(allElements.length, 100); i++) {
              const elem = allElements[i];
              const attrs = elem.attributes;
              for (let attr of attrs) {
                if (attr.value && (attr.value.includes('.m3u8') || attr.value.includes('.mp4') || attr.value.includes('.mpd'))) {
                  if (attr.value.startsWith('http') || attr.value.startsWith('blob:')) {
                    console.log('Found in attribute ' + attr.name + ': ' + attr.value);
                    streamUrl = attr.value;
                    return true;
                  }
                }
              }
            }
            
            return false;
          }
          
          // Initial attempt
          if (extractStream()) {
            sendStreamUrl(streamUrl);
          } else if (attempts < maxAttempts) {
            // Retry after delay for dynamic content
            const delayMs = attempts < 3 ? 500 : 1000;
            console.log('Retrying in ' + delayMs + 'ms...');
            setTimeout(extractStream, delayMs);
          } else {
            console.log('Failed to extract stream after ' + maxAttempts + ' attempts');
            
            // Last resort: Log page structure for debugging
            console.log('Page title: ' + document.title);
            console.log('Page domain: ' + window.location.hostname);
            console.log('Number of scripts: ' + document.querySelectorAll('script').length);
            console.log('Number of iframes: ' + document.querySelectorAll('iframe').length);
            
            // Try one more time with a different strategy
            const allText = document.body.innerText || '';
            if (allText.includes('stream') || allText.includes('video')) {
              console.log('Page contains stream-related text');
            }
            
            StreamExtractor.postMessage('');
          }
        })();
      ''';

      await _webViewController!.runJavaScript(extractionScript);
    } catch (e) {
      debugPrint('$_tag: Error extracting stream from page: $e');
    }
  }

  /// Detect stream type based on URL
  static String _detectStreamType(String url) {
    if (url.contains('.m3u8') || url.contains('master.m3u8')) {
      return 'hls';
    } else if (url.contains('.mpd')) {
      return 'dash';
    } else if (url.contains('.mp4')) {
      return 'mp4';
    } else if (url.contains('stream') || url.contains('video')) {
      return 'http';
    }
    return 'http'; // Default
  }

  /// Get appropriate headers for source
  static Map<String, String>? _getHeadersForSource(String source) {
    final sourceUri = source.toLowerCase();

    if (sourceUri.contains('vidsrc')) {
      return {
        'Referer': 'https://vidsrc.to',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (sourceUri.contains('flixhq')) {
      return {
        'Referer': 'https://flixhq.to',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (sourceUri.contains('hdtoday')) {
      return {
        'Referer': 'https://hdtodayz.to',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    }

    // Default headers
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };
  }

  /// Resolve multiple embed sources and return first successful
  ///
  /// Tries each source in order, returns first successful resolution
  static Future<ResolvedStream?> resolveBestSource(
    List<({String url, String source, String quality})> sources,
  ) async {
    for (final source in sources) {
      debugPrint(
        '$_tag: Attempting to resolve ${source.source} - ${source.quality}',
      );

      final resolved = await resolveStream(
        source.url,
        source: source.source,
        quality: source.quality,
      );

      if (resolved != null && resolved.isPlayable) {
        debugPrint('$_tag: ✓ Successfully resolved from ${source.source}');
        return resolved;
      }

      debugPrint(
        '$_tag: Failed to resolve from ${source.source}, trying next...',
      );
    }

    debugPrint('$_tag: ✗ Failed to resolve any source');
    return null;
  }

  /// Clear WebView cache
  static Future<void> clearCache() async {
    try {
      if (_webViewController != null) {
        debugPrint('$_tag: Clearing WebView cache');
        // Cache is automatically managed by WebView
      }
    } catch (e) {
      debugPrint('$_tag: Error clearing cache: $e');
    }
  }

  /// Dispose WebView resources
  static Future<void> dispose() async {
    try {
      debugPrint('$_tag: Disposing WebView');
      _webViewController = null;
      _urlCompleter = null;
      _isInitialized = false;
      debugPrint('$_tag: WebView disposed');
    } catch (e) {
      debugPrint('$_tag: Error disposing WebView: $e');
    }
  }
}
