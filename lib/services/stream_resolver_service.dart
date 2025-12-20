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
              // Wait for JavaScript to initialize, then extract
              // Different delay based on domain to allow for dynamic content
              final delay = url.contains('vidsrc')
                  ? const Duration(milliseconds: 800)
                  : const Duration(milliseconds: 500);
              Future.delayed(delay, () {
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
            final msgPreview = message.message.length > 100
                ? message.message.substring(0, 100)
                : message.message;
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
  /// [timeout] - Maximum time to wait for resolution (default 25 seconds)
  ///
  /// Returns ResolvedStream if successful, null if timeout or error
  static Future<ResolvedStream?> resolveStream(
    String embedUrl, {
    required String source,
    required String quality,
    Duration timeout = const Duration(seconds: 25),
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
      // JavaScript injection to extract stream URLs from providers like VidSrc.me
      // Uses multiple strategies for different provider implementations
      const String extractionScript = '''
        (function() {
          let streamUrl = null;
          let attempts = 0;
          const maxAttempts = 15;
          
          function sendStreamUrl(url) {
            if (url && url.trim() && url.length > 5) {
              console.log('Stream URL found: ' + url);
              StreamExtractor.postMessage(url);
            }
          }
          
          function extractStream() {
            attempts++;
            console.log('Extraction attempt ' + attempts + '/' + maxAttempts);
            
            // VIDSRC.ME SPECIFIC: Check for player initialization in main window
            try {
              // Strategy 1: VidSrc player object
              if (window.player && window.player.source) {
                console.log('Found window.player.source');
                streamUrl = window.player.source;
                if (streamUrl) return true;
              }
              if (window.__player && window.__player.src) {
                console.log('Found window.__player.src');
                streamUrl = window.__player.src;
                if (streamUrl) return true;
              }
              if (window.source && window.source.src) {
                console.log('Found window.source.src');
                streamUrl = window.source.src;
                if (streamUrl) return true;
              }
            } catch (e) {
              console.log('Error checking window objects: ' + e);
            }
            
            // Strategy 2: Check for nested iframes in sandbox
            try {
              const iframes = document.querySelectorAll('iframe');
              for (let iframe of iframes) {
                try {
                  if (iframe.contentWindow && iframe.contentWindow.player) {
                    if (iframe.contentWindow.player.source) {
                      console.log('Found iframe player.source');
                      streamUrl = iframe.contentWindow.player.source;
                      if (streamUrl) return true;
                    }
                  }
                } catch (e) {
                  console.log('Cannot access iframe: ' + e.message);
                }
              }
            } catch (e) {
              console.log('Error checking iframes: ' + e);
            }
            
            // Strategy 3: Look for HLS/DASH manifests in script tags
            try {
              const scripts = document.querySelectorAll('script');
              for (let script of scripts) {
                const text = script.textContent || '';
                
                // Look for m3u8 URLs (HLS)
                const m3u8Matches = text.match(/https?:\\/\\/[^\\s"'<>]+\\.m3u8[^\\s"'<>]*/gi);
                if (m3u8Matches && m3u8Matches.length > 0) {
                  for (let match of m3u8Matches) {
                    if (!match.includes('player') && !match.includes('js')) {
                      console.log('Found m3u8 URL: ' + match);
                      streamUrl = match;
                      return true;
                    }
                  }
                }
                
                // Look for mp4 URLs
                const mp4Matches = text.match(/https?:\\/\\/[^\\s"'<>]+\\.mp4[^\\s"'<>]*/gi);
                if (mp4Matches && mp4Matches.length > 0) {
                  console.log('Found mp4 URL: ' + mp4Matches[0]);
                  streamUrl = mp4Matches[0];
                  return true;
                }
                
                // Look for mpd URLs (DASH)
                const mpdMatches = text.match(/https?:\\/\\/[^\\s"'<>]+\\.mpd[^\\s"'<>]*/gi);
                if (mpdMatches && mpdMatches.length > 0) {
                  console.log('Found mpd URL: ' + mpdMatches[0]);
                  streamUrl = mpdMatches[0];
                  return true;
                }
              }
            } catch (e) {
              console.log('Error checking scripts: ' + e);
            }
            
            // Strategy 4: Look in video/audio tags
            try {
              const mediaElements = document.querySelectorAll('video, audio');
              for (let media of mediaElements) {
                // Check src attribute
                if (media.src && media.src.trim() && media.src.startsWith('http')) {
                  console.log('Found media src: ' + media.src);
                  streamUrl = media.src;
                  return true;
                }
                
                // Check source children
                const sources = media.querySelectorAll('source');
                for (let source of sources) {
                  const src = source.src || source.getAttribute('src') || source.getAttribute('data-src');
                  if (src && src.trim() && (src.startsWith('http') || src.startsWith('blob:'))) {
                    console.log('Found source tag: ' + src);
                    streamUrl = src;
                    return true;
                  }
                }
              }
            } catch (e) {
              console.log('Error checking media elements: ' + e);
            }
            
            // Strategy 5: Data attributes in containers
            try {
              const mediaContainers = document.querySelectorAll('[data-src], [data-url], [data-file], [data-media]');
              for (let container of mediaContainers) {
                let url = container.getAttribute('data-src') || 
                         container.getAttribute('data-url') || 
                         container.getAttribute('data-file') ||
                         container.getAttribute('data-media');
                if (url && url.trim() && (url.startsWith('http') || url.startsWith('blob:'))) {
                  if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('.mpd') || url.length > 20) {
                    console.log('Found in data attribute: ' + url.substring(0, 100));
                    streamUrl = url;
                    return true;
                  }
                }
              }
            } catch (e) {
              console.log('Error checking data attributes: ' + e);
            }
            
            // Strategy 6: Window/global config objects
            try {
              for (let key in window) {
                try {
                  const obj = window[key];
                  if (obj && typeof obj === 'object') {
                    // Check common property names
                    if (obj.url && typeof obj.url === 'string' && obj.url.startsWith('http')) {
                      console.log('Found window.' + key + '.url');
                      streamUrl = obj.url;
                      return true;
                    }
                    if (obj.src && typeof obj.src === 'string' && obj.src.startsWith('http')) {
                      console.log('Found window.' + key + '.src');
                      streamUrl = obj.src;
                      return true;
                    }
                    if (obj.source && typeof obj.source === 'string' && obj.source.startsWith('http')) {
                      console.log('Found window.' + key + '.source');
                      streamUrl = obj.source;
                      return true;
                    }
                  }
                } catch (e) {}
              }
            } catch (e) {
              console.log('Error searching window object: ' + e);
            }
            
            // Strategy 7: Common player library patterns
            try {
              const players = [
                { name: 'hlsPlayer', path: 'media.src' },
                { name: 'dashPlayer', path: 'media.src' },
                { name: 'videoPlayer', path: 'src' },
                { name: 'player', path: 'getAssetUri' },
              ];
              
              for (let p of players) {
                try {
                  const player = window[p.name];
                  if (player) {
                    if (typeof player.getAssetUri === 'function') {
                      const uri = player.getAssetUri();
                      if (uri) {
                        console.log('Found from ' + p.name + '.getAssetUri()');
                        streamUrl = uri;
                        return true;
                      }
                    }
                    if (player.media && player.media.src) {
                      console.log('Found from ' + p.name);
                      streamUrl = player.media.src;
                      return true;
                    }
                  }
                } catch (e) {}
              }
            } catch (e) {
              console.log('Error checking player libraries: ' + e);
            }
            
            // Strategy 8: Look in href and src attributes
            try {
              const links = document.querySelectorAll('a[href], button[onclick], div[onclick]');
              for (let link of links) {
                let url = link.getAttribute('href') || link.getAttribute('data-url');
                if (url && (url.includes('.m3u8') || url.includes('.mp4') || url.includes('.mpd'))) {
                  console.log('Found in link/button: ' + url.substring(0, 100));
                  streamUrl = url;
                  return true;
                }
              }
            } catch (e) {
              console.log('Error checking links: ' + e);
            }
            
            return false;
          }
          
          // Initial attempt
          if (extractStream()) {
            sendStreamUrl(streamUrl);
          } else if (attempts < maxAttempts) {
            // Retry after delay for dynamic content
            const delayMs = attempts < 5 ? 300 : 500;
            setTimeout(extractStream, delayMs);
          } else {
            console.log('Failed to extract stream after ' + maxAttempts + ' attempts');
            
            // Last resort: Log page structure for debugging
            console.log('Page domain: ' + window.location.hostname);
            console.log('Page has player: ' + (window.player != undefined));
            
            // Send empty to timeout gracefully
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
        'Referer': 'https://vidsrc.me',
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
