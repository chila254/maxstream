import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Represents a stream provider source
class StreamProvider {
  final String url;
  final String quality;
  final String source;
  final String? seeders;
  final String? type;

  StreamProvider({
    required this.url,
    required this.quality,
    required this.source,
    this.seeders,
    this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'quality': quality,
      'source': source,
      'seeders': seeders,
      'type': type,
    };
  }
}

/// Stremio Provider Service
/// Fetches streaming sources from Stremio ecosystem addons
class StremioProviderService {
  static const String _tag = 'StremioProviderService';

  static final Dio _dio = Dio(
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

  /// Stream providers (embed URLs + direct sources)
  static const Map<String, String> _providers = {
    'vidsrc_me': 'https://vidsrc.me/embed',
    'vidsrc_icu': 'https://vidsrc.icu/embed',
    'vidsrc_pro': 'https://vidsrc.pro/embed',
    'moviesapi': 'https://moviesapi.club/embed',
  };

  /// Get movie streams from Stremio providers
  static Future<List<StreamProvider>> getMovieStreams(String tmdbId) async {
    try {
      debugPrint('');
      debugPrint('$_tag: ═══════════════════════════════════════════');
      debugPrint('$_tag: Discovering Stremio providers for movie');
      debugPrint('$_tag: TMDB ID: $tmdbId');
      debugPrint('$_tag: ═══════════════════════════════════════════');

      final providers = <StreamProvider>[];

      // Try each provider
      for (final entry in _providers.entries) {
        try {
          final url = '${entry.value}/movie/$tmdbId';
          debugPrint('$_tag: [${entry.key}] Testing: $url');
          debugPrint('$_tag: Making HEAD request to: $url');

          // Verify provider is reachable
          final response = await _dio.head(
            url,
            options: Options(validateStatus: (status) => status! < 500),
          );

          if (response.statusCode! < 400) {
            // Determine quality based on provider
            String quality;
            if (entry.key.contains('pro')) {
              quality = '1080p';
            } else if (entry.key.contains('icu')) {
              quality = '720p';
            } else {
              quality = '720p';
            }

            providers.add(
              StreamProvider(
                url: url,
                quality: quality,
                source: _formatSourceName(entry.key),
                type: 'embed',
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
          if (e is DioException) {
            debugPrint('$_tag: DioException details:');
            debugPrint('$_tag:   Type: ${e.type}');
            debugPrint('$_tag:   Message: ${e.message}');
            debugPrint('$_tag:   Response: ${e.response}');
            debugPrint('$_tag:   Error: ${e.error}');
          }
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
    }
  }

  /// Get series streams from Stremio providers
  static Future<List<StreamProvider>> getSeriesStreams(
    String tmdbId,
    int season,
    int episode,
  ) async {
    try {
      debugPrint(
        '$_tag: Fetching streams for series $tmdbId S$season E$episode',
      );

      final providers = <StreamProvider>[];

      // Try each provider
      for (final entry in _providers.entries) {
        try {
          final url = '${entry.value}/tv/$tmdbId/$season/$episode';
          debugPrint('$_tag: Attempting provider: ${entry.key}');
          debugPrint('$_tag: Making HEAD request to: $url');

          // Verify provider is reachable
          final response = await _dio.head(
            url,
            options: Options(validateStatus: (status) => status! < 500),
          );

          if (response.statusCode! < 400) {
            // Determine quality based on provider
            String quality;
            if (entry.key.contains('pro')) {
              quality = '1080p';
            } else if (entry.key.contains('icu')) {
              quality = '720p';
            } else {
              quality = '720p';
            }

            providers.add(
              StreamProvider(
                url: url,
                quality: quality,
                source: _formatSourceName(entry.key),
                type: 'embed',
              ),
            );

            debugPrint('$_tag: ✓ Provider ${entry.key} is available');
          }
          } catch (e) {
          debugPrint('$_tag: Provider ${entry.key} failed: $e');
          if (e is DioException) {
            debugPrint('$_tag: DioException details:');
            debugPrint('$_tag:   Type: ${e.type}');
            debugPrint('$_tag:   Message: ${e.message}');
            debugPrint('$_tag:   Response: ${e.response}');
            debugPrint('$_tag:   Error: ${e.error}');
          }
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
    }
  }

  /// Format provider name for display
  static String _formatSourceName(String providerKey) {
    return providerKey
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get best quality provider
  static StreamProvider? getBestProvider(List<StreamProvider> providers) {
    if (providers.isEmpty) return null;

    final qualityMap = {'1080p': 5, '720p': 4, '480p': 3, '360p': 2, 'auto': 1};

    StreamProvider best = providers.first;
    int bestScore = qualityMap[providers.first.quality] ?? 0;

    for (final provider in providers) {
      final score = qualityMap[provider.quality] ?? 0;
      if (score > bestScore) {
        bestScore = score;
        best = provider;
      }
    }

    return best;
  }

  /// Verify provider is working
  static Future<bool> verifyProvider(StreamProvider provider) async {
    try {
      final response = await _dio.head(
        provider.url,
        options: Options(validateStatus: (status) => status! < 500),
      );

      return response.statusCode! < 400;
    } catch (e) {
      debugPrint('$_tag: Provider verification failed: $e');
      return false;
    }
  }

  /// Get working providers only
  static Future<List<StreamProvider>> getWorkingProviders(
    List<StreamProvider> providers, {
    int maxConcurrent = 3,
  }) async {
    try {
      debugPrint('$_tag: Verifying ${providers.length} providers...');

      final working = <StreamProvider>[];
      final futures = <Future<bool>>[];

      for (int i = 0; i < providers.length; i += maxConcurrent) {
        final batch = providers.sublist(
          i,
          i + maxConcurrent > providers.length
              ? providers.length
              : i + maxConcurrent,
        );

        for (final provider in batch) {
          futures.add(
            verifyProvider(provider).then((isWorking) {
              if (isWorking) {
                working.add(provider);
              }
              return isWorking;
            }),
          );
        }

        await Future.wait(futures);
        futures.clear();
      }

      debugPrint(
        '$_tag: ${working.length}/${providers.length} providers are working',
      );
      return working;
    } catch (e) {
      debugPrint('$_tag: Error verifying providers: $e');
      return providers;
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      debugPrint('$_tag: Disposing service...');
      _dio.close();
      debugPrint('$_tag: Service disposed');
    } catch (e) {
      debugPrint('$_tag: Error disposing: $e');
    }
  }
}
