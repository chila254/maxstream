import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Web stream resolution service.
/// Calls Cloudflare Worker API to extract actual .m3u8 URLs server-side.
class WebStreamService {
  static const String _tag = 'WebStreamService';
  static const String _workerUrl =
      'https://maxstream-extractor.maxstream123.workers.dev';

  /// All available servers
  static const List<Map<String, String>> servers = [
    {
      'name': 'VixSrc',
      'id': 'vixsrc',
      'movieUrl': 'https://vixsrc.to/api/movie/{id}?lang=en',
      'tvUrl': 'https://vixsrc.to/api/tv/{id}/{season}/{episode}?lang=en',
    },
    {
      'name': 'VidLink',
      'id': 'vidlink',
      'movieUrl': 'https://vidlink.pro/movie/{id}',
      'tvUrl': 'https://vidlink.pro/tv/{id}/{season}/{episode}',
    },
    {
      'name': '2Embed',
      'id': '2embed',
      'movieUrl': 'https://www.2embed.cc/embed/{id}',
      'tvUrl': 'https://www.2embed.cc/embedtv/{id}&s={season}&e={episode}',
    },
  ];

  /// Resolve a stream URL from a specific server.
  static Future<Map<String, dynamic>?> resolveFromServer({
    required String serverId,
    required String tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
  }) async {
    debugPrint('$_tag: Resolving from $serverId for TMDB $tmdbId');

    try {
      final url =
          '$_workerUrl/api/extract'
          '?tmdb_id=$tmdbId'
          '&is_movie=$isMovie'
          '&season=$season'
          '&episode=$episode'
          '&server=$serverId';

      debugPrint('$_tag: Calling worker: $url');

      final response = await http
          .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      debugPrint('$_tag: Worker response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final streamUrl = data['url']?.toString() ?? '';
        if (streamUrl.isNotEmpty) {
          return {
            'url': streamUrl,
            'source': data['source'] as String? ?? serverId,
            'type': data['type'] as String? ?? 'hls',
            'headers': <String, String>{},
            'isEmbed': (data['type'] as String?) == 'embed',
          };
        }
      }
    } catch (e) {
      debugPrint('$_tag: Worker call failed: $e');
    }

    return null;
  }

  /// Resolve a stream URL trying all servers in order.
  static Future<Map<String, dynamic>?> resolveStream({
    required String tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
    String title = '',
  }) async {
    // Try each server in order
    for (final server in servers) {
      final result = await resolveFromServer(
        serverId: server['id']!,
        tmdbId: tmdbId,
        isMovie: isMovie,
        season: season,
        episode: episode,
      );
      if (result != null) {
        debugPrint('$_tag: Success with ${server['name']}');
        return result;
      }
    }

    // Fallback: return VidLink embed URL
    debugPrint('$_tag: All servers failed, using embed fallback');
    final embedUrl = isMovie
        ? 'https://vidlink.pro/movie/$tmdbId'
        : 'https://vidlink.pro/tv/$tmdbId/$season/$episode';
    return {
      'url': embedUrl,
      'source': 'VidLink',
      'type': 'embed',
      'headers': <String, String>{},
      'isEmbed': true,
    };
  }

  /// Get server list for UI picker.
  static List<Map<String, String>> getServerList() {
    return servers.map((s) => {
      'name': s['name']!,
      'id': s['id']!,
    }).toList();
  }
}
