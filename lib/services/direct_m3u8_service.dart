import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Pure HTTP stream extractors ported from streamflix.
/// PrimeSrc provides server links, then Voe/Streamtape extractors resolve
/// the actual m3u8/mp4 URLs via HTTP (no WebView needed).
class DirectM3u8Service {
  static const String _tag = 'DirectM3u8Service';
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  // ── Public API ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchMovieStreamUrl(
    String title,
    int? year,
    String? tmdbId,
  ) async {
    final id = tmdbId?.trim();
    if (id == null || id.isEmpty) return null;
    debugPrint('$_tag: Resolving movie $title (TMDB: $id)');
    return _resolveFromPrimeSrc(tmdbId: id, type: 'movie');
  }

  static Future<Map<String, dynamic>?> fetchSeriesStreamUrl(
    String title,
    int season,
    int episode,
    String? tmdbId,
  ) async {
    final id = tmdbId?.trim();
    if (id == null || id.isEmpty) return null;
    debugPrint('$_tag: Resolving $title S${season}E$episode (TMDB: $id)');
    return _resolveFromPrimeSrc(
      tmdbId: id,
      type: 'tv',
      season: season,
      episode: episode,
    );
  }

  /// Embed URLs for VidLinkExtractor fallback.
  static const List<Map<String, String>> _embedSources = [
    {
      'name': 'VidLink',
      'movieUrl': 'https://vidlink.pro/movie/{id}',
      'tvUrl': 'https://vidlink.pro/tv/{id}/{season}/{episode}',
    },
  ];

  static List<Map<String, String>> getEmbedSources() => List.from(_embedSources);

  static String generateMovieEmbedUrl(String tmdbId, String sourceName) {
    final s = _embedSources.firstWhere((s) => s['name'] == sourceName,
        orElse: () => _embedSources.first);
    return s['movieUrl']!.replaceAll('{id}', tmdbId);
  }

  static String generateTvEmbedUrl(
      String tmdbId, int season, int episode, String sourceName) {
    final s = _embedSources.firstWhere((s) => s['name'] == sourceName,
        orElse: () => _embedSources.first);
    return s['tvUrl']!
        .replaceAll('{id}', tmdbId)
        .replaceAll('{season}', season.toString())
        .replaceAll('{episode}', episode.toString());
  }

  // ── PrimeSrc → Server List → Link Resolution → Extractor ────────────────

  static Future<Map<String, dynamic>?> _resolveFromPrimeSrc({
    required String tmdbId,
    required String type,
    int season = 1,
    int episode = 1,
  }) async {
    try {
      // Step 1: Get server list from PrimeSrc
      final serversUrl = type == 'movie'
          ? 'https://primesrc.me/api/v1/s?tmdb=$tmdbId&type=movie'
          : 'https://primesrc.me/api/v1/s?tmdb=$tmdbId&season=$season&episode=$episode&type=tv';

      debugPrint('$_tag: PrimeSrc servers: $serversUrl');
      final dio = _makeDio(headers: {'Referer': 'https://primesrc.me/'});
      final serversResp = await dio.get<dynamic>(serversUrl);

      if (serversResp.statusCode != 200 || serversResp.data == null) {
        debugPrint('$_tag: PrimeSrc servers returned ${serversResp.statusCode}');
        return null;
      }

      final serversData = serversResp.data;
      if (serversData is! Map) {
        debugPrint('$_tag: PrimeSrc servers response is not a Map');
        return null;
      }

      final servers = serversData['servers'];
      if (servers is! List || servers.isEmpty) {
        debugPrint('$_tag: PrimeSrc no servers found');
        return null;
      }

      debugPrint('$_tag: PrimeSrc found ${servers.length} servers');

      // Step 2: Try each server - get link, then extract
      for (final server in servers) {
        if (server is! Map) continue;
        final serverName = server['name']?.toString() ?? '';
        final serverKey = server['key']?.toString() ?? '';
        if (serverKey.isEmpty) continue;

        debugPrint('$_tag: Trying server: $serverName (key: $serverKey)');

        try {
          final linkResp = await dio.get<dynamic>(
            'https://primesrc.me/api/v1/l?key=$serverKey',
          );

          if (linkResp.statusCode != 200 || linkResp.data == null) {
            debugPrint('$_tag:   Link endpoint returned ${linkResp.statusCode}');
            continue;
          }

          final linkData = linkResp.data;
          final link = linkData is Map ? linkData['link']?.toString() : null;
          if (link == null || link.isEmpty) {
            debugPrint('$_tag:   No link in response');
            continue;
          }

          debugPrint('$_tag:   Got link: $link');

          // Step 3: Extract based on server name / link URL
          final result = await _extractByServerName(serverName, link);
          if (result != null) {
            debugPrint('$_tag:   SUCCESS from $serverName');
            return result;
          }
        } catch (e) {
          debugPrint('$_tag:   Server $serverName failed: $e');
        }
      }

      debugPrint('$_tag: All PrimeSrc servers failed');
      return null;
    } catch (e) {
      debugPrint('$_tag: PrimeSrc resolution failed: $e');
      return null;
    }
  }

  // ── Dispatcher: pick extractor by server name ───────────────────────────

  static Future<Map<String, dynamic>?> _extractByServerName(
    String serverName,
    String link,
  ) async {
    final lower = serverName.toLowerCase();
    if (lower.contains('voe')) {
      return _extractVoe(link);
    } else if (lower.contains('streamtape') || lower.contains('streamta')) {
      return _extractStreamtape(link);
    } else {
      // Generic: try to fetch the page and find an m3u8 URL
      return _extractGeneric(link, source: serverName);
    }
  }

  // ── Voe Extractor ───────────────────────────────────────────────────────
  // Fetch page → find <script type="application/json"> → ROT13 decrypt → m3u8

  static Future<Map<String, dynamic>?> _extractVoe(String link) async {
    try {
      debugPrint('$_tag: Voe extracting: $link');

      // Step 1: Fetch the Voe page
      final dio = _makeDio(headers: {
        'Referer': link,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      });

      // Voe may redirect to an alias domain - follow it
      final pageResp = await dio.get<String>(link);
      if (pageResp.statusCode != 200 || pageResp.data == null) {
        debugPrint('$_tag: Voe page returned ${pageResp.statusCode}');
        return null;
      }

      final html = pageResp.data!;
      final pageUrl = pageResp.requestOptions.uri.toString();
      debugPrint('$_tag: Voe final URL: $pageUrl');

      // Step 2: Find encoded data in <script type="application/json">
      final scriptRegex = RegExp(
        r'''<script\s+type="application/json">(.*?)</script>''',
        dotAll: true,
      );
      final scriptMatch = scriptRegex.firstMatch(html);
      var encodedData = scriptMatch?.group(1)?.trim() ?? '';

      // Fallback: find encoded data via regex pattern
      if (encodedData.isEmpty) {
        final altRegex = RegExp(
          r'''<script\s+type="application/json">(.*?)</script>''',
          dotAll: true,
        );
        encodedData = altRegex.firstMatch(html)?.group(1)?.trim() ?? '';
      }

      if (encodedData.isEmpty) {
        debugPrint('$_tag: Voe: no encoded data found');
        return null;
      }

      // Step 3: Decrypt (ROT13 → replace patterns → remove underscores → Base64 → charShift → reverse → Base64)
      final decrypted = _decryptVoe(encodedData);
      if (decrypted.isEmpty) {
        debugPrint('$_tag: Voe: decryption failed');
        return null;
      }

      final m3u8 = decrypted['source']?.toString() ?? '';
      if (m3u8.isEmpty) {
        debugPrint('$_tag: Voe: no source in decrypted data');
        return null;
      }

      debugPrint('$_tag: Voe stream: $m3u8');
      return {
        'url': m3u8,
        'source': 'Voe',
        'type': 'direct_m3u8',
        'headers': {'Referer': '$pageUrl'},
      };
    } catch (e) {
      debugPrint('$_tag: Voe extraction failed: $e');
      return null;
    }
  }

  /// Decrypt Voe-encoded string.
  /// ROT13 → replace patterns → remove underscores → Base64 decode →
  /// char shift -3 → reverse → Base64 decode → JSON
  static Map<String, dynamic> _decryptVoe(String input) {
    try {
      // ROT13
      var s = _rot13(input);
      // Replace Voe-specific patterns with underscores
      s = s.replaceAll('@\$', '_');
      s = s.replaceAll('^^', '_');
      s = s.replaceAll('~@', '_');
      s = s.replaceAll('%\x3f', '_');
      s = s.replaceAll('*~', '_');
      s = s.replaceAll('!!', '_');
      s = s.replaceAll('#&', '_');
      // Remove underscores
      s = s.replaceAll('_', '');
      // Base64 decode
      s = utf8.decode(base64.decode(s));
      // Char shift -3
      s = _charShift(s, -3);
      // Reverse
      s = s.split('').reversed.join('');
      // Base64 decode again
      s = utf8.decode(base64.decode(s));
      // Parse JSON
      return json.decode(s) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('$_tag: Voe decrypt error: $e');
      return {};
    }
  }

  static String _rot13(String input) {
    return input.split('').map((c) {
      final code = c.codeUnitAt(0);
      if (code >= 65 && code <= 90) return String.fromCharCode((code - 65 + 13) % 26 + 65);
      if (code >= 97 && code <= 122) return String.fromCharCode((code - 97 + 13) % 26 + 97);
      return c;
    }).join('');
  }

  static String _charShift(String input, int shift) {
    return input.split('').map((c) {
      return String.fromCharCode(c.codeUnitAt(0) - shift);
    }).join('');
  }

  // ── Streamtape Extractor ────────────────────────────────────────────────
  // Fetch page → parse botlink JS regex → reconstruct URL → follow redirect

  static Future<Map<String, dynamic>?> _extractStreamtape(String link) async {
    try {
      debugPrint('$_tag: Streamtape extracting: $link');

      final dio = _makeDio();
      final pageResp = await dio.get<String>(link);
      if (pageResp.statusCode != 200 || pageResp.data == null) {
        debugPrint('$_tag: Streamtape page returned ${pageResp.statusCode}');
        return null;
      }

      final html = pageResp.data!;

      // Parse: document.getElementById('botlink').innerHTML = '...' + '(...)'  .substring(N)
      final botlinkRegex = RegExp(
        r"document\.getElementById\('botlink'\)\.innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)",
      );
      final match = botlinkRegex.firstMatch(html);
      if (match == null) {
        debugPrint('$_tag: Streamtape: botlink JS not found');
        return null;
      }

      final paramString = match.group(2)!;
      final substringIndex = int.parse(match.group(3)!);

      // Apply substring to get clean parameters
      final cleanParams = paramString.substring(substringIndex);

      // Extract parameters
      final id = _extractParam(cleanParams, 'id');
      final expires = _extractParam(cleanParams, 'expires');
      final ip = _extractParam(cleanParams, 'ip');
      final token = _extractParam(cleanParams, 'token');

      if (id == null || expires == null || ip == null || token == null) {
        debugPrint('$_tag: Streamtape: failed to extract parameters');
        return null;
      }

      // Build the download URL
      final videoUrl =
          'https://streamtape.com/get_video?id=$id&expires=$expires&ip=$ip&token=$token&stream=1';

      debugPrint('$_tag: Streamtape video URL: $videoUrl');

      // Follow the redirect to get the actual streaming URL
      final videoResp = await dio.get<dynamic>(
        videoUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final redirectUrl = videoResp.headers.value('location');
      if (redirectUrl == null || redirectUrl.isEmpty) {
        debugPrint('$_tag: Streamtape: no redirect URL');
        return null;
      }

      debugPrint('$_tag: Streamtape stream: $redirectUrl');
      return {
        'url': redirectUrl,
        'source': 'Streamtape',
        'type': 'direct_video',
        'headers': {'Referer': 'https://streamtape.com/'},
      };
    } catch (e) {
      debugPrint('$_tag: Streamtape extraction failed: $e');
      return null;
    }
  }

  static String? _extractParam(String source, String paramName) {
    final regex = RegExp('$paramName=([^&]+)');
    return regex.firstMatch(source)?.group(1);
  }

  // ── Generic Extractor ───────────────────────────────────────────────────
  // Fetch page → search for m3u8/mp4 URLs in HTML/scripts

  static Future<Map<String, dynamic>?> _extractGeneric(
    String link, {
    required String source,
  }) async {
    try {
      debugPrint('$_tag: Generic extracting $source: $link');

      final dio = _makeDio(headers: {'Referer': link});
      final pageResp = await dio.get<String>(link);
      if (pageResp.statusCode != 200 || pageResp.data == null) return null;

      final html = pageResp.data!;

      // Search for m3u8 URLs in the page
      final m3u8Regex = RegExp(
        'https?://[^\\s"\'<>]+\\.m3u8[^\\s"\'<>]*',
        caseSensitive: false,
      );
      final m3u8Match = m3u8Regex.firstMatch(html);
      if (m3u8Match != null) {
        final url = m3u8Match.group(0)!;
        debugPrint('$_tag: Generic found m3u8: $url');
        return {
          'url': url,
          'source': source,
          'type': 'direct_m3u8',
          'headers': {'Referer': link},
        };
      }

      // Search for mp4 URLs
      final mp4Regex = RegExp(
        'https?://[^\\s"\'<>]+\\.mp4[^\\s"\'<>]*',
        caseSensitive: false,
      );
      final mp4Match = mp4Regex.firstMatch(html);
      if (mp4Match != null) {
        final url = mp4Match.group(0)!;
        debugPrint('$_tag: Generic found mp4: $url');
        return {
          'url': url,
          'source': source,
          'type': 'direct_video',
          'headers': {'Referer': link},
        };
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Generic extraction failed: $e');
      return null;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static Dio _makeDio({Map<String, String> headers = const {}}) {
    return Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': _ua,
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        ...headers,
      },
      followRedirects: true,
      maxRedirects: 5,
    ));
  }
}
