import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Service to fetch embedded video links from various streaming servers
class EmbeddedVideoService {
  static const String _tag = 'EmbeddedVideoService';

  // List of embedded video servers
  static const List<Map<String, String>> _servers = [
    {'name': '2Embed', 'baseUrl': 'https://2embed.cc'},
    {'name': 'VidSrcPro', 'baseUrl': 'https://vidsrc.pro'},
    {'name': 'EmbedSoap', 'baseUrl': 'https://www.embedsoap.com'},
    {'name': 'MultiEmbed', 'baseUrl': 'https://multiembed.mov'},
    {'name': 'SmashyStream', 'baseUrl': 'https://player.smashy.stream'},
    {'name': 'VidPlay', 'baseUrl': 'https://vidplay.online'},
    {'name': 'VidSrcTo', 'baseUrl': 'https://vidsrc.to'},
    {'name': 'VidSrcMe', 'baseUrl': 'https://vidsrc.me'},
    {'name': 'VidFast', 'baseUrl': 'https://vidfast.co'},
    {'name': 'VidLink', 'baseUrl': 'https://vidlink.pro'},
  ];

  // Public getter for servers
  static List<Map<String, String>> getServers() {
    return _servers;
  }

  // Public getter for Dio client
  static Dio getDioClient() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
        },
        followRedirects: true,
        maxRedirects: 5,
      ),
    );
  }

  // Public method to build embed URL
  static String buildEmbedUrl(
    String baseUrl,
    String tmdbId,
    int season,
    int episode,
    bool isMovie,
  ) {
    switch (baseUrl) {
      case 'https://2embed.cc':
        return isMovie
            ? '$baseUrl/embed/$tmdbId'
            : '$baseUrl/embedtv/$tmdbId&s=$season&e=$episode';

      case 'https://vidsrc.pro':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://www.embedsoap.com':
        return isMovie
            ? '$baseUrl/embed/movie/?id=$tmdbId'
            : '$baseUrl/embed/tv/?id=$tmdbId&s=$season&e=$episode';

      case 'https://multiembed.mov':
        return isMovie
            ? '$baseUrl/direct?video_id=$tmdbId'
            : '$baseUrl/direct?video_id=$tmdbId&s=$season&e=$episode';

      case 'https://player.smashy.stream':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId/$season/$episode';

      case 'https://vidplay.online':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidsrc.to':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidsrc.me':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidfast.co':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidlink.pro':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId/$season/$episode';

      default:
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';
    }
  }

  /// Get embedded video URL by TMDB ID
  static Future<Map<String, dynamic>?> getEmbeddedVideo(
    String tmdbId, {
    int season = 1,
    int episode = 1,
    bool isMovie = true,
  }) async {
    try {
      debugPrint('$_tag: Getting embedded video for TMDB ID: $tmdbId');

      // Try each server in order until one works
      for (final server in _servers) {
        try {
          final embedUrl = _buildEmbedUrl(
            server['baseUrl']!,
            tmdbId,
            season,
            episode,
            isMovie,
          );

          debugPrint('$_tag: Trying ${server['name']}: $embedUrl');

          // Check if the embed URL is accessible
          final dio = getDioClient();

          try {
            final response = await dio
                .head(embedUrl)
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () {
                    throw DioException(
                      requestOptions: RequestOptions(path: embedUrl),
                      message: 'Connection timeout',
                      type: DioExceptionType.connectionTimeout,
                    );
                  },
                );

            if (response.statusCode == 200 || response.statusCode == 403) {
              // 403 is acceptable - it means the server exists but forbids direct access
              // The embed will still work through the WebView
              debugPrint(
                '$_tag: Found working embed from ${server['name']}: $embedUrl (status: ${response.statusCode})',
              );
              return {
                'embedUrl': embedUrl,
                'title': 'Video Content',
                'quality': 'HD',
                'source': server['name'],
                'type': 'embed',
                'isPlayable': true,
              };
            }
          } on DioException catch (e) {
            // If we get a response with 403, it still works
            if (e.response?.statusCode == 403) {
              debugPrint(
                '$_tag: Found working embed from ${server['name']}: $embedUrl (403 Forbidden - acceptable)',
              );
              return {
                'embedUrl': embedUrl,
                'title': 'Video Content',
                'quality': 'HD',
                'source': server['name'],
                'type': 'embed',
                'isPlayable': true,
              };
            }
            debugPrint('$_tag: ${server['name']} failed: ${e.message}');
            continue;
          }
        } catch (e) {
          debugPrint('$_tag: ${server['name']} error: $e');
          continue;
        }
      }

      debugPrint('$_tag: No working embed servers found');
      return null;
    } catch (e) {
      debugPrint('$_tag: Error: $e');
      return null;
    }
  }

  /// Search for content and get embedded video URL
  static Future<Map<String, dynamic>?> searchAndGetEmbeddedVideo(
    String title, {
    int season = 1,
    int episode = 1,
    bool isMovie = true,
  }) async {
    try {
      debugPrint('$_tag: Searching for embedded video: "$title"');

      // For search-based approach, we'd need TMDB ID first
      // For now, return null and rely on TMDB ID method
      debugPrint('$_tag: Search not implemented, use TMDB ID method');
      return null;
    } catch (e) {
      debugPrint('$_tag: Search error: $e');
      return null;
    }
  }

  /// Build embed URL for a specific server
  static String _buildEmbedUrl(
    String baseUrl,
    String tmdbId,
    int season,
    int episode,
    bool isMovie,
  ) {
    switch (baseUrl) {
      case 'https://2embed.cc':
        return isMovie
            ? '$baseUrl/embed/$tmdbId'
            : '$baseUrl/embedtv/$tmdbId&s=$season&e=$episode';

      case 'https://vidsrc.pro':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://www.embedsoap.com':
        return isMovie
            ? '$baseUrl/embed/movie/?id=$tmdbId'
            : '$baseUrl/embed/tv/?id=$tmdbId&s=$season&e=$episode';

      case 'https://multiembed.mov':
        return isMovie
            ? '$baseUrl/direct?video_id=$tmdbId'
            : '$baseUrl/direct?video_id=$tmdbId&s=$season&e=$episode';

      case 'https://player.smashy.stream':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId/$season/$episode';

      case 'https://vidplay.online':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidsrc.to':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidsrc.me':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidfast.co':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidlink.pro':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId/$season/$episode';

      default:
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';
    }
  }
}
