import 'package:flutter/foundation.dart';
import 'stremio_provider_service.dart';
import 'stream_resolver_service.dart';

/// Combined stream extraction service
/// Orchestrates Stremio provider discovery and stream resolution for movies and TV series
class CombinedStreamService {
  static const String _tag = 'CombinedStreamService';

  /// Extract and resolve stream URL for movies and TV shows
  ///
  /// This is the main entry point for getting playable streams.
  /// It handles both embed discovery and resolution:
  /// 1. Gets embed URLs from Stremio providers (VidSrc, VidSrc Pro, etc.)
  /// 2. Resolves embeds to actual playable URLs using WebView
  /// 3. Returns ready-to-play stream URL
  ///
  /// [tmdbId] - The TMDB ID of the content
  /// [isMovie] - Whether this is a movie (true) or TV show (false)
  /// [season] - TV show season number (ignored for movies)
  /// [episode] - TV show episode number (ignored for movies)
  ///
  /// Returns a map with playable stream URL and metadata
  static Future<Map<String, dynamic>?> extractStream(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      // Reset connections to prevent connection pool exhaustion
      await StremioProviderService.resetConnections();
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
        providers = await StremioProviderService.getMovieStreams(tmdbId);
      } else {
        providers = await StremioProviderService.getSeriesStreams(
          tmdbId,
          season,
          episode,
        );
      }

      if (providers.isEmpty) {
        debugPrint('$_tag: ❌ STEP 1 FAILED: No Stremio providers found');
        return null;
      }

      debugPrint('$_tag: ✓ STEP 1 SUCCESS: Found ${providers.length} providers');
      debugPrint('');

      // Step 2: Resolve embeds to playable URLs (ordered by quality)
      debugPrint('$_tag: 📍 STEP 2: Resolving Embed URLs via WebView');
      debugPrint('$_tag: ─────────────────────────────────────');
      final providersToResolve = providers
          .map((p) => (url: p.url, source: p.source, quality: p.quality))
          .toList();

      debugPrint('$_tag: Attempting to resolve ${providersToResolve.length} providers...');
      debugPrint('$_tag: Provider order (by quality):');
      for (int i = 0; i < providersToResolve.length; i++) {
        final p = providersToResolve[i];
        debugPrint('$_tag:   ${i + 1}. ${p.source} (${p.quality})');
      }
      debugPrint('');

      final resolvedStream = await StreamResolverService.resolveBestSource(
        providersToResolve,
      );

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
      final urlPreview = resolvedStream.url.substring(0, resolvedStream.url.length > 100 ? 100 : resolvedStream.url.length);
      debugPrint('$_tag: 📡 URL: $urlPreview...');
      debugPrint('');

      // Return playable stream data
      return {
        'streamUrl': resolvedStream.url,
        'source': resolvedStream.source,
        'type': resolvedStream.type,
        'quality': resolvedStream.quality,
        'method': 'stremio_webview',
        'message': 'Stream resolved from ${resolvedStream.source}',
        'headers': resolvedStream.headers,
        'isPlayable': resolvedStream.isPlayable,
      };
    } catch (e) {
      debugPrint('$_tag: ❌ FATAL ERROR: $e');
      return null;
    }
  }

  /// Get all available Stremio providers
  static Future<List<StreamProvider>> getAvailableProviders(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      if (isMovie) {
        return await StremioProviderService.getMovieStreams(tmdbId);
      } else {
        return await StremioProviderService.getSeriesStreams(
          tmdbId,
          season,
          episode,
        );
      }
    } catch (e) {
      debugPrint('$_tag: Error getting providers: $e');
      return [];
    }
  }

  /// Verify and get only working providers
  static Future<List<StreamProvider>> getWorkingProviders(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      final providers = await getAvailableProviders(
        tmdbId,
        isMovie,
        season: season,
        episode: episode,
      );

      if (providers.isEmpty) {
        return [];
      }

      return await StremioProviderService.getWorkingProviders(providers);
    } catch (e) {
      debugPrint('$_tag: Error verifying providers: $e');
      return [];
    }
  }

  /// Health check - verify Stremio providers are available
  static Future<Map<String, bool>> checkHealth() async {
    try {
      // Test with a popular movie (The Shawshank Redemption - TMDB ID: 278)
      final providers = await StremioProviderService.getMovieStreams('278');
      final isHealthy = providers.isNotEmpty;
      return {
        'stremio_providers': isHealthy,
        'overall': isHealthy,
      };
    } catch (e) {
      debugPrint('$_tag: Health check error: $e');
      return {'stremio_providers': false, 'overall': false};
    }
  }

  /// Clear all caches
  static Future<void> clearCaches() async {
    try {
      await StreamResolverService.clearCache();
      debugPrint('$_tag: Caches cleared');
    } catch (e) {
      debugPrint('$_tag: Cache clear error: $e');
    }
  }

  /// Dispose and cleanup resources
  static Future<void> dispose() async {
    try {
      await StremioProviderService.resetConnections();
      await StremioProviderService.dispose();
      await StreamResolverService.dispose();
      debugPrint('$_tag: All services disposed');
    } catch (e) {
      debugPrint('$_tag: Dispose error: $e');
    }
  }

  /// Initialize required services
  static Future<void> initialize() async {
    try {
      debugPrint('$_tag: Initializing services...');
      await StreamResolverService.initialize();
      debugPrint('$_tag: Services initialized');
    } catch (e) {
      debugPrint('$_tag: Initialization error: $e');
    }
  }
}
