import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'stream_security.dart';

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
    {
      'name': 'Goodstream',
      'id': 'goodstream',
      'movieUrl': 'https://goodstream.one/movie/{id}',
      'tvUrl': 'https://goodstream.one/tv/{id}/{season}/{episode}',
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

      final response = await http
          .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final streamUrl = data['url']?.toString() ?? '';
        final streamUri = Uri.tryParse(streamUrl);
        final workerUri = Uri.parse(_workerUrl);
        final isWorkerMediaUrl =
            streamUri != null &&
            streamUri.scheme == 'https' &&
            streamUri.host == workerUri.host &&
            streamUri.path == '/api/media' &&
            streamUri.queryParameters.containsKey('token') &&
            streamUri.queryParameters.containsKey('sig');
        if (isWorkerMediaUrl && data['type'] == 'hls') {
          return StreamSecurity.sanitizeResolverResult({
            'url': streamUrl,
            'source': data['source'] as String? ?? serverId,
            'type': 'hls',
            'headers': <String, String>{},
          });
        }
        if (data['type'] == 'embed') {
          final embed = _sanitizeEmbedUrl(streamUrl);
          if (embed != null) {
            return StreamSecurity.sanitizeResolverResult({
              'url': embed,
              'source': data['source'] as String? ?? serverId,
              'type': 'embed',
              'headers': <String, String>{},
            });
          }
          debugPrint('$_tag: Worker returned an unsafe embed URL');
        } else {
          debugPrint(
            '$_tag: Worker returned an unsafe or unsupported stream URL',
          );
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

    debugPrint('$_tag: No direct streaming source was found');
    return null;
  }

  /// Get server list for UI picker.
  static List<Map<String, String>> getServerList() {
    return servers.map((s) => {'name': s['name']!, 'id': s['id']!}).toList();
  }

  /// Allowed hosts for embed player URLs. The embed page is loaded in an
  /// iframe in the user's browser, so the URL must point at a trusted,
  /// known player host over HTTPS.
  static const List<String> _embedAllowedHosts = [
    'vidlink.pro',
    'goodstream.one',
    'www.2embed.cc',
    '2embed.cc',
  ];

  static String? _sanitizeEmbedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme != 'https') return null;
    final host = uri.host.toLowerCase();
    if (!_embedAllowedHosts.any((allowed) => host == allowed || host.endsWith('.$allowed'))) {
      return null;
    }
    return uri.toString();
  }
}
