import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'native_stream_extractor.dart';
import 'stream_security.dart';
import 'web_stream_service.dart';

/// Stream extraction service.
/// On mobile: delegates to native Android Kotlin extractors via platform channel.
/// On web: uses web-compatible embed URLs and HTTP requests.
class DirectM3u8Service {
  static const String _tag = 'DirectM3u8Service';

  static Future<Map<String, dynamic>?> fetchMovieStreamUrl(
    String title,
    int? year,
    String? tmdbId,
  ) async {
    final id = tmdbId?.trim();
    if (id == null || id.isEmpty) return null;
    debugPrint('$_tag: Resolving movie $title (TMDB: $id)');

    if (kIsWeb) {
      return WebStreamService.resolveStream(
        tmdbId: id,
        isMovie: true,
        title: title,
      );
    }

    final result = await NativeStreamExtractor.resolveStream(
      tmdbId: id,
      isMovie: true,
      title: title,
    );

    return StreamSecurity.sanitizeResolverResult(result);
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

    if (kIsWeb) {
      return WebStreamService.resolveStream(
        tmdbId: id,
        isMovie: false,
        season: season,
        episode: episode,
        title: title,
      );
    }

    final result = await NativeStreamExtractor.resolveStream(
      tmdbId: id,
      isMovie: false,
      season: season,
      episode: episode,
      title: title,
    );

    return StreamSecurity.sanitizeResolverResult(result);
  }

  static Future<List<Map<String, dynamic>>> fetchAvailableStreams({
    required String title,
    required String tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
  }) async {
    if (kIsWeb) {
      // On web, return embed sources as available servers
      final sources = WebStreamService.servers;
      return sources.map((source) {
        final url = isMovie
            ? source['movieUrl']!.replaceAll('{id}', tmdbId)
            : source['tvUrl']!
                  .replaceAll('{id}', tmdbId)
                  .replaceAll('{season}', season.toString())
                  .replaceAll('{episode}', episode.toString());
        return {
          'url': url,
          'source': source['name'],
          'type': 'embed',
          'isEmbed': true,
        };
      }).toList();
    }

    final streams = await NativeStreamExtractor.resolveStreams(
      tmdbId: tmdbId,
      isMovie: isMovie,
      season: season,
      episode: episode,
      title: title,
    );
    return streams
        .map(StreamSecurity.sanitizeResolverResult)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Pre-flight check that a resolved stream URL will actually play before we
  /// hand it to ExoPlayer. Downloads only the head of the resource (the HLS
  /// manifest is small; a direct file is capped at 64KB) and rejects dead,
  /// expired-token or misconfigured URLs so a broken server is never sent to
  /// the player and playback falls through to the next working source.
  static Future<bool> validateStream(
    String url, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (kIsWeb) return true;
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;

    final client = http.Client();
    try {
      final request = http.Request('GET', uri)..headers.addAll(headers);
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('$_tag: reject $url -> HTTP ${response.statusCode}');
        return false;
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > 65536) break;
      }
      if (bytes.isEmpty) {
        debugPrint('$_tag: reject $url -> empty body');
        return false;
      }
      final body = utf8.decode(bytes, allowMalformed: true);
      final looksHls = url.toLowerCase().contains('.m3u8') ||
          body.trimLeft().toUpperCase().startsWith('#EXTM3U');
      if (looksHls) {
        // The body must be a real playlist referencing media segments, not an
        // HTML error page or a stale/empty manifest.
        final isPlaylist = body.contains('#EXTM3U') ||
            RegExp(r'\.(ts|m4s|mp4|aac)([?#]|$)').hasMatch(body);
        if (!isPlaylist) {
          debugPrint('$_tag: reject $url -> body is not an HLS playlist');
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('$_tag: reject $url -> $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Embed URLs for VidLinkExtractor fallback.
  static const List<Map<String, String>> _embedSources = [
    {
      'name': 'VidLink',
      'movieUrl': 'https://vidlink.pro/movie/{id}',
      'tvUrl': 'https://vidlink.pro/tv/{id}/{season}/{episode}',
    },
  ];

  static List<Map<String, String>> getEmbedSources() =>
      List.from(_embedSources);

  static String generateMovieEmbedUrl(String tmdbId, String sourceName) {
    final s = _embedSources.firstWhere(
      (s) => s['name'] == sourceName,
      orElse: () => _embedSources.first,
    );
    return s['movieUrl']!.replaceAll('{id}', tmdbId);
  }

  static String generateTvEmbedUrl(
    String tmdbId,
    int season,
    int episode,
    String sourceName,
  ) {
    final s = _embedSources.firstWhere(
      (s) => s['name'] == sourceName,
      orElse: () => _embedSources.first,
    );
    return s['tvUrl']!
        .replaceAll('{id}', tmdbId)
        .replaceAll('{season}', season.toString())
        .replaceAll('{episode}', episode.toString());
  }
}
