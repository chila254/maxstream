import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Comprehensive scrapper API service for extracting direct m3u8 URLs
/// Supports multiple streaming sources and provides fallback mechanisms
class ScrapperApiService {
  static const String _tag = 'ScrapperApiService';
  static final Dio _dio = Dio();

  // Initialize Dio with optimized settings for streaming
  static void _initializeDio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/html, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Referer': 'https://vidsrc.to/',
        'Origin': 'https://vidsrc.to',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site',
      },
    );

    // Clear existing interceptors and add fresh logging
    _dio.interceptors.clear();
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: kDebugMode,
        responseBody: kDebugMode,
        error: kDebugMode,
      ),
    );
  }

  // Provider configurations
  static const Map<String, Map<String, String>> _providers = {
    'flixhq': {
      'name': 'FlixHQ',
      'baseUrl': 'https://flixhq.to',
      'type': 'embed',
    },
    'hdtoday': {
      'name': 'HDToday',
      'baseUrl': 'https://hdtoday.tv',
      'type': 'embed',
    },
    'sflix': {'name': 'Sflix', 'baseUrl': 'https://sflix.to', 'type': 'embed'},
    'lookmovie': {
      'name': 'LookMovie',
      'baseUrl': 'https://lookmovie.io',
      'type': 'embed',
    },
  };

  /// Extract direct m3u8 stream URL using multiple scrapper APIs
  ///
  /// [tmdbId] - The TMDB ID of the content
  /// [isMovie] - Whether this is a movie (true) or TV show (false)
  /// [season] - TV show season number (ignored for movies)
  /// [episode] - TV show episode number (ignored for movies)
  /// [preferredProvider] - Preferred scrapper provider (optional)
  ///
  /// Returns a StreamExtractionResult with the best available stream URL
  static Future<StreamExtractionResult> extractStreamUrl(
    String tmdbId, {
    bool isMovie = true,
    int season = 1,
    int episode = 1,
    String? preferredProvider,
  }) async {
    _initializeDio();

    debugPrint(
      '$_tag: Starting stream extraction for ${isMovie ? 'movie' : 'tv'} $tmdbId',
    );

    // Get list of providers to try (respecting preference)
    final providersToTry = _getProvidersToTry(preferredProvider);

    for (final provider in providersToTry) {
      try {
        debugPrint('$_tag: Trying provider: ${provider['name']}');

        final result = await _tryProvider(
          provider,
          tmdbId,
          isMovie: isMovie,
          season: season,
          episode: episode,
        );

        if (result.success && result.streamUrl != null) {
          debugPrint(
            '$_tag: Success with ${provider['name']}: ${result.streamUrl}',
          );
          return result;
        }
      } catch (e) {
        debugPrint('$_tag: Error with ${provider['name']}: $e');
        // Continue to next provider
      }
    }

    debugPrint('$_tag: All providers failed to extract stream');
    return StreamExtractionResult.failure(
      'Failed to extract stream from all available sources',
    );
  }

  /// Get providers to try based on preference
  static List<Map<String, String>> _getProvidersToTry(
    String? preferredProvider,
  ) {
    final allProviders = _providers.entries
        .map((entry) => entry.value)
        .toList();

    if (preferredProvider != null &&
        _providers.containsKey(preferredProvider)) {
      final preferred = _providers[preferredProvider]!;
      final others = allProviders.where((p) => p != preferred).toList();
      return [preferred, ...others];
    }

    // Default priority order
    return [
      _providers['flixhq']!,
      _providers['hdtoday']!,
      _providers['sflix']!,
      _providers['lookmovie']!,
    ];
  }

  /// Try a specific provider to extract stream
  static Future<StreamExtractionResult> _tryProvider(
    Map<String, String> provider,
    String tmdbId, {
    required bool isMovie,
    required int season,
    required int episode,
  }) async {
    final providerType = provider['type'];
    final baseUrl = provider['baseUrl']!;
    final providerName = provider['name']!;

    if (providerType == 'api') {
      return await _tryApiProvider(
        providerName,
        baseUrl,
        tmdbId,
        isMovie,
        season,
        episode,
      );
    } else {
      return await _tryEmbedProvider(
        providerName,
        baseUrl,
        tmdbId,
        isMovie,
        season,
        episode,
      );
    }
  }

  /// Try API-based provider (direct JSON response)
  static Future<StreamExtractionResult> _tryApiProvider(
    String providerName,
    String baseUrl,
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    try {
      String endpoint;
      if (isMovie) {
        endpoint = '$baseUrl/vidsrc/$tmdbId';
      } else {
        endpoint = '$baseUrl/vidsrc/$tmdbId?s=$season&e=$episode';
      }

      debugPrint('$_tag: API request to: $endpoint');

      final response = await _dio.get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        dynamic data = response.data;
        String? streamUrl;
        String? message;

        // Try to parse as JSON if it's a string
        if (data is String) {
          try {
            data = _parseJsonString(data);
          } catch (_) {
            // Not JSON, handle as raw response
            if (data.contains('.m3u8') || data.startsWith('http')) {
              streamUrl = data;
            }
          }
        }

        if (data is Map) {
          // Handle different response formats
          if (data.containsKey('url')) {
            streamUrl = data['url'] as String?;
          } else if (data.containsKey('stream')) {
            streamUrl = data['stream'] as String?;
          } else if (data.containsKey('m3u8')) {
            streamUrl = data['m3u8'] as String?;
          } else if (data.containsKey('sources')) {
            final sources = data['sources'] as List?;
            if (sources != null && sources.isNotEmpty) {
              streamUrl = sources.first['url'] as String?;
            }
          }

          message =
              data['message'] as String? ?? 'Stream extracted successfully';
        }

        if (streamUrl != null && streamUrl.isNotEmpty) {
          return StreamExtractionResult.success(
            streamUrl: _cleanStreamUrl(streamUrl),
            source: providerName,
            message: message ?? 'Stream extracted from API',
          );
        }
      } else if (response.statusCode != null && response.statusCode! >= 400) {
        return StreamExtractionResult.failure(
          'HTTP ${response.statusCode} from $providerName',
        );
      }

      return StreamExtractionResult.failure(
        'No valid stream URL in API response',
      );
    } catch (e) {
      return StreamExtractionResult.failure('API request failed: $e');
    }
  }

  /// Parse JSON string safely
  static dynamic _parseJsonString(String str) {
    // Simple JSON parsing - for production use a proper JSON library
    final trimmed = str.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      // Could be JSON, but without a JSON parser, we'll skip
      return null;
    }
    return str;
  }

  /// Try embed-based provider (scrape from embed page)
  static Future<StreamExtractionResult> _tryEmbedProvider(
    String providerName,
    String baseUrl,
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    try {
      String embedUrl;
      if (isMovie) {
        embedUrl = '$baseUrl/embed/movie/$tmdbId';
      } else {
        embedUrl = '$baseUrl/embed/tv/$tmdbId/$season/$episode';
      }

      debugPrint('$_tag: Embed request to: $embedUrl');

      // Try to get embed page content
      final response = await _dio.get(embedUrl);

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();

        // Check if we got actual embed content (not a parking page)
        if (html.isEmpty || html.length < 100) {
          return StreamExtractionResult.failure(
            'Empty or invalid response from $providerName',
          );
        }

        // Try direct m3u8 extraction first
        var streamUrl = _extractM3u8DirectFromHtml(html);

        // Fallback to general stream extraction
        if (streamUrl == null) {
          streamUrl = _extractStreamFromHtml(html, providerName);
        }

        if (streamUrl != null) {
          return StreamExtractionResult.success(
            streamUrl: _cleanStreamUrl(streamUrl),
            source: providerName,
            message: 'Stream extracted from embed page',
          );
        }
      } else if (response.statusCode != null && response.statusCode! >= 400) {
        return StreamExtractionResult.failure(
          'HTTP ${response.statusCode} from $providerName',
        );
      }

      return StreamExtractionResult.failure(
        'Failed to extract stream from embed page',
      );
    } catch (e) {
      return StreamExtractionResult.failure('Embed request failed: $e');
    }
  }

  /// Extract direct m3u8 URL from HTML with advanced pattern matching
  static String? _extractM3u8DirectFromHtml(String html) {
    try {
      // Pattern 1: Direct m3u8 URL in src attribute
      final srcPattern = RegExp(
        'src\\s*=\\s*["\']?(https?://[^"\']*\\.m3u8[^"\']*)["\']?',
        caseSensitive: false,
      );
      final srcMatch = srcPattern.firstMatch(html);
      if (srcMatch != null) {
        final url = srcMatch.group(1);
        if (url != null && _isValidStreamUrl(url)) {
          return url;
        }
      }

      // Pattern 2: m3u8 in data-src
      final dataSrcPattern = RegExp(
        'data-src\\s*=\\s*["\']?(https?://[^"\']*\\.m3u8[^"\']*)["\']?',
        caseSensitive: false,
      );
      final dataSrcMatch = dataSrcPattern.firstMatch(html);
      if (dataSrcMatch != null) {
        final url = dataSrcMatch.group(1);
        if (url != null && _isValidStreamUrl(url)) {
          return url;
        }
      }

      // Pattern 3: m3u8 in file property (HLS.js)
      final filePattern = RegExp(
        'file\\s*:\\s*["\']?(https?://[^"\']*\\.m3u8[^"\']*)["\']?',
        caseSensitive: false,
      );
      final fileMatch = filePattern.firstMatch(html);
      if (fileMatch != null) {
        final url = fileMatch.group(1);
        if (url != null && _isValidStreamUrl(url)) {
          return url;
        }
      }

      // Pattern 4: m3u8 in url property
      final urlPattern = RegExp(
        '(["\'])?url\\1\\s*:\\s*["\']?(https?://[^"\']*\\.m3u8[^"\']*)["\']?',
        caseSensitive: false,
      );
      final urlMatch = urlPattern.firstMatch(html);
      if (urlMatch != null) {
        final url = urlMatch.group(2);
        if (url != null && _isValidStreamUrl(url)) {
          return url;
        }
      }

      // Pattern 5: m3u8 in source tag
      final sourcePattern = RegExp(
        '<source[^>]*src\\s*=\\s*["\']?(https?://[^"\']*\\.m3u8[^"\']*)["\']?',
        caseSensitive: false,
      );
      final sourceMatch = sourcePattern.firstMatch(html);
      if (sourceMatch != null) {
        final url = sourceMatch.group(1);
        if (url != null && _isValidStreamUrl(url)) {
          return url;
        }
      }

      // Pattern 6: Plain m3u8 URL
      final plainPattern = RegExp('(https?://[^\\s"\'<>]*\\.m3u8[^\\s"\'<>]*)');
      final plainMatch = plainPattern.firstMatch(html);
      if (plainMatch != null) {
        final url = plainMatch.group(1);
        if (url != null && _isValidStreamUrl(url)) {
          return url;
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Error in m3u8 extraction: $e');
      return null;
    }
  }

  /// Check if URL is valid for streaming
  static bool _isValidStreamUrl(String url) {
    if (url.isEmpty || url.length > 2000) {
      return false;
    }
    // Check for common invalid patterns
    if (url.contains('javascript:') || url.contains('data:')) {
      return false;
    }
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Extract stream URL from HTML content
  static String? _extractStreamFromHtml(String html, String providerName) {
    try {
      // Simple pattern matching for common stream URLs
      if (html.contains('.m3u8')) {
        final m3u8Match = RegExp(
          r'(https?://[^"\s]*?\.m3u8[^"\s]*)',
        ).firstMatch(html);
        if (m3u8Match != null) {
          final url = m3u8Match.group(1);
          if (url != null && _isValidM3u8Url(url)) {
            debugPrint('$_tag: Found m3u8 URL: $url');
            return url;
          }
        }
      }

      // Look for other stream indicators
      if (html.contains('file:') ||
          html.contains('streamUrl:') ||
          html.contains('source:')) {
        final pattern = RegExp(r'(https?://[^"\s]*)');
        final matches = pattern.allMatches(html);

        for (final match in matches) {
          final url = match.group(1);
          if (url != null && _looksLikeStreamUrl(url) && !_isEmbedUrl(url)) {
            debugPrint('$_tag: Found stream URL: $url');
            return url;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Error extracting stream from HTML: $e');
      return null;
    }
  }

  /// Check if URL looks like a streaming URL
  static bool _looksLikeStreamUrl(String url) {
    final streamIndicators = [
      '.m3u8',
      '.mp4',
      '.webm',
      '.mkv',
      'stream',
      'video',
      'embed',
    ];

    return streamIndicators.any(
      (indicator) => url.toLowerCase().contains(indicator),
    );
  }

  /// Check if URL is a valid m3u8 URL (prioritize m3u8 over embed URLs)
  static bool _isValidM3u8Url(String url) {
    if (url.isEmpty || url.length > 2000) {
      return false;
    }
    // Must be HTTP/HTTPS and contain .m3u8
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return false;
    }
    if (!url.contains('.m3u8')) {
      return false;
    }
    // Avoid embed/player URLs that might contain m3u8 in path but are not streams
    if (_isEmbedUrl(url)) {
      return false;
    }
    return true;
  }

  /// Check if URL is an embed/player URL (not a direct stream)
  static bool _isEmbedUrl(String url) {
    final embedIndicators = [
      '/embed/',
      '/player/',
      '/watch/',
      '/video/',
      'player.',
      'embed.',
      'watch.',
      'iframe',
      'javascript:',
      'data:',
    ];

    final lowerUrl = url.toLowerCase();
    return embedIndicators.any((indicator) => lowerUrl.contains(indicator));
  }

  /// Clean and validate stream URL
  static String _cleanStreamUrl(String url) {
    // Remove any surrounding whitespace and quotes
    url = url.trim().replaceAll(RegExp('["\']'), '');

    // Fix common URL issues
    if (url.startsWith('//')) {
      url = 'https:$url';
    } else if (url.startsWith('/')) {
      url = 'https://vidsrc.to$url';
    }

    return url;
  }

  /// Get available scrapper providers
  static List<Map<String, String>> getAvailableProviders() {
    return _providers.values.toList();
  }

  /// Test a specific provider
  static Future<StreamExtractionResult> testProvider(
    String providerKey,
    String tmdbId, {
    bool isMovie = true,
    int season = 1,
    int episode = 1,
  }) async {
    if (!_providers.containsKey(providerKey)) {
      return StreamExtractionResult.failure('Provider not found: $providerKey');
    }

    final provider = _providers[providerKey]!;
    return await _tryProvider(
      provider,
      tmdbId,
      isMovie: isMovie,
      season: season,
      episode: episode,
    );
  }

  /// Health check for all providers
  static Future<Map<String, bool>> checkProvidersHealth() async {
    final health = <String, bool>{};
    const testTmdbId = '550'; // Fight Club (popular test movie)

    for (final entry in _providers.entries) {
      try {
        final result = await testProvider(entry.key, testTmdbId);
        health[entry.value['name']!] = result.success;
      } catch (e) {
        health[entry.value['name']!] = false;
      }
    }

    return health;
  }

  /// Clear any cached data
  static Future<void> clearCache() async {
    _initializeDio();
    debugPrint('$_tag: Cache cleared');
  }

  /// Dispose resources
  static void dispose() {
    _dio.close();
    debugPrint('$_tag: Service disposed');
  }
}

/// Result class for stream extraction from scrapper APIs
class StreamExtractionResult {
  final bool success;
  final String? streamUrl;
  final String? error;
  final String? message;
  final String source;

  const StreamExtractionResult({
    required this.success,
    this.streamUrl,
    this.error,
    this.message,
    required this.source,
  });

  /// Create successful result
  factory StreamExtractionResult.success({
    required String streamUrl,
    required String source,
    String? message,
  }) {
    return StreamExtractionResult(
      success: true,
      streamUrl: streamUrl,
      source: source,
      message: message ?? 'Stream extracted successfully',
    );
  }

  /// Create failure result
  factory StreamExtractionResult.failure(String error) {
    return StreamExtractionResult(
      success: false,
      error: error,
      source: 'scrapper_api',
    );
  }

  @override
  String toString() {
    return 'StreamExtractionResult(success: $success, streamUrl: $streamUrl, error: $error, message: $message, source: $source)';
  }
}
