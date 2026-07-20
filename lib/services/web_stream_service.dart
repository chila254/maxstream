import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Web-compatible stream resolution service.
/// Uses embed URLs and direct HTTP requests instead of native extractors.
class WebStreamService {
  static const String _tag = 'WebStreamService';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  /// Embed sources that work in browsers via iframe/HTML5 video.
  static const List<Map<String, String>> _embedSources = [
    {
      'name': 'VidLink',
      'movieUrl': 'https://vidlink.pro/movie/{id}',
      'tvUrl': 'https://vidlink.pro/tv/{id}/{season}/{episode}',
    },
    {
      'name': 'VidStreaming',
      'movieUrl': 'https://vidstreaming.io/movie/{id}',
      'tvUrl': 'https://vidstreaming.io/tv/{id}/{season}/{episode}',
    },
  ];

  /// Resolve a stream URL for web playback.
  /// Returns an embed URL that can be loaded in an iframe or web view.
  static Future<Map<String, dynamic>?> resolveStream({
    required String tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
    String title = '',
  }) async {
    debugPrint('$_tag: Resolving TMDB $tmdbId (movie=$isMovie)');

    // Try each embed source
    for (final source in _embedSources) {
      try {
        final url = isMovie
            ? source['movieUrl']!.replaceAll('{id}', tmdbId)
            : source['tvUrl']!
                .replaceAll('{id}', tmdbId)
                .replaceAll('{season}', season.toString())
                .replaceAll('{episode}', episode.toString());

        // Verify the URL is accessible
        final response = await http.head(
          Uri.parse(url),
          headers: {'User-Agent': _userAgent},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 302) {
          debugPrint('$_tag: Found stream from ${source['name']}: $url');
          return {
            'url': url,
            'source': source['name'],
            'type': 'embed',
            'headers': <String, String>{},
            'isEmbed': true,
          };
        }
      } catch (e) {
        debugPrint('$_tag: ${source['name']} failed: $e');
        continue;
      }
    }

    // Fallback: try to find a direct HLS stream via TMDB metadata
    try {
      final hlsUrl = await _tryDirectHls(tmdbId, isMovie, season, episode);
      if (hlsUrl != null) {
        return {
          'url': hlsUrl,
          'source': 'Direct HLS',
          'type': 'direct_m3u8',
          'headers': <String, String>{},
          'isEmbed': false,
        };
      }
    } catch (e) {
      debugPrint('$_tag: Direct HLS failed: $e');
    }

    debugPrint('$_tag: No stream found for TMDB $tmdbId');
    return null;
  }

  /// Try to find a direct HLS stream URL.
  static Future<String?> _tryDirectHls(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    // This is a placeholder for direct HLS extraction.
    // In production, you'd implement the actual extraction logic here
    // using pure Dart HTTP requests.
    return null;
  }

  /// Get all available embed sources for manual selection.
  static List<Map<String, String>> getEmbedSources() =>
      List.from(_embedSources);

  /// Generate an embed URL for a specific source.
  static String generateEmbedUrl({
    required String tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
    required String sourceName,
  }) {
    final source = _embedSources.firstWhere(
      (s) => s['name'] == sourceName,
      orElse: () => _embedSources.first,
    );

    return isMovie
        ? source['movieUrl']!.replaceAll('{id}', tmdbId)
        : source['tvUrl']!
            .replaceAll('{id}', tmdbId)
            .replaceAll('{season}', season.toString())
            .replaceAll('{episode}', episode.toString());
  }
}
