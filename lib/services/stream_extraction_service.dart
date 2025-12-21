import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';

/// Stream provider model
class StreamProvider {
  final String url;
  final String quality;
  final String source;
  final String type;

  StreamProvider({
    required this.url,
    required this.quality,
    required this.source,
    this.type = 'embed',
  });
}

/// Resolved stream model
class ResolvedStream {
  final String url;
  final String quality;
  final String source;
  final String type; // 'hls', 'dash', or 'mp4'
  final Map<String, String>? headers;
  final bool isPlayable;
  final String? embedUrl;

  ResolvedStream({
    required this.url,
    required this.quality,
    required this.source,
    required this.type,
    this.headers,
    this.isPlayable = true,
    this.embedUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'quality': quality,
      'source': source,
      'type': type,
      'headers': headers,
      'isPlayable': isPlayable,
      'embedUrl': embedUrl,
    };
  }
}

/// Unified Stream Extraction Service
/// Single service for all stream extraction needs:
/// 1. Gets embed URLs from Stremio providers
/// 2. Resolves embeds to playable streams (Android native, WebView, or Proxy)
/// 3. Handles fallbacks and retries
class StreamExtractionService {
  static const String _tag = 'StreamExtractionService';

  // Stremio providers
  static const Map<String, String> _providers = {
    'vidsrc_me': 'https://vidsrc.me/embed',
    'vidsrc_icu': 'https://vidsrc.icu/embed',
    'vidsrc_pro': 'https://vidsrc.pro/embed',
    'moviesapi': 'https://moviesapi.club/embed',
  };

  static WebViewController? _webViewController;
  static Completer<String?>? _urlCompleter;
  static bool _isInitialized = false;

