import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Bridges to the native Kotlin StreamExtractor via platform channel.
/// Uses OkHttp on Android for better Cloudflare/TLS handling.
class NativeStreamExtractor {
  static const _channel = MethodChannel('com.maxstream.app/extractor');

  static Future<double> getBrightness() async {
    return await _channel.invokeMethod<double>('getBrightness') ?? 0.5;
  }

  static Future<void> setBrightness(double value) async {
    await _channel.invokeMethod<void>('setBrightness', {
      'value': value.clamp(0.01, 1.0),
    });
  }

  static Map<String, dynamic> _normalizeStream(Map result) {
    final map = <String, dynamic>{};
    result.forEach((key, value) {
      if (key.toString() == 'headers' && value is Map) {
        map['headers'] = value.map(
          (header, headerValue) =>
              MapEntry(header.toString(), headerValue.toString()),
        );
      } else {
        map[key.toString()] = value;
      }
    });
    return map;
  }

  /// Resolve a TMDB ID to a playable stream URL using native Kotlin extractors.
  /// Returns stream metadata and request headers, or null on failure.
  static Future<Map<String, dynamic>?> resolveStream({
    required String tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
    String title = '',
  }) async {
    try {
      debugPrint('NativeExtractor: Resolving TMDB $tmdbId (movie=$isMovie)');

      final result = await _channel.invokeMethod<Map>('resolveStream', {
        'tmdbId': tmdbId,
        'isMovie': isMovie,
        'season': season,
        'episode': episode,
        'title': title,
      });

      if (result == null) return null;

      final map = _normalizeStream(result);
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

  /// Resolve every server that currently produces a validated playable stream.
  static Future<List<Map<String, dynamic>>> resolveStreams({
    required String tmdbId,
    required bool isMovie,
    int season = 1,
    int episode = 1,
    String title = '',
  }) async {
    try {
      final result = await _channel.invokeMethod<List>('resolveStreams', {
        'tmdbId': tmdbId,
        'isMovie': isMovie,
        'season': season,
        'episode': episode,
        'title': title,
      });
      return result
              ?.whereType<Map>()
              .map(_normalizeStream)
              .where((stream) => stream['url']?.toString().isNotEmpty == true)
              .toList() ??
          const [];
    } on PlatformException catch (e) {
      debugPrint('NativeExtractor: Server discovery failed: ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('NativeExtractor: Server discovery error: $e');
      return const [];
    }
  }
}
