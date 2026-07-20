import 'package:flutter/foundation.dart';
import 'native_stream_extractor.dart';
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

    return result;
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

    return result;
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
      final sources = WebStreamService.getEmbedSources();
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

    return NativeStreamExtractor.resolveStreams(
      tmdbId: tmdbId,
      isMovie: isMovie,
      season: season,
      episode: episode,
      title: title,
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
