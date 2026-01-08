import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'stream_extraction_service.dart';

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

/// Embed playback configuration
class EmbedPlaybackConfig {
  final String url;
  final String quality;
  final String source;
  final String type; // 'embed'
  final String? embedUrl;

  EmbedPlaybackConfig({
    required this.url,
    required this.quality,
    required this.source,
    required this.type,
    this.embedUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'quality': quality,
      'source': source,
      'type': type,
      'embedUrl': embedUrl,
    };
  }
}

/// Unified Embed Discovery Service
/// Discovers and ranks embed URLs from Stremio providers
/// Does NOT resolve embeds to raw streams - embeds are loadable units
class EmbedDiscoveryService {
  static const String _tag = 'EmbedDiscoveryService';

  // Stremio providers
  static const Map<String, String> _providers = {
    'vidsrc_me': 'https://vidsrc.me/embed',
    'vidsrc_icu': 'https://vidsrc.icu/embed',
    'vidsrc_pro': 'https://vidsrc.pro/embed',
    'moviesapi': 'https://moviesapi.club/embed',
  };

  /// Main entry point: Get embed URL for movies/TV (no resolution needed)
  static Future<Map<String, dynamic>?> extractStream(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      debugPrint('');
      debugPrint('$_tag: ╔════════════════════════════════════════════╗');
      debugPrint('$_tag: ║       EMBED URL FETCH STARTED               ║');
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
      debugPrint('$_tag: Provider order (by quality):');
      for (int i = 0; i < providers.length; i++) {
        final p = providers[i];
        debugPrint('$_tag:   ${i + 1}. ${p.source} (${p.quality}) - ${p.url}');
      }
      debugPrint('');

      // Select best provider by quality
      providers.sort((a, b) {
        final qualityOrder = {'1080p': 0, '720p': 1, '480p': 2};
        final aRank = qualityOrder[a.quality] ?? 99;
        final bRank = qualityOrder[b.quality] ?? 99;
        return aRank.compareTo(bRank);
      });

      final bestProvider = providers.first;

      debugPrint('');
      debugPrint('$_tag: ╔════════════════════════════════════════════╗');
      debugPrint('$_tag: ║       EMBED URL READY ✓                     ║');
      debugPrint('$_tag: ╚════════════════════════════════════════════╝');
      debugPrint('$_tag: 📺 Source: ${bestProvider.source}');
      debugPrint('$_tag: 🎬 Quality: ${bestProvider.quality}');
      debugPrint('$_tag: 📡 Embed URL: ${bestProvider.url}');
      debugPrint('');

      return {
        'streamUrl': bestProvider.url,
        'source': bestProvider.source,
        'type': 'embed',
        'quality': bestProvider.quality,
        'embedUrl': bestProvider.url,
        'method': 'direct_embed',
        'message':
            'Using ${bestProvider.source} embed (${bestProvider.quality})',
        'isPlayable': true,
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
      // Check embed discovery
      final providers = await _getMovieStreams('278');
      final discoveryHealthy = providers.isNotEmpty;

      // Check stream extraction
      final extractionHealth = await StreamExtractionService.checkHealth();
      final extractionHealthy = extractionHealth['stream_extraction'] ?? false;

      final overall = discoveryHealthy && extractionHealthy;

      return {
        'discovery_service': discoveryHealthy,
        'stream_extraction': extractionHealthy,
        'overall': overall,
      };
    } catch (e) {
      debugPrint('$_tag: Health check error: $e');
      return {
        'discovery_service': false,
        'stream_extraction': false,
        'overall': false,
      };
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
      debugPrint('$_tag: Service disposed');
    } catch (e) {
      debugPrint('$_tag: Dispose error: $e');
    }
  }
}
