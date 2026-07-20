import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Web stream resolution service.
/// Calls Cloudflare Worker API to extract actual .m3u8 URLs server-side.
/// No CORS issues, no iframes, no ads.
class WebStreamService {
  static const String _tag = 'WebStreamService';

  // TODO: Replace with your actual Cloudflare Worker URL after deployment
  static const String _workerUrl = 'https://maxstream-extractor.your-subdomain.workers.dev';

  /// Resolve a stream URL for web playback.
  /// Calls the Cloudflare Worker to extract the actual .m3u8 URL.
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

    try {
      final url = '$_workerUrl/api/extract'
          '?tmdb_id=$tmdbId'
          '&is_movie=$isMovie'
          '&season=$season'
          '&episode=$episode';

      debugPrint('$_tag: Calling worker: $url');

      final client = HttpClient();
      try {
        final httpRequest = await client.getUrl(Uri.parse(url));
        final httpResponse = await httpRequest.close().timeout(
          const Duration(seconds: 15),
        );

        final body = await httpResponse.transform(utf8.decoder).join();
        debugPrint('$_tag: Worker response: $body');

        if (httpResponse.statusCode == 200) {
          final data = json.decode(body) as Map<String, dynamic>;
          if (data.containsKey('url')) {
            debugPrint('$_tag: Got stream URL: ${data['url']}');
            return {
              'url': data['url'] as String,
              'source': data['source'] as String? ?? 'Cloudflare Worker',
              'type': data['type'] as String? ?? 'hls',
              'headers': <String, String>{},
              'isEmbed': false,
            };
          }
        } else {
          debugPrint('$_tag: Worker returned ${httpResponse.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('$_tag: Worker call failed: $e');
    }

    // Fallback: return embed URL if worker is unavailable
    debugPrint('$_tag: Worker unavailable, returning embed URL fallback');
    return _fallbackEmbedUrl(tmdbId, isMovie, season, episode);
  }

  /// Fallback: return embed URL if worker is down
  static Map<String, dynamic>? _fallbackEmbedUrl(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) {
    final url = isMovie
        ? 'https://vidlink.pro/movie/$tmdbId'
        : 'https://vidlink.pro/tv/$tmdbId/$season/$episode';

    return {
      'url': url,
      'source': 'VidLink (embed)',
      'type': 'embed',
      'headers': <String, String>{},
      'isEmbed': true,
    };
  }

  /// Get all available embed sources for server picker.
  static List<Map<String, String>> getEmbedSources() {
    return [
      {'name': 'VidLink', 'url': 'https://vidlink.pro'},
      {'name': 'MultiEmbed', 'url': 'https://multiembed.mov'},
    ];
  }
}
