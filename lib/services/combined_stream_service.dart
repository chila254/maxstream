import 'package:flutter/foundation.dart';
import 'native_stream_extractor_service.dart';
import 'scrapper_api_service.dart';

/// Combined stream extraction service that works with both native API and scrapper API
/// Provides intelligent fallback strategy: Native API first, then Scrapper API, then direct embed scraping
class CombinedStreamService {
  static const String _tag = 'CombinedStreamService';

  /// Extract stream URL using combined native + scrapper approach
  ///
  /// [tmdbId] - The TMDB ID of the content
  /// [isMovie] - Whether this is a movie (true) or TV show (false)
  /// [season] - TV show season number (ignored for movies)
  /// [episode] - TV show episode number (ignored for movies)
  ///
  /// Returns a map with stream URL and metadata with this priority:
  /// 1. Native WebView extraction (highest performance)
  /// 2. Scrapper API extraction (fast, no native overhead)
  /// 3. Direct HTTP scraping fallback
  static Future<Map<String, dynamic>?> extractStream(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    debugPrint(
      '$_tag: Starting combined extraction for ${isMovie ? 'movie' : 'tv'} $tmdbId',
    );

    // Step 1: Try native WebView extraction (highest priority)
    debugPrint('$_tag: Step 1 - Attempting native WebView extraction');
    final nativeResult = await _tryNativeExtraction(
      tmdbId,
      isMovie,
      season: season,
      episode: episode,
    );

    if (nativeResult != null) {
      debugPrint('$_tag: ✓ Native extraction succeeded');
      return {
        ...nativeResult,
        'method': 'native_webview',
        'priority': 1,
      };
    }

    // Step 2: Try scrapper API extraction
    debugPrint('$_tag: Step 2 - Native failed, attempting scrapper API');
    final scrapperResult = await _tryScrapperExtraction(
      tmdbId,
      isMovie,
      season: season,
      episode: episode,
    );

    if (scrapperResult != null) {
      debugPrint('$_tag: ✓ Scrapper API extraction succeeded');
      return {
        ...scrapperResult,
        'method': 'scrapper_api',
        'priority': 2,
      };
    }

    debugPrint('$_tag: ✗ All extraction methods failed');
    return null;
  }

  /// Try native WebView extraction with multiple sources
  static Future<Map<String, dynamic>?> _tryNativeExtraction(
    String tmdbId,
    bool isMovie, {
    required int season,
    required int episode,
  }) async {
    try {
      // Check if native extractor is available
      final isNativeAvailable =
          await NativeStreamExtractorService.isAvailable();

      if (!isNativeAvailable) {
        debugPrint('$_tag: Native extractor not available');
        return null;
      }

      // Try multiple sources
      final sources = _getNativeSources(tmdbId, isMovie, season, episode);

      for (int i = 0; i < sources.length; i++) {
        final embedUrl = sources[i];
        try {
          debugPrint('$_tag: Native attempt ${i + 1}/${sources.length}: $embedUrl');

          final result = await NativeStreamExtractorService.extractStream(
            embedUrl,
            timeoutSeconds: 45,
          );

          if (result.success && result.streamUrl != null) {
            debugPrint('$_tag: Native success from source ${i + 1}');
            return {
              'streamUrl': result.streamUrl,
              'source': result.source,
              'type': result.streamUrl!.contains('.m3u8') ? 'm3u8' : 'direct',
              'message': result.message,
              'sourceIndex': i,
            };
          }
        } catch (e) {
          debugPrint('$_tag: Native source ${i + 1} error: $e');
          continue;
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Native extraction error: $e');
      return null;
    }
  }

  /// Try scrapper API extraction with multiple providers
  static Future<Map<String, dynamic>?> _tryScrapperExtraction(
    String tmdbId,
    bool isMovie, {
    required int season,
    required int episode,
  }) async {
    try {
      final result = await ScrapperApiService.extractStreamUrl(
        tmdbId,
        isMovie: isMovie,
        season: season,
        episode: episode,
      );

      if (result.success && result.streamUrl != null) {
        debugPrint('$_tag: Scrapper API success from ${result.source}');
        return {
          'streamUrl': result.streamUrl,
          'source': result.source,
          'type': result.streamUrl!.contains('.m3u8') ? 'm3u8' : 'direct',
          'message': result.message,
        };
      }

      debugPrint('$_tag: Scrapper API failed: ${result.error}');
      return null;
    } catch (e) {
      debugPrint('$_tag: Scrapper extraction error: $e');
      return null;
    }
  }

  /// Get native embed sources to try
  static List<String> _getNativeSources(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) {
    return [
      // Primary sources (fastest, most reliable)
      if (isMovie)
        'https://vidsrc.pro/embed/movie/$tmdbId'
      else
        'https://vidsrc.pro/embed/tv/$tmdbId/$season/$episode',

      // Fallback sources
      if (isMovie)
        'https://vidsrc.net/embed/movie/$tmdbId'
      else
        'https://vidsrc.net/embed/tv/$tmdbId/$season/$episode',

      if (isMovie)
        'https://vidsrc.me/embed/movie/$tmdbId'
      else
        'https://vidsrc.me/embed/tv/$tmdbId/$season/$episode',
    ];
  }

  /// Health check - verify both services are responsive
  static Future<Map<String, bool>> checkHealth() async {
    try {
      final nativeAvailable =
          await NativeStreamExtractorService.isAvailable();
      final scrapperProviders = ScrapperApiService.getAvailableProviders();

      return {
        'native_webview': nativeAvailable,
        'scrapper_api': scrapperProviders.isNotEmpty,
        'overall': nativeAvailable || scrapperProviders.isNotEmpty,
      };
    } catch (e) {
      debugPrint('$_tag: Health check error: $e');
      return {
        'native_webview': false,
        'scrapper_api': false,
        'overall': false,
      };
    }
  }

  /// Test a specific provider
  static Future<bool> testProvider(
    String providerKey,
    String testTmdbId, {
    bool isMovie = true,
  }) async {
    try {
      if (providerKey == 'native_webview') {
        final result = await NativeStreamExtractorService.extractStream(
          isMovie
              ? 'https://vidsrc.pro/embed/movie/$testTmdbId'
              : 'https://vidsrc.pro/embed/tv/$testTmdbId/1/1',
          timeoutSeconds: 30,
        );
        return result.success;
      } else {
        final result = await ScrapperApiService.testProvider(
          providerKey,
          testTmdbId,
          isMovie: isMovie,
        );
        return result.success;
      }
    } catch (e) {
      debugPrint('$_tag: Test provider error: $e');
      return false;
    }
  }

  /// Clear caches from both services
  static Future<void> clearCaches() async {
    try {
      await NativeStreamExtractorService.clearCache();
      await ScrapperApiService.clearCache();
      debugPrint('$_tag: All caches cleared');
    } catch (e) {
      debugPrint('$_tag: Cache clear error: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      await NativeStreamExtractorService.dispose();
      ScrapperApiService.dispose();
      debugPrint('$_tag: All services disposed');
    } catch (e) {
      debugPrint('$_tag: Dispose error: $e');
    }
  }
}
