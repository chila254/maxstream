import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Resolves movie and episode playback sources from TMDB metadata.
/// Uses multiple extractors (VixSrc, Vidrock) with automatic fallback.
class DirectM3u8Service {
  static const String _tag = 'DirectM3u8Service';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
    },
    followRedirects: true,
    maxRedirects: 5,
  ));

  // ── Public API ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchMovieStreamUrl(
    String title,
    int? year,
    String? tmdbId,
  ) async {
    final id = tmdbId?.trim();
    if (id == null || id.isEmpty) return null;

    debugPrint('$_tag: Resolving movie stream for $title (TMDB: $id)');

    final attempts = <Future<Map<String, dynamic>?> Function()>[
      () => _extractVixSrc(tmdbId: id, type: 'movie'),
      () => _extractVidrock(tmdbId: id, type: 'movie'),
    ];

    return _firstWorking(attempts);
  }

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
      () => _extractVixSrc(
        tmdbId: id,
        type: 'tv',
        season: season,
        episode: episode,
      ),
      () => _extractVidrock(
        tmdbId: id,
        type: 'tv',
        season: season,
        episode: episode,
      ),
    ];

    return _firstWorking(attempts);
  }

  // ── VixSrc Extractor ────────────────────────────────────────────────────
  // Pure HTTP: API call → HTML script parsing → m3u8 playlist

  static const String _vixSrcBase = 'https://vixsrc.to';

  static Future<Map<String, dynamic>?> _extractVixSrc({
    required String tmdbId,
    required String type,
    int season = 1,
    int episode = 1,
  }) async {
    final apiPath = type == 'movie'
        ? 'api/movie/$tmdbId?lang=en'
        : 'api/tv/$tmdbId/$season/$episode?lang=en';

    final dio = Dio(_dio.options);
    dio.options.headers['Referer'] = _vixSrcBase;
    dio.options.headers['X-Requested-With'] = 'XMLHttpRequest';
    dio.options.headers['Accept'] = 'application/json, text/plain, */*';

    // Step 1: Call API to get embed path
    final apiResp = await dio.get<dynamic>('$_vixSrcBase/$apiPath');
    if (apiResp.statusCode != 200 || apiResp.data == null) return null;

    final apiData = apiResp.data;
    final embedPath = (apiData is Map ? apiData['src'] : null)?.toString();
    if (embedPath == null || embedPath.isEmpty) return null;

    debugPrint('$_tag: VixSrc embed path: $embedPath');

    // Step 2: Fetch embed page and parse script tags
    dio.options.headers['Accept'] =
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
    final embedResp = await dio.get<String>('$_vixSrcBase/$embedPath');
    if (embedResp.statusCode != 200 || embedResp.data == null) return null;

    final html = embedResp.data!;
    final scriptContent = _extractVixSrcScript(html);
    if (scriptContent == null) {
      debugPrint('$_tag: VixSrc: no script with window.video found');
      return null;
    }

    // Step 3: Extract video ID, token, expires from script
    final videoId = _extractBetween(scriptContent, "id: '", "'");
    final token = _extractBetween(scriptContent, "'token': '", "'");
    final expires = _extractBetween(scriptContent, "'expires': '", "'");
    final hasBParam = scriptContent.contains('b=1');
    final canPlayFHD = scriptContent.contains('window.canPlayFHD = true');

    if (videoId == null || token == null || expires == null) {
      debugPrint('$_tag: VixSrc failed to parse script variables');
      return null;
    }

    // Step 4: Build m3u8 URL
    final params = <String, String>{
      'token': token,
      'expires': expires,
      'lang': 'en',
    };
    if (hasBParam) params['b'] = '1';
    if (canPlayFHD) params['h'] = '1';

    final queryStr = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final m3u8Url = '$_vixSrcBase/playlist/$videoId?$queryStr';

    final headers = {
      'Referer': '$_vixSrcBase/$embedPath',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    };

    // Step 5: Verify the m3u8 URL is accessible
    if (!await _verifyUrl(m3u8Url, headers: headers)) return null;

    debugPrint('$_tag: VixSrc stream resolved: $m3u8Url');
    return {
      'url': m3u8Url,
      'source': 'VixSrc',
      'type': 'direct_m3u8',
      'headers': headers,
      'isPlayable': true,
    };
  }

  static String? _extractVixSrcScript(String html) {
    final scriptRegex = RegExp(
      r'<script[^>]*>(.*?)</script>',
      dotAll: true,
    );
    for (final match in scriptRegex.allMatches(html)) {
      final content = match.group(1) ?? '';
      if (content.contains('window.video') ||
          content.contains('window.masterPlaylist')) {
        return content;
      }
    }
    return null;
  }

  // ── Vidrock Extractor ───────────────────────────────────────────────────
  // AES-CBC encrypt TMDB ID → API call → JSON with stream URLs

  static const String _vidrockBase = 'https://vidrock.net';
  static const String _vidrockKey = 'x7k9mPqT2rWvY8zA5bC3nF6hJ2lK4mN9';

  static Future<Map<String, dynamic>?> _extractVidrock({
    required String tmdbId,
    required String type,
    int season = 1,
    int episode = 1,
  }) async {
    try {
      final dataToEncrypt = type == 'movie'
          ? tmdbId
          : '${tmdbId}_${season}_$episode';

      final key = encrypt.Key.fromUtf8(_vidrockKey);
      final iv = encrypt.IV.fromUtf8(_vidrockKey.substring(0, 16));
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );
      final encrypted = encrypter.encryptBytes(
        utf8.encode(dataToEncrypt),
        iv: iv,
      );
      final encoded = encrypted.base64;

      final apiPath = type == 'movie'
          ? 'api/movie/$encoded'
          : 'api/tv/$encoded';

      final dio = Dio(_dio.options);
      dio.options.headers['Referer'] = '$_vidrockBase/';
      dio.options.headers['Origin'] = _vidrockBase;

      final response = await dio.get<dynamic>('$_vidrockBase/$apiPath');
      if (response.statusCode != 200 || response.data == null) return null;

      final data = response.data;
      if (data is! Map) return null;

      // Find first server with a valid m3u8 URL
      for (final entry in data.entries) {
        final serverData = entry.value;
        if (serverData is Map) {
          final url = serverData['url']?.toString();
          if (url != null && url.isNotEmpty && url.contains('.m3u8')) {
            debugPrint('$_tag: Vidrock stream from ${entry.key}: $url');
            return {
              'url': url,
              'source': 'Vidrock',
              'type': 'direct_m3u8',
              'headers': {
                'Referer': '$_vidrockBase/',
                'Origin': _vidrockBase,
              },
              'isPlayable': true,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('$_tag: Vidrock extraction failed: $e');
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
        debugPrint('$_tag: Extractor attempt failed: $e');
      }
    }
    return null;
  }

  static String? _extractBetween(String source, String before, String after) {
    final beforeIdx = source.indexOf(before);
    if (beforeIdx == -1) return null;
    final start = beforeIdx + before.length;
    final afterIdx = source.indexOf(after, start);
    if (afterIdx == -1) return null;
    return source.substring(start, afterIdx).trim();
  }

  static Future<bool> _verifyUrl(
    String url, {
    Map<String, String> headers = const {},
  }) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          ...headers,
        },
      ));
      final resp = await dio.head(url);
      return resp.statusCode != null &&
          resp.statusCode! >= 200 &&
          resp.statusCode! < 400;
    } catch (e) {
      debugPrint('$_tag: URL verification failed for $url: $e');
      return false;
    }
  }
}
