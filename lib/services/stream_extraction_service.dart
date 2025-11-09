import 'package:flutter/foundation.dart';
import 'native_stream_extractor_service.dart';

/// Service for extracting playable stream URLs from embed pages
/// Uses native platform bridges (Android/iOS WebView) for optimal performance
class StreamExtractionService {
  /// Extract stream URL for a movie or TV show
  ///
  /// [tmdbId] - The TMDB ID of the content
  /// [isMovie] - Whether this is a movie (true) or TV show (false)
  /// [season] - TV show season number (ignored for movies)
  /// [episode] - TV show episode number (ignored for movies)
  ///
  /// Returns a map with stream URL and metadata, or null if extraction fails
  static Future<Map<String, dynamic>?> extractStream(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      debugPrint(
        'StreamExtractionService: Starting extraction for ${isMovie ? 'movie' : 'tv'} $tmdbId',
      );

      // Construct the embed URL
      final embedUrl = isMovie
          ? 'https://vidsrc.to/embed/movie/$tmdbId'
          : 'https://vidsrc.to/embed/tv/$tmdbId/$season/$episode';

      debugPrint(
        'StreamExtractionService: Extracting from: $embedUrl',
      );

      // Check if native extractor is available
      final isNativeAvailable =
          await NativeStreamExtractorService.isAvailable();

      if (!isNativeAvailable) {
        debugPrint(
          'StreamExtractionService: Native extractor not available',
        );
        return null;
      }

      // Extract stream using native bridge
      final result = await NativeStreamExtractorService.extractStream(
        embedUrl,
        timeoutSeconds: 45,
      );

      debugPrint(
        'StreamExtractionService: Extraction result - $result',
      );

      if (result.success && result.streamUrl != null) {
        debugPrint(
          'StreamExtractionService: Stream extracted successfully',
        );
        return {
          'streamUrl': result.streamUrl,
          'source': result.source,
          'type': result.streamUrl!.contains('.m3u8') ? 'm3u8' : 'direct',
          'message': result.message,
        };
      } else {
        debugPrint(
          'StreamExtractionService: Extraction failed - ${result.error}',
        );
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint(
        'StreamExtractionService: Error during extraction: $e',
      );
      debugPrint('StreamExtractionService: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Clear the native WebView cache
  /// Call this periodically to free up memory
  static Future<void> clearCache() async {
    try {
      await NativeStreamExtractorService.clearCache();
      debugPrint('StreamExtractionService: Cache cleared');
    } catch (e) {
      debugPrint('StreamExtractionService: Error clearing cache - $e');
    }
  }

  /// Dispose native resources
  /// Call this when the app is shutting down or the service is no longer needed
  static Future<void> dispose() async {
    try {
      await NativeStreamExtractorService.dispose();
      debugPrint('StreamExtractionService: Disposed');
    } catch (e) {
      debugPrint('StreamExtractionService: Error disposing - $e');
    }
  }
}