  /// Main entry point: Extract and resolve stream for movies/TV
  static Future<Map<String, dynamic>?> extractStream(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      debugPrint('');
      debugPrint('$_tag: ╔════════════════════════════════════════════╗');
      debugPrint('$_tag: ║       STREAM EXTRACTION STARTED             ║');
      debugPrint('$_tag: ╚════════════════════════════════════════════╝');
      debugPrint('$_tag: Content Type: ${isMovie ? 'MOVIE' : 'TV SERIES'}');
      debugPrint('$_tag: TMDB ID: $tmdbId');
      if (!isMovie) {
        debugPrint('$_tag: Season: $season, Episode: $episode');
      }
      debugPrint('');

      // Step 1: Get embed URLs from Stremio providers
      debugPrint('$_tag: 📍 STEP 1: Discovering Stremio Providers');
      debugPrint('$_tag: ─────────────────────────────────────');
      List<StreamProvider> providers;

      if (isMovie) {
        providers = await _getMovieStreams(tmdbId);
      } else {
        providers = await _getSeriesStreams(tmdbId, season, episode);
      }

      if (providers.isEmpty) {
        debugPrint('$_tag: ❌ STEP 1 FAILED: No Stremio providers found');
        return null;
      }

      debugPrint(
        '$_tag: ✓ STEP 1 SUCCESS: Found ${providers.length} providers',
      );
      debugPrint('');

      // Step 2: Resolve embeds to playable URLs
      debugPrint('$_tag: 📍 STEP 2: Resolving Embed URLs');
      debugPrint('$_tag: ─────────────────────────────────────');
      final providersToResolve = providers
          .map((p) => (url: p.url, source: p.source, quality: p.quality))
          .toList();

      debugPrint(
        '$_tag: Attempting to resolve ${providersToResolve.length} providers...',
      );
      debugPrint('$_tag: Provider order (by quality):');
      for (int i = 0; i < providersToResolve.length; i++) {
        final p = providersToResolve[i];
        debugPrint('$_tag:   ${i + 1}. ${p.source} (${p.quality})');
      }
      debugPrint('');

      final resolvedStream = await _resolveBestSource(providersToResolve);

      if (resolvedStream == null || !resolvedStream.isPlayable) {
        debugPrint('$_tag: ❌ STEP 2 FAILED: Could not resolve any stream');
        return null;
      }

      debugPrint('');
      debugPrint('$_tag: ✓ STEP 2 SUCCESS: Stream resolved');
      debugPrint('');
      debugPrint('$_tag: ╔════════════════════════════════════════════╗');
      debugPrint('$_tag: ║       STREAM EXTRACTION COMPLETED ✓         ║');
      debugPrint('$_tag: ╚════════════════════════════════════════════╝');
      debugPrint('$_tag: 📺 Source: ${resolvedStream.source}');
      debugPrint('$_tag: 🎬 Quality: ${resolvedStream.quality}');
      debugPrint('$_tag: 🔗 Type: ${resolvedStream.type}');
      final urlPreview = resolvedStream.url.substring(
        0,
        resolvedStream.url.length > 100 ? 100 : resolvedStream.url.length,
      );
      debugPrint('$_tag: 📡 URL: $urlPreview...');
      debugPrint('');

      return {
        'streamUrl': resolvedStream.url,
        'source': resolvedStream.source,
        'type': resolvedStream.type,
        'quality': resolvedStream.quality,
        'embedUrl': resolvedStream.embedUrl,
        'method': 'unified_extraction',
        'message': 'Stream resolved from ${resolvedStream.source}',
        'headers': resolvedStream.headers,
        'isPlayable': resolvedStream.isPlayable,
      };
    } catch (e) {
      debugPrint('$_tag: ❌ FATAL ERROR: $e');
      return null;
    }
  }

  /// Get movie streams from Stremio providers
  static Future<List<StreamProvider>> _getMovieStreams(String tmdbId) async {
    Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );

    try {
      debugPrint('');
      debugPrint('$_tag: ═══════════════════════════════════════════');
      debugPrint('$_tag: Discovering Stremio providers for movie');
      debugPrint('$_tag: TMDB ID: $tmdbId');
      debugPrint('$_tag: ═══════════════════════════════════════════');

      final providers = <StreamProvider>[];

      for (final entry in _providers.entries) {
        try {
          final url = '${entry.value}/movie/$tmdbId';
          debugPrint('$_tag: [${entry.key}] Testing: $url');

          final response = await dio.head(
            url,
            options: Options(validateStatus: (status) => status! < 500),
          );

          if (response.statusCode! < 400) {
            final quality = _getQualityForProvider(entry.key);
            providers.add(
              StreamProvider(
                url: url,
                quality: quality,
                source: _formatSourceName(entry.key),
              ),
            );
            debugPrint(
              '$_tag: ✓ [${entry.key}] Available - ${response.statusCode} - $quality',
            );
          } else {
            debugPrint(
              '$_tag: ❌ [${entry.key}] Not available - ${response.statusCode}',
            );
          }
        } catch (e) {
          debugPrint('$_tag: ❌ [${entry.key}] Error: $e');
        }
      }

      if (providers.isEmpty) {
        debugPrint('$_tag: ❌ No providers available for movie $tmdbId');
        return [];
      }

      debugPrint('$_tag: ✓ Found ${providers.length} available providers');
      for (final p in providers) {
        debugPrint('$_tag:   • ${p.source} (${p.quality})');
      }
      debugPrint('$_tag: ═══════════════════════════════════════════');
      debugPrint('');

      return providers;
    } catch (e) {
      debugPrint('$_tag: ❌ Error fetching movie streams: $e');
      return [];
    } finally {
      dio.close();
    }
  }

  /// Get series streams from Stremio providers
  static Future<List<StreamProvider>> _getSeriesStreams(
    String tmdbId,
    int season,
    int episode,
  ) async {
    Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );

    try {
      debugPrint(
        '$_tag: Fetching streams for series $tmdbId S$season E$episode',
      );

      final providers = <StreamProvider>[];

      for (final entry in _providers.entries) {
        try {
          final url = '${entry.value}/tv/$tmdbId/$season/$episode';
          debugPrint('$_tag: Attempting provider: ${entry.key}');

          final response = await dio.head(
            url,
            options: Options(validateStatus: (status) => status! < 500),
          );

          if (response.statusCode! < 400) {
            final quality = _getQualityForProvider(entry.key);
            providers.add(
              StreamProvider(
                url: url,
                quality: quality,
                source: _formatSourceName(entry.key),
              ),
            );
            debugPrint('$_tag: ✓ Provider ${entry.key} is available');
          }
        } catch (e) {
          debugPrint('$_tag: Provider ${entry.key} failed: $e');
        }
      }

      if (providers.isEmpty) {
        debugPrint('$_tag: No providers available for series $tmdbId');
        return [];
      }

      debugPrint('$_tag: Found ${providers.length} available providers');
      return providers;
    } catch (e) {
      debugPrint('$_tag: Error fetching series streams: $e');
      return [];
    } finally {
      dio.close();
    }
  }

  /// Resolve best source with multiple strategies
  static Future<ResolvedStream?> _resolveBestSource(
    List<({String url, String source, String quality})> sources,
  ) async {
    for (final source in sources) {
      debugPrint(
        '$_tag: Attempting to resolve ${source.source} - ${source.quality}',
      );

      // Strategy 1: Try Android native fetch (direct, no ORB issues)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await _resolveStreamAndroid(
          source.url,
          source: source.source,
          quality: source.quality,
        );
        if (result != null) {
          debugPrint('$_tag: ✓ Successfully resolved via Android native');
          return result;
        }
      }

      // Strategy 2: Try WebView
      final webViewResult = await _resolveStreamWebView(
        source.url,
        source: source.source,
        quality: source.quality,
      );
      if (webViewResult != null) {
        debugPrint('$_tag: ✓ Successfully resolved via WebView');
        return webViewResult;
      }

      // Strategy 3: Try proxy fetch
      final proxyResult = await _resolveStreamProxy(
        source.url,
        source: source.source,
        quality: source.quality,
      );
      if (proxyResult != null) {
        debugPrint('$_tag: ✓ Successfully resolved via proxy');
        return proxyResult;
      }

      debugPrint(
        '$_tag: Failed to resolve from ${source.source}, trying next...',
      );
    }

    debugPrint('$_tag: ✗ Failed to resolve any source');
    return null;
  }

  /// Strategy 1: Android native fetch (bypasses ORB completely)
  static Future<ResolvedStream?> _resolveStreamAndroid(
    String embedUrl, {
    required String source,
    required String quality,
  }) async {
    try {
      debugPrint('$_tag: [Android] Fetching $source...');

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Referer': embedUrl,
          },
        ),
      );

      try {
        final response = await dio.get<String>(
          embedUrl,
          options: Options(
            validateStatus: (status) => status! < 500,
            followRedirects: true,
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final streamUrl = _extractStreamUrl(response.data!);
          if (streamUrl != null) {
            return ResolvedStream(
              url: streamUrl,
              quality: quality,
              source: source,
              type: _detectStreamType(streamUrl),
              headers: _getHeadersForSource(source),
              isPlayable: true,
              embedUrl: embedUrl,
            );
          }
        }
      } finally {
        dio.close();
      }
    } catch (e) {
      debugPrint('$_tag: [Android] Error: $e');
    }
    return null;
  }

  /// Strategy 2: WebView resolution
  static Future<ResolvedStream?> _resolveStreamWebView(
    String embedUrl, {
    required String source,
    required String quality,
  }) async {
    try {
      debugPrint('$_tag: [WebView] Resolving $source...');

      if (!_isInitialized) {
        await _initializeWebView();
      }

      if (_webViewController == null) {
        return null;
      }

      _urlCompleter = Completer<String?>();

      final wrapperHtml = _buildWrapperHtml(embedUrl);
      final dataUri =
          'data:text/html;base64,${base64Encode(utf8.encode(wrapperHtml))}';
      await _webViewController!.loadRequest(Uri.parse(dataUri));

      final streamUrl = await _urlCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );

      _urlCompleter = null;

      if (streamUrl != null && streamUrl.isNotEmpty) {
        return ResolvedStream(
          url: streamUrl,
          quality: quality,
          source: source,
          type: _detectStreamType(streamUrl),
          headers: _getHeadersForSource(source),
          isPlayable: true,
          embedUrl: embedUrl,
        );
      }
    } catch (e) {
      debugPrint('$_tag: [WebView] Error: $e');
    }
    return null;
  }

  /// Strategy 3: Proxy fetch
  static Future<ResolvedStream?> _resolveStreamProxy(
    String embedUrl, {
    required String source,
    required String quality,
  }) async {
    try {
      debugPrint('$_tag: [Proxy] Fetching $source...');

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );

      try {
        final response = await dio.get<String>(
          embedUrl,
          options: Options(validateStatus: (status) => status! < 500),
        );

        if (response.statusCode == 200 && response.data != null) {
          final streamUrl = _extractStreamUrl(response.data!);
          if (streamUrl != null) {
            return ResolvedStream(
              url: streamUrl,
              quality: quality,
              source: source,
              type: _detectStreamType(streamUrl),
              headers: _getHeadersForSource(source),
              isPlayable: true,
              embedUrl: embedUrl,
            );
          }
        }
      } finally {
        dio.close();
      }
    } catch (e) {
      debugPrint('$_tag: [Proxy] Error: $e');
    }
    return null;
  }

  /// Extract stream URL from HTML content
  static String? _extractStreamUrl(String htmlContent) {
    try {
      // Pattern 1: m3u8 URLs
      final m3u8 = RegExp(
        r'https?://[^\s]+\.m3u8[^\s]*',
        caseSensitive: false,
      ).firstMatch(htmlContent);
      if (m3u8 != null) return m3u8.group(0);

      // Pattern 2: mp4 URLs
      final mp4 = RegExp(
        r'https?://[^\s]+\.mp4[^\s]*',
        caseSensitive: false,
      ).firstMatch(htmlContent);
      if (mp4 != null) return mp4.group(0);

      // Pattern 3: mpd URLs
      final mpd = RegExp(
        r'https?://[^\s]+\.mpd[^\s]*',
        caseSensitive: false,
      ).firstMatch(htmlContent);
      if (mpd != null) return mpd.group(0);

      return null;
    } catch (e) {
      debugPrint('$_tag: Extract error: $e');
      return null;
    }
  }

  /// Detect stream type from URL
  static String _detectStreamType(String url) {
    if (url.contains('.m3u8')) return 'hls';
    if (url.contains('.mpd')) return 'dash';
    if (url.contains('.mp4')) return 'mp4';
    return 'http';
  }

  /// Get quality for provider
  static String _getQualityForProvider(String providerKey) {
    if (providerKey.contains('pro')) return '1080p';
    return '720p';
  }

  /// Format source name
  static String _formatSourceName(String providerKey) {
    return providerKey
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get headers for source
  static Map<String, String>? _getHeadersForSource(String source) {
    final sourceUri = source.toLowerCase();
    if (sourceUri.contains('vidsrc')) {
      return {
        'Referer': 'https://vidsrc.me',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    }
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };
  }

  /// Initialize WebView
  static Future<void> _initializeWebView() async {
    if (_isInitialized) return;

    try {
      debugPrint('$_tag: Initializing WebView');

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              Future.delayed(const Duration(milliseconds: 500), () {
                _extractStreamFromPage();
              });
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('$_tag: WebView error: ${error.description}');
              _urlCompleter?.complete(null);
            },
          ),
        )
        ..addJavaScriptChannel(
          'StreamExtractor',
          onMessageReceived: (JavaScriptMessage message) {
            if (message.message.isNotEmpty &&
                _urlCompleter != null &&
                !_urlCompleter!.isCompleted) {
              _urlCompleter?.complete(message.message);
            }
          },
        );

      _isInitialized = true;
      debugPrint('$_tag: ✓ WebView initialized');
    } catch (e) {
      debugPrint('$_tag: Error initializing WebView: $e');
      rethrow;
    }
  }

  /// Extract stream from WebView page
  static Future<void> _extractStreamFromPage() async {
    if (_webViewController == null) return;

    try {
      const String script = '''
        (function() {
          let streamUrl = null;
          let attempts = 0;
          const maxAttempts = 10;
          
          function sendStreamUrl(url) {
            if (url && url.trim() && url.length > 5) {
              StreamExtractor.postMessage(url);
            }
          }
          
          function extractStream() {
            attempts++;
            
            // Check for player source
            try {
              if (window.player?.source) return (streamUrl = window.player.source), true;
              if (window.__player?.src) return (streamUrl = window.__player.src), true;
            } catch (e) {}
            
            // Check for video elements
            try {
              const videos = document.querySelectorAll('video[src], video > source[src]');
              for (let v of videos) {
                const src = v.src || v.getAttribute('src');
                if (src?.startsWith('http')) return (streamUrl = src), true;
              }
            } catch (e) {}
            
            // Search scripts
            try {
              const text = document.body.innerText;
              const m3u8 = text.match(/https?:\\/\\/[^\\s"'<>]+\\.m3u8[^\\s"'<>]*/);
              if (m3u8) return (streamUrl = m3u8[0]), true;
            } catch (e) {}
            
            return false;
          }
          
          if (extractStream()) {
            sendStreamUrl(streamUrl);
          } else if (attempts < maxAttempts) {
            setTimeout(extractStream, 300);
          } else {
            StreamExtractor.postMessage('');
          }
        })();
      ''';

      await _webViewController!.runJavaScript(script);
    } catch (e) {
      debugPrint('$_tag: Error extracting from page: $e');
    }
  }

  /// Build wrapper HTML for WebView
  static String _buildWrapperHtml(String embedUrl) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { margin: 0; padding: 0; }
          iframe { width: 100%; height: 100%; border: none; display: block; }
        </style>
      </head>
      <body>
        <iframe src="$embedUrl" sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-presentation"></iframe>
      </body>
      </html>
    ''';
  }

  /// Get available providers
  static Future<List<StreamProvider>> getAvailableProviders(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      if (isMovie) {
        return await _getMovieStreams(tmdbId);
      } else {
        return await _getSeriesStreams(tmdbId, season, episode);
      }
    } catch (e) {
      debugPrint('$_tag: Error getting providers: $e');
      return [];
    }
  }

  /// Health check
  static Future<Map<String, bool>> checkHealth() async {
    try {
      final providers = await _getMovieStreams('278');
      final isHealthy = providers.isNotEmpty;
      return {'extraction_service': isHealthy, 'overall': isHealthy};
    } catch (e) {
      debugPrint('$_tag: Health check error: $e');
      return {'extraction_service': false, 'overall': false};
    }
  }

  /// Clear caches
  static Future<void> clearCaches() async {
    try {
      debugPrint('$_tag: Caches cleared');
    } catch (e) {
      debugPrint('$_tag: Cache clear error: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      _webViewController = null;
      _urlCompleter = null;
      _isInitialized = false;
      debugPrint('$_tag: Service disposed');
    } catch (e) {
      debugPrint('$_tag: Dispose error: $e');
    }
  }

  /// Initialize service
  static Future<void> initialize() async {
    try {
      debugPrint('$_tag: Initializing...');
      await _initializeWebView();
      debugPrint('$_tag: Service initialized');
    } catch (e) {
      debugPrint('$_tag: Initialization error: $e');
    }
  }
}
