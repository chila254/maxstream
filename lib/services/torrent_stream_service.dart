import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service for extracting streams from torrent/magnet links
/// Supports legal torrent sources and conversion to streaming URLs
class TorrentStreamService {
  static const String _tag = 'TorrentStreamService';
  static final Dio _dio = Dio();

  // Torrent search and streaming providers
  static const Map<String, Map<String, String>> _providers = {
    'torrentio': {
      'name': 'Torrentio',
      'baseUrl': 'https://torrentio.strem.fun',
      'type': 'addon',
    },
    'jackett': {
      'name': 'Jackett',
      'baseUrl': 'http://localhost:9117',
      'type': 'indexer',
    },
  };

  static void _initializeDio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );
  }

  /// Extract streams from torrent using Stremio Torrentio addon
  /// Returns magnet links and stream metadata
  static Future<TorrentStreamResult> extractTorrentStreams(
    String tmdbId, {
    required bool isMovie,
    int season = 1,
    int episode = 1,
    String? searchQuery,
  }) async {
    _initializeDio();

    debugPrint(
      '$_tag: Starting torrent extraction for ${isMovie ? 'movie' : 'tv'} $tmdbId',
    );

    try {
      // Try Torrentio addon first
      final result = await _tryTorrentioProvider(
        tmdbId,
        isMovie,
        season: season,
        episode: episode,
        searchQuery: searchQuery,
      );

      if (result.success && result.magnets!.isNotEmpty) {
        debugPrint(
          '$_tag: ✓ Found ${result.magnets!.length} torrent sources',
        );
        return result;
      }

      debugPrint('$_tag: ✗ No torrent streams found');
      return TorrentStreamResult.failure('No torrent streams available');
    } catch (e) {
      debugPrint('$_tag: Torrent extraction error: $e');
      return TorrentStreamResult.failure('Torrent extraction failed: $e');
    }
  }

  /// Try Torrentio Stremio addon for torrent streams
  static Future<TorrentStreamResult> _tryTorrentioProvider(
    String tmdbId,
    bool isMovie, {
    required int season,
    required int episode,
    String? searchQuery,
  }) async {
    try {
      String endpoint;
      if (isMovie) {
        endpoint =
            '${_providers['torrentio']!['baseUrl']}/manifest.json';
      } else {
        endpoint =
            '${_providers['torrentio']!['baseUrl']}/stream/series/$tmdbId:$season:$episode.json';
      }

      debugPrint('$_tag: Torrentio request to: $endpoint');

      final response = await _dio.get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<dynamic, dynamic>;
        final streams = data['streams'] as List?;

        if (streams != null && streams.isNotEmpty) {
          final magnets = <TorrentMagnet>[];

          for (final stream in streams) {
            if (stream is Map) {
              final title = stream['title'] as String?;
              final url = stream['url'] as String?;

              if (url != null && url.startsWith('magnet:')) {
                magnets.add(
                  TorrentMagnet(
                    url: url,
                    title: title ?? 'Unknown',
                    quality: _extractQuality(title ?? ''),
                    seeders: _extractSeeders(title ?? ''),
                  ),
                );
              }
            }
          }

          // Sort by quality and seeders
          magnets.sort((a, b) {
            if (a.quality != b.quality) {
              return b.quality.compareTo(a.quality);
            }
            return b.seeders.compareTo(a.seeders);
          });

          return TorrentStreamResult.success(
            magnets: magnets,
            source: 'Torrentio',
          );
        }
      }

      return TorrentStreamResult.failure(
        'No streams from Torrentio',
      );
    } catch (e) {
      return TorrentStreamResult.failure(
        'Torrentio request failed: $e',
      );
    }
  }

  /// Extract quality from torrent title (1080p, 720p, etc.)
  static int _extractQuality(String title) {
    if (title.contains('2160p') || title.contains('4K')) return 2160;
    if (title.contains('1080p')) return 1080;
    if (title.contains('720p')) return 720;
    if (title.contains('480p')) return 480;
    if (title.contains('360p')) return 360;
    return 0;
  }

  /// Extract seeders count from title
  static int _extractSeeders(String title) {
    final seedMatch = RegExp(r'👤\s*(\d+)').firstMatch(title);
    if (seedMatch != null) {
      return int.tryParse(seedMatch.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  /// Get available torrent providers
  static List<Map<String, String>> getAvailableProviders() {
    return _providers.values.toList();
  }

  /// Test torrent provider connectivity
  static Future<bool> testProvider(String providerKey) async {
    try {
      final provider = _providers[providerKey];
      if (provider == null) return false;

      final response = await _dio.get(
        '${provider['baseUrl']}/manifest.json',
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('$_tag: Provider test failed: $e');
      return false;
    }
  }

  /// Dispose resources
  static void dispose() {
    _dio.close();
    debugPrint('$_tag: Service disposed');
  }
}

/// Torrent magnet link data
class TorrentMagnet {
  final String url;
  final String title;
  final int quality;
  final int seeders;

  const TorrentMagnet({
    required this.url,
    required this.title,
    required this.quality,
    required this.seeders,
  });

  @override
  String toString() => 'TorrentMagnet(title: $title, quality: ${quality}p, seeders: $seeders)';
}

/// Result class for torrent stream extraction
class TorrentStreamResult {
  final bool success;
  final List<TorrentMagnet>? magnets;
  final String? error;
  final String source;

  const TorrentStreamResult({
    required this.success,
    this.magnets,
    this.error,
    required this.source,
  });

  /// Create successful result
  factory TorrentStreamResult.success({
    required List<TorrentMagnet> magnets,
    required String source,
  }) {
    return TorrentStreamResult(
      success: true,
      magnets: magnets,
      source: source,
    );
  }

  /// Create failure result
  factory TorrentStreamResult.failure(String error) {
    return TorrentStreamResult(
      success: false,
      error: error,
      source: 'torrent',
    );
  }

  @override
  String toString() {
    return 'TorrentStreamResult(success: $success, magnets: ${magnets?.length ?? 0}, error: $error, source: $source)';
  }
}
