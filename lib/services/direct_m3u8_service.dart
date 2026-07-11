import 'package:flutter/foundation.dart';
import 'native_stream_extractor.dart';

/// Stream extraction service. Delegates to native Kotlin extractor (OkHttp)
/// which handles PrimeSrc → Voe/Streamtape → direct m3u8/mp4 resolution.
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

    final result = await NativeStreamExtractor.resolveStream(
      tmdbId: id,
      isMovie: true,
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

    final result = await NativeStreamExtractor.resolveStream(
      tmdbId: id,
      isMovie: false,
      season: season,
      episode: episode,
    );

    return result;
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
}
