import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Bridges to the native Kotlin StreamExtractor via platform channel.
/// Uses OkHttp on Android for better Cloudflare/TLS handling.
class NativeStreamExtractor {
  static const _channel = MethodChannel('com.maxstream.app/extractor');

  /// Resolve a TMDB ID to a playable stream URL using native Kotlin extractors.
  /// Returns a map with url, source, type, referer keys, or null on failure.
  static Future<Map<String, String>?> resolveStream({
    required String tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
  }) async {
    try {
      debugPrint('NativeExtractor: Resolving TMDB $tmdbId (movie=$isMovie)');

      final result = await _channel.invokeMethod<Map>('resolveStream', {
        'tmdbId': tmdbId,
        'isMovie': isMovie,
        'season': season,
        'episode': episode,
      });

      if (result == null) return null;

      // Convert Map<Object?, Object?> to Map<String, String>
      final map = result.map((key, value) => MapEntry(key.toString(), value.toString()));
      debugPrint('NativeExtractor: Success - ${map["source"]}: ${map["url"]}');
      return map;
    } on PlatformException catch (e) {
      debugPrint('NativeExtractor: Platform error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('NativeExtractor: Error: $e');
      return null;
    }
  }
}
