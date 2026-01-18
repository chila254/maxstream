import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Service to fetch embedded video links from various streaming servers
class EmbeddedVideoService {
  static const String _tag = 'EmbeddedVideoService';

  // List of embedded video servers
  static const List<Map<String, String>> _servers = [
    {'name': 'VidFast', 'baseUrl': 'https://vidfast.co'},
    {'name': 'VidLink', 'baseUrl': 'https://vidlink.pro'},
    {'name': 'VidEasy', 'baseUrl': 'https://vidsrc.me'},
    {'name': 'Vidsrc', 'baseUrl': 'https://vidsrc.to'},
    {'name': 'Vidora', 'baseUrl': 'https://vidora.to'},
    {'name': 'Mapple', 'baseUrl': 'https://mapple.net'},
    {'name': 'Super', 'baseUrl': 'https://superembed.xyz'},
    {'name': 'MovAPI', 'baseUrl': 'https://movapi.com'},
    {'name': '2Embed', 'baseUrl': 'https://2embed.cc'},
    {'name': '1Movies', 'baseUrl': 'https://1movies.tv'},
    {'name': 'Nonton', 'baseUrl': 'https://nonton.com'},
    {'name': 'Primewire', 'baseUrl': 'https://primewire.mx'},
  ];

  static Dio _getDioClient() {
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

          // Check if the embed URL is accessible
          final dio = _getDioClient();
          final response = await dio.head(embedUrl);

          if (response.statusCode == 200) {
            debugPrint(
              '$_tag: Found working embed from ${server['name']}: $embedUrl',
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
        } catch (e) {
          debugPrint('$_tag: ${server['name']} failed: $e');
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
      case 'https://vidfast.co':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidlink.pro':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId/$season/$episode';

      case 'https://vidsrc.me':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidsrc.to':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://vidora.to':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://mapple.net':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId/$season/$episode';

      case 'https://superembed.xyz':
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';

      case 'https://movapi.com':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId/$season/$episode';

      case 'https://2embed.cc':
        return isMovie
            ? '$baseUrl/embed/$tmdbId'
            : '$baseUrl/embedtv/$tmdbId&s=$season&e=$episode';

      case 'https://1movies.tv':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId-$season-$episode';

      case 'https://nonton.com':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId/$season/$episode';

      case 'https://primewire.mx':
        return isMovie
            ? '$baseUrl/movie/$tmdbId'
            : '$baseUrl/tv/$tmdbId/season-$season/episode-$episode';

      default:
        return isMovie
            ? '$baseUrl/embed/movie/$tmdbId'
            : '$baseUrl/embed/tv/$tmdbId/$season/$episode';
    }
  }
}
