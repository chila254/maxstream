import 'package:flutter/foundation.dart';
import 'scrapper_api_service.dart';

/// Stream extraction service that only works with scrapper API
/// Provides direct access to scrapper API for extracting streaming URLs
class CombinedStreamService {
  static const String _tag = 'CombinedStreamService';

  /// Extract stream URL using scrapper API approach
  ///
  /// [tmdbId] - The TMDB ID of the content
  /// [isMovie] - Whether this is a movie (true) or TV show (false)
  /// [season] - TV show season number (ignored for movies)
  /// [episode] - TV show episode number (ignored for movies)
  ///
  /// Returns a map with stream URL and metadata
  static Future<Map<String, dynamic>?> extractStream(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    debugPrint(
      '$_tag: Starting scrapper API extraction for ${isMovie ? 'movie' : 'tv'} $tmdbId',
    );

    // Try scrapper API extraction
    final scrapperResult = await _tryScrapperExtraction(
      tmdbId,
      isMovie,
      season: season,
      episode: episode,
    );

    if (scrapperResult != null) {
      debugPrint('$_tag: ✓ Scrapper API extraction succeeded');
      return {...scrapperResult, 'method': 'scrapper_api', 'priority': 1};
    }

    debugPrint('$_tag: ✗ Scrapper API extraction failed');
    return null;
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

  /// Health check - verify scrapper API is responsive
  static Future<Map<String, bool>> checkHealth() async {
    try {
      final scrapperProviders = ScrapperApiService.getAvailableProviders();

      return {
        'scrapper_api': scrapperProviders.isNotEmpty,
        'overall': scrapperProviders.isNotEmpty,
      };
    } catch (e) {
      debugPrint('$_tag: Health check error: $e');
      return {'scrapper_api': false, 'overall': false};
    }
  }

  /// Test a specific provider
  static Future<bool> testProvider(
    String providerKey,
    String testTmdbId, {
    bool isMovie = true,
  }) async {
    try {
      final result = await ScrapperApiService.testProvider(
        providerKey,
        testTmdbId,
        isMovie: isMovie,
      );
      return result.success;
    } catch (e) {
      debugPrint('$_tag: Test provider error: $e');
      return false;
    }
  }

  /// Clear caches from scrapper API service
  static Future<void> clearCaches() async {
    try {
      await ScrapperApiService.clearCache();
      debugPrint('$_tag: Scrapper API cache cleared');
    } catch (e) {
      debugPrint('$_tag: Cache clear error: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      ScrapperApiService.dispose();
      debugPrint('$_tag: Scrapper API service disposed');
    } catch (e) {
      debugPrint('$_tag: Dispose error: $e');
    }
  }
}
