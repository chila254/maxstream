import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Resolves movie and episode playback sources from TMDB metadata.
/// Uses multiple API sources with automatic fallback, similar to how
/// streamflix resolves streams via its Provider/Extractor pipeline.
class DirectM3u8Service {
  static const String _tag = 'DirectM3u8Service';

  static Dio _getDioClient({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, String>? customHeaders,
  }) {
    return Dio(
      BaseOptions(
        connectTimeout: connectTimeout ?? const Duration(seconds: 15),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 15),
        sendTimeout: sendTimeout ?? const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate, br',
          'Referer': 'https://www.google.com/',
          ...?customHeaders,
        },
        followRedirects: true,
        maxRedirects: 5,
      ),
    );
  }

  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // ── Public API ──────────────────────────────────────────────────────────

  /// Fetch a direct HLS/MP4 stream for a movie.
  static Future<Map<String, dynamic>?> fetchMovieStreamUrl(
    String title,
    int? year,
    String? tmdbId,
  ) async {
    final id = tmdbId?.trim();
    if (id == null || id.isEmpty) return null;

    debugPrint('$_tag: Resolving movie stream for $title (TMDB: $id)');

    final attempts = <Future<Map<String, dynamic>?> Function()>[
      () => _fetchVidflixApi(
        apiUrl: 'https://vidflix.club/api/movie/$id',
        referer: 'https://vidflix.club/movie/$id',
      ),
      () => _fetchPrimeSrcLinks(
        serversUrl: 'https://primesrc.me/api/v1/s?tmdb=$id&type=movie',
      ),
      () => _fetchVidrockApi(tmdbId: id, type: 'movie'),
      () => _fetchRemotestreamApi(tmdbId: id, type: 'movie'),
    ];

    return _firstWorking(attempts);
  }

  /// Fetch a direct HLS/MP4 stream for a TV episode.
  static Future<Map<String, dynamic>?> fetchSeriesStreamUrl(
    String title,
    int season,
    int episode,
    String? tmdbId,
  ) async {
    final id = tmdbId?.trim();
    if (id == null || id.isEmpty) return null;

    debugPrint(
      '$_tag: Resolving episode stream for $title S$season E$episode (TMDB: $id)',
    );

    final attempts = <Future<Map<String, dynamic>?> Function()>[
      () => _fetchVidflixApi(
        apiUrl: 'https://vidflix.club/api/tv/$id/$season/$episode',
        referer: 'https://vidflix.club/tv/$id/$season/$episode',
      ),
      () => _fetchPrimeSrcLinks(
        serversUrl:
            'https://primesrc.me/api/v1/s?tmdb=$id&season=$season&episode=$episode&type=tv',
      ),
      () => _fetchVidrockApi(
        tmdbId: id,
        type: 'tv',
        season: season,
        episode: episode,
      ),
      () => _fetchRemotestreamApi(
        tmdbId: id,
        type: 'tv',
        season: season,
        episode: episode,
      ),
    ];

    return _firstWorking(attempts);
  }

  // ── Source resolvers (each returns a playable URL or null) ──────────────

  /// VidFlix API — returns a JSON object with an embedded m3u8/mp4 URL.
  static Future<Map<String, dynamic>?> _fetchVidflixApi({
    required String apiUrl,
    required String referer,
  }) async {
    final dio = _getDioClient(
      receiveTimeout: const Duration(seconds: 12),
      customHeaders: {..._browserHeaders, 'Referer': referer},
    );

    final response = await dio.get<dynamic>(apiUrl);
    if (!_isSuccess(response.statusCode)) return null;

    final candidate = _findPlayableUrl(response.data);
    return _buildResult(
      candidate,
      source: 'Vidflix',
      headers: {..._browserHeaders, 'Referer': referer},
    );
  }

  /// PrimeSrc API — fetches server list, then resolves each server key.
  static Future<Map<String, dynamic>?> _fetchPrimeSrcLinks({
    required String serversUrl,
  }) async {
    final dio = _getDioClient(
      receiveTimeout: const Duration(seconds: 12),
      customHeaders: {..._browserHeaders, 'Referer': 'https://primesrc.me/'},
    );

    final serversResponse = await dio.get<dynamic>(serversUrl);
    if (!_isSuccess(serversResponse.statusCode)) return null;

    final serverKeys = _extractPrimeSrcServerKeys(serversResponse.data);
    for (final key in serverKeys) {
      try {
        final linkResponse = await dio.get<dynamic>(
          'https://primesrc.me/api/v1/l?key=$key',
        );
        if (!_isSuccess(linkResponse.statusCode)) continue;

        final candidate = _findPlayableUrl(linkResponse.data);
        final result = await _buildResult(
          candidate,
          source: 'PrimeSrc',
          headers: {..._browserHeaders, 'Referer': 'https://primesrc.me/'},
        );
        if (result != null) return result;
      } catch (e) {
        debugPrint('$_tag: PrimeSrc server failed: $e');
      }
    }

    return null;
  }

  /// Vidrock API — scrapes the embed page for an m3u8 URL.
  static Future<Map<String, dynamic>?> _fetchVidrockApi({
    required String tmdbId,
    required String type,
    int season = 1,
    int episode = 1,
  }) async {
    final path = type == 'movie'
        ? 'https://vidrock.net/movie/$tmdbId'
        : 'https://vidrock.net/tv/$tmdbId/$season/$episode';

    final dio = _getDioClient(
      receiveTimeout: const Duration(seconds: 12),
      customHeaders: {
        ..._browserHeaders,
        'Referer': 'https://vidrock.net/',
      },
    );

    try {
      final response = await dio.get<String>(path);
      if (!_isSuccess(response.statusCode) || response.data == null) return null;

      // Look for m3u8 URL in page source
      final m3u8Match = RegExp(
        'https?://[^\\s"\'<>]+\\.m3u8[^\\s"\'<>]*',
      ).firstMatch(response.data!);

      if (m3u8Match != null) {
        final url = _normalizeUrl(m3u8Match.group(0));
        if (url != null) {
          return await _buildResult(
            url,
            source: 'Vidrock',
            headers: {..._browserHeaders, 'Referer': 'https://vidrock.net/'},
          );
        }
      }

      // Try to find an iframe src pointing to an embed
      final iframeMatch = RegExp(
        r'''src=["']([^"']*(?:embed|stream)[^"']*)["']''',
      ).firstMatch(response.data!);

      if (iframeMatch != null) {
        final embedUrl = iframeMatch.group(1)!;
        final resolved = embedUrl.startsWith('http')
            ? embedUrl
            : 'https://vidrock.net$embedUrl';
        final embedResponse = await dio.get<String>(resolved);
        if (_isSuccess(embedResponse.statusCode) && embedResponse.data != null) {
          final embedM3u8 = RegExp(
            'https?://[^\\s"\'<>]+\\.m3u8[^\\s"\'<>]*',
          ).firstMatch(embedResponse.data!);
          if (embedM3u8 != null) {
            final url = _normalizeUrl(embedM3u8.group(0));
            if (url != null) {
              return await _buildResult(
                url,
                source: 'Vidrock',
                headers: {
                  ..._browserHeaders,
                  'Referer': resolved,
                },
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('$_tag: Vidrock API failed: $e');
    }

    return null;
  }

  /// Remotestream API — fetches embed page for direct stream URL.
  static Future<Map<String, dynamic>?> _fetchRemotestreamApi({
    required String tmdbId,
    required String type,
    int season = 1,
    int episode = 1,
  }) async {
    final path = type == 'movie'
        ? 'https://remotestream.click/embed/movie?id=$tmdbId'
        : 'https://remotestream.click/embed/tv?id=$tmdbId&s=$season&e=$episode';

    final dio = _getDioClient(
      receiveTimeout: const Duration(seconds: 12),
      customHeaders: {
        ..._browserHeaders,
        'Referer': 'https://remotestream.click/',
      },
    );

    try {
      final response = await dio.get<String>(path);
      if (!_isSuccess(response.statusCode) || response.data == null) return null;

      // Look for m3u8 URL in the page or in script tags
      final m3u8Match = RegExp(
        'https?://[^\\s"\'<>]+\\.m3u8[^\\s"\'<>]*',
      ).firstMatch(response.data!);

      if (m3u8Match != null) {
        final url = _normalizeUrl(m3u8Match.group(0));
        if (url != null) {
          return await _buildResult(
            url,
            source: 'Remotestream',
            headers: {
              ..._browserHeaders,
              'Referer': 'https://remotestream.click/',
            },
          );
        }
      }
    } catch (e) {
      debugPrint('$_tag: Remotestream API failed: $e');
    }

    return null;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> _firstWorking(
    List<Future<Map<String, dynamic>?> Function()> attempts,
  ) async {
    for (final attempt in attempts) {
      try {
        final result = await attempt();
        if (result != null) return result;
      } catch (e) {
        debugPrint('$_tag: Resolver attempt failed: $e');
      }
    }
    return null;
  }

  static List<String> _extractPrimeSrcServerKeys(dynamic data) {
    if (data is! Map) return const [];
    final servers = data['servers'];
    if (servers is! List) return const [];

    return servers
        .whereType<Map>()
        .map((server) => server['key']?.toString() ?? '')
        .where((key) => key.isNotEmpty)
        .toList();
  }

  static Future<Map<String, dynamic>?> _buildResult(
    String? url, {
    required String source,
    required Map<String, String> headers,
  }) async {
    final normalized = _normalizeUrl(url);
    if (normalized == null || !_isDirectVideoUrl(normalized)) return null;

    if (!await _verifyVideoUrl(normalized, headers: headers)) return null;

    return {
      'url': normalized,
      'source': source,
      'type': normalized.contains('.m3u8') ? 'direct_m3u8' : 'direct_video',
      'headers': headers,
      'isPlayable': true,
    };
  }

  static String? _findPlayableUrl(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final directMatch = RegExp(
        r'''https?:\/\/[^\s"'<>]+\.(?:m3u8|mp4)(?:[^\s"'<>]*)?''',
        caseSensitive: false,
      ).firstMatch(value);
      if (directMatch != null) return directMatch.group(0);

      if (value.startsWith('http')) return value;
      return null;
    }

    if (value is List) {
      for (final item in value) {
        final found = _findPlayableUrl(item);
        if (found != null) return found;
      }
      return null;
    }

    if (value is Map) {
      const priorityKeys = [
        'playlist',
        'source',
        'file',
        'url',
        'video_url',
        'link',
      ];

      for (final key in priorityKeys) {
        if (!value.containsKey(key)) continue;
        final found = _findPlayableUrl(value[key]);
        if (found != null) return found;
      }

      for (final entry in value.entries) {
        if (priorityKeys.contains(entry.key)) continue;
        final found = _findPlayableUrl(entry.value);
        if (found != null) return found;
      }
    }

    return null;
  }

  static String? _normalizeUrl(String? url) {
    if (url == null) return null;
    var normalized = url.trim();
    if (normalized.isEmpty) return null;

    normalized = normalized
        .replaceAll(r'\/', '/')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'''^["']+|["']+$'''), '');

    if (normalized.startsWith('//')) return 'https:$normalized';
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      return null;
    }
    return normalized;
  }

  static bool _isDirectVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('.mp4');
  }

  static Future<bool> _verifyVideoUrl(
    String url, {
    required Map<String, String> headers,
  }) async {
    try {
      final dio = _getDioClient(
        receiveTimeout: const Duration(seconds: 6),
        customHeaders: headers,
      );

      final response = await dio
          .head(url)
          .timeout(const Duration(seconds: 6))
          .catchError((_) {
            return dio.get<dynamic>(
              url,
              options: Options(responseType: ResponseType.bytes),
            );
          });

      return _isSuccess(response.statusCode) || response.statusCode == 206;
    } catch (e) {
      debugPrint('$_tag: Video URL verification failed: $e');
      return false;
    }
  }

  static bool _isSuccess(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 400;
  }
}
