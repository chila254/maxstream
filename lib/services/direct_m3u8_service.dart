import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'phone_scraper_service.dart';

/// Resolves movie and episode playback sources from TMDB metadata.
class DirectM3u8Service {
  static const String _tag = 'DirectM3u8Service';

  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Browser-based fallback sources. These are loaded by the WebView player when
  /// a direct HLS/MP4 URL cannot be resolved ahead of time.
  static const List<Map<String, String>> _embedSources = [
    {
      'name': 'VidLink',
      'movieUrl': 'https://vidlink.pro/movie/{id}',
      'tvUrl': 'https://vidlink.pro/tv/{id}/{season}/{episode}',
    },
    {
      'name': 'VidsrcRu',
      'movieUrl': 'https://vidsrc.ru/movie/{id}',
      'tvUrl': 'https://vidsrc.ru/tv/{id}/{season}/{episode}',
    },
    {
      'name': 'VidsrcNet',
      'movieUrl': 'https://vidsrc-embed.ru/embed/movie?tmdb={id}',
      'tvUrl':
          'https://vidsrc-embed.ru/embed/tv?tmdb={id}&season={season}&episode={episode}',
    },
    {
      'name': '2Embed',
      'movieUrl': 'https://www.2embed.cc/embed/{id}',
      'tvUrl': 'https://www.2embed.cc/embedtv/{id}&s={season}&e={episode}',
    },
    {
      'name': 'Remotestream',
      'movieUrl': 'https://remotestream.click/embed/movie?id={id}',
      'tvUrl':
          'https://remotestream.click/embed/tv?id={id}&s={season}&e={episode}',
    },
  ];

  /// Fetch a direct HLS/MP4 stream for a movie when an API exposes one.
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
    ];

    return _firstWorking(attempts);
  }

  /// Fetch a direct HLS/MP4 stream for a TV episode when an API exposes one.
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
    ];

    return _firstWorking(attempts);
  }

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

  static Future<Map<String, dynamic>?> _fetchVidflixApi({
    required String apiUrl,
    required String referer,
  }) async {
    final dio = PhoneScraperService.getDioClient(
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

  static Future<Map<String, dynamic>?> _fetchPrimeSrcLinks({
    required String serversUrl,
  }) async {
    final dio = PhoneScraperService.getDioClient(
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
      final dio = PhoneScraperService.getDioClient(
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

  /// Get browser fallback sources for movies/TV shows.
  static List<Map<String, String>> getEmbedSources() {
    return List<Map<String, String>>.from(_embedSources);
  }

  /// Generate an embed URL for a movie.
  static String generateMovieEmbedUrl(String tmdbId, String sourceName) {
    final source = _embedSources.firstWhere(
      (source) => source['name'] == sourceName,
      orElse: () => _embedSources.first,
    );
    return source['movieUrl']!.replaceAll('{id}', tmdbId);
  }

  /// Generate an embed URL for a TV episode.
  static String generateTvEmbedUrl(
    String tmdbId,
    int season,
    int episode,
    String sourceName,
  ) {
    final source = _embedSources.firstWhere(
      (source) => source['name'] == sourceName,
      orElse: () => _embedSources.first,
    );
    return source['tvUrl']!
        .replaceAll('{id}', tmdbId)
        .replaceAll('{season}', season.toString())
        .replaceAll('{episode}', episode.toString());
  }
}
