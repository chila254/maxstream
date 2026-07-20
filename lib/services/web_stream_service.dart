import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Web stream resolution service.
/// Calls Cloudflare Worker API to extract actual .m3u8 URLs server-side.
/// No CORS issues, no iframes, no ads.
class WebStreamService {
  static const String _tag = 'WebStreamService';

  // TODO: Replace with your actual Cloudflare Worker URL after deployment
  static const String _workerUrl =
      'https://maxstream-extractor.maxstream123.workers.dev';

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
      final url =
          '$_workerUrl/api/extract'
          '?tmdb_id=$tmdbId'
          '&is_movie=$isMovie'
          '&season=$season'
          '&episode=$episode';

      debugPrint('$_tag: Calling worker: $url');

      final response = await http
          .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      debugPrint('$_tag: Worker response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final streamUrl = data['url']?.toString() ?? '';
        if (streamUrl.isNotEmpty) {
          debugPrint('$_tag: Got stream URL: $streamUrl');
          return {
            'url': streamUrl,
            'source': data['source'] as String? ?? 'Cloudflare Worker',
            'type': data['type'] as String? ?? 'hls',
            'headers': <String, String>{},
            'isEmbed': false,
          };
        }
      } else {
        debugPrint('$_tag: Worker returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('$_tag: Worker call failed: $e');
    }

    final embedUrl = isMovie
        ? 'https://vidlink.pro/movie/$tmdbId'
        : 'https://vidlink.pro/tv/$tmdbId/$season/$episode';
    debugPrint('$_tag: Using browser embed fallback: $embedUrl');
    return {
      'url': embedUrl,
      'source': 'VidLink',
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
