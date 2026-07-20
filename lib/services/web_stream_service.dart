import 'package:flutter/foundation.dart';

/// Web-compatible stream resolution service.
/// Returns embed URLs for iframe playback. No CORS-blocked HTTP checks.
class WebStreamService {
  static const String _tag = 'WebStreamService';

  /// Embed sources that work in browsers via iframe.
  static const List<Map<String, String>> _embedSources = [
    {
      'name': 'VidLink',
      'movieUrl': 'https://vidlink.pro/movie/{id}',
      'tvUrl': 'https://vidlink.pro/tv/{id}/{season}/{episode}',
    },
    {
      'name': 'MultiEmbed',
      'movieUrl': 'https://multiembed.mov/?video_id={id}&tmdb=1',
      'tvUrl': 'https://multiembed.mov/?video_id={id}&tmdb=1&season={season}&episode={episode}',
    },
    {
      'name': 'VidStreaming',
      'movieUrl': 'https://vidstreaming.io/movie/{id}',
      'tvUrl': 'https://vidstreaming.io/tv/{id}/{season}/{episode}',
    },
  ];

  /// Resolve a stream URL for web playback.
  /// Returns an embed URL that can be loaded in an iframe.
  /// No HTTP verification - let the iframe handle loading.
  static Future<Map<String, dynamic>?> resolveStream({
    required String tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
    String title = '',
  }) async {
    debugPrint('$_tag: Resolving TMDB $tmdbId (movie=$isMovie)');

    if (tmdbId.isEmpty) {
      debugPrint('$_tag: Empty TMDB ID');
      return null;
    }

    // Return first embed source - no CORS-blocked HTTP checks
    final source = _embedSources.first;
    final url = isMovie
        ? source['movieUrl']!.replaceAll('{id}', tmdbId)
        : source['tvUrl']!
            .replaceAll('{id}', tmdbId)
            .replaceAll('{season}', season.toString())
            .replaceAll('{episode}', episode.toString());

    debugPrint('$_tag: Returning embed URL from ${source['name']}: $url');

    return {
      'url': url,
      'source': source['name'],
      'type': 'embed',
      'headers': <String, String>{},
      'isEmbed': true,
    };
  }

  /// Get all available embed sources for server picker.
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
