import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Fallback streaming service for when main providers fail
/// Tries alternative methods and mirrors to get playable streams
class StreamFallbackService {
  static const String _tag = 'StreamFallbackService';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ),
  );

  /// Fallback providers in order of priority
  static const List<String> _fallbackProviders = [
    'https://2embed.cc/embed',
    'https://multiembed.mov/embed',
    'https://embedsito.com/embed',
    'https://streamvid.net/embed',
  ];

  /// Try fallback providers if main extraction fails
  static Future<String?> tryFallbackProviders(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      debugPrint('$_tag: Attempting fallback providers...');

      for (final providerUrl in _fallbackProviders) {
        try {
          final url = isMovie
              ? '$providerUrl/movie/$tmdbId'
              : '$providerUrl/tv/$tmdbId/$season/$episode';

          debugPrint('$_tag: Testing fallback: $providerUrl');

          // Quick availability check
          final response = await _dio.head(
            url,
            options: Options(validateStatus: (status) => status! < 500),
          );

          if (response.statusCode! < 400) {
            debugPrint('$_tag: ✓ Fallback provider available: $providerUrl');
            return url;
          }
        } catch (e) {
          debugPrint('$_tag: Fallback $providerUrl failed: $e');
        }
      }

      debugPrint('$_tag: ❌ No fallback providers available');
      return null;
    } catch (e) {
      debugPrint('$_tag: Error checking fallbacks: $e');
      return null;
    }
  }

  /// Get alternative streaming sources
  /// Returns list of alternative URLs to try
  static Future<List<String>> getAlternativeSources(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    final sources = <String>[];

    try {
      // Add all working fallback providers
      for (final providerUrl in _fallbackProviders) {
        try {
          final url = isMovie
              ? '$providerUrl/movie/$tmdbId'
              : '$providerUrl/tv/$tmdbId/$season/$episode';

          final response = await _dio.head(
            url,
            options: Options(validateStatus: (status) => status! < 500),
          );

          if (response.statusCode! < 400) {
            sources.add(url);
          }
        } catch (e) {
          // Continue to next provider
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error getting alternative sources: $e');
    }

    return sources;
  }

  /// Check if a URL is a direct playable stream (not an embed)
  static Future<bool> isDirectPlayableUrl(String url) async {
    try {
      if (!url.startsWith('http')) {
        return false;
      }

      // Check if it's a streaming URL
      if (url.contains('.m3u8') ||
          url.contains('.mpd') ||
          url.contains('.mp4') ||
          url.contains('stream')) {
        final response = await _dio.head(
          url,
          options: Options(validateStatus: (status) => status! < 500),
        );

        return response.statusCode! < 400;
      }

      return false;
    } catch (e) {
      debugPrint('$_tag: Error checking URL: $e');
      return false;
    }
  }

  /// Get stream info including availability status
  static Future<Map<String, dynamic>?> getStreamInfo(
    String url,
    String source,
    String quality,
  ) async {
    try {
      final response = await _dio.head(
        url,
        options: Options(validateStatus: (status) => status! < 500),
      );

      if (response.statusCode! < 400) {
        return {
          'url': url,
          'source': source,
          'quality': quality,
          'available': true,
          'statusCode': response.statusCode,
          'headers': response.headers.map.map(
            (key, value) => MapEntry(key, value.join(', ')),
          ),
        };
      }

      return {
        'url': url,
        'source': source,
        'quality': quality,
        'available': false,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      debugPrint('$_tag: Error getting stream info: $e');
      return null;
    }
  }

  /// Verify stream quality before attempting playback
  static Future<bool> verifyStreamQuality(String streamUrl) async {
    try {
      if (!streamUrl.startsWith('http')) {
        return false;
      }

      final response = await _dio.head(
        streamUrl,
        options: Options(
          validateStatus: (status) => status! < 500,
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      // Accept 2xx and 3xx status codes
      return response.statusCode! < 400;
    } catch (e) {
      debugPrint('$_tag: Stream verification failed: $e');
      return false;
    }
  }

  /// Dispose service
  static Future<void> dispose() async {
    try {
      _dio.close();
      debugPrint('$_tag: Service disposed');
    } catch (e) {
      debugPrint('$_tag: Error disposing: $e');
    }
  }
}
