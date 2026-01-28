import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import '../services/phone_scraper_service.dart';

/// Service for fetching direct m3u8 URLs for movies and TV series
/// Integrates with various streaming sources to extract playable m3u8 links
class DirectM3u8Service {
  static const String _tag = 'DirectM3u8Service';

  /// Direct M3U8 streaming sources that work with movies/series
  static const List<Map<String, String>> _m3u8Sources = [
    {
      'name': 'StreamingSource1',
      'baseUrl': 'https://m3u.freetv.ch',
      'type': 'playlist',
    },
    {'name': 'M3U8Direct', 'baseUrl': 'https://iptvx.one', 'type': 'html'},
    {
      'name': 'IPTV-ORG',
      'baseUrl': 'https://iptv-org.github.io',
      'type': 'json',
    },
    {
      'name': 'TVStreamLive',
      'baseUrl': 'https://tvstreamlive.net',
      'type': 'html',
    },
  ];

  /// Fetch direct m3u8 URL for a movie
  /// Returns a map with stream URL or null if not found
  static Future<Map<String, dynamic>?> fetchMovieStreamUrl(
    String title,
    int? year,
    String? tmdbId,
  ) async {
    try {
      debugPrint(
        '$_tag: Searching m3u8 stream for movie: $title (Year: $year, TMDB: $tmdbId)',
      );

      // Try to find stream using title and year
      for (final source in _m3u8Sources) {
        try {
          final result = await _searchStreamInSource(
            source['baseUrl']!,
            source['name']!,
            source['type']!,
            title,
            year: year,
          );

          if (result != null) {
            debugPrint(
              '$_tag: Found movie stream in ${source['name']}: ${result['url']}',
            );
            return result;
          }
        } catch (e) {
          debugPrint('$_tag: Error searching ${source['name']} for movie: $e');
          continue;
        }
      }

      debugPrint('$_tag: No m3u8 URL found for movie: $title');
      return null;
    } catch (e) {
      debugPrint('$_tag: Error fetching movie stream: $e');
      return null;
    }
  }

  /// Fetch direct m3u8 URL for a TV series episode
  /// Returns a map with stream URL or null if not found
  static Future<Map<String, dynamic>?> fetchSeriesStreamUrl(
    String title,
    int season,
    int episode,
    String? tmdbId,
  ) async {
    try {
      debugPrint(
        '$_tag: Searching m3u8 stream for series: $title S${season}E$episode (TMDB: $tmdbId)',
      );

      // Format series query: "Series Name S01E01"
      final seriesQuery =
          '$title S${season.toString().padLeft(2, '0')}'
          'E${episode.toString().padLeft(2, '0')}';

      // Try to find stream using series query
      for (final source in _m3u8Sources) {
        try {
          final result = await _searchStreamInSource(
            source['baseUrl']!,
            source['name']!,
            source['type']!,
            seriesQuery,
          );

          if (result != null) {
            debugPrint(
              '$_tag: Found series stream in ${source['name']}: ${result['url']}',
            );
            return result;
          }
        } catch (e) {
          debugPrint('$_tag: Error searching ${source['name']} for series: $e');
          continue;
        }
      }

      debugPrint('$_tag: No m3u8 URL found for series: $title');
      return null;
    } catch (e) {
      debugPrint('$_tag: Error fetching series stream: $e');
      return null;
    }
  }

  /// Search for stream URL in a specific source
  static Future<Map<String, dynamic>?> _searchStreamInSource(
    String baseUrl,
    String sourceName,
    String sourceType,
    String query, {
    int? year,
  }) async {
    try {
      switch (sourceType) {
        case 'playlist':
          return await _searchInM3u8Playlist(
            baseUrl,
            sourceName,
            query,
            year: year,
          );

        case 'html':
          return await _searchInHtmlSource(
            baseUrl,
            sourceName,
            query,
            year: year,
          );

        case 'json':
          return await _searchInJsonSource(baseUrl, sourceName, query);

        default:
          return null;
      }
    } catch (e) {
      debugPrint('$_tag: Error searching $sourceName: $e');
      return null;
    }
  }

  /// Search for m3u8 URL in M3U8 playlist format
  static Future<Map<String, dynamic>?> _searchInM3u8Playlist(
    String playlistUrl,
    String sourceName,
    String query, {
    int? year,
  }) async {
    try {
      final dio = PhoneScraperService.getDioClient();
      final response = await dio
          .get(playlistUrl)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final content = response.data as String;
        final m3u8Url = _extractM3u8FromPlaylist(content, query, year: year);

        if (m3u8Url != null && await _verifyM3u8Url(m3u8Url)) {
          return {
            'url': m3u8Url,
            'title': query,
            'source': sourceName,
            'type': 'direct_m3u8',
            'isPlayable': true,
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Playlist search error: $e');
      return null;
    }
  }

  /// Search for m3u8 URL in HTML source
  static Future<Map<String, dynamic>?> _searchInHtmlSource(
    String baseUrl,
    String sourceName,
    String query, {
    int? year,
  }) async {
    try {
      final dio = PhoneScraperService.getDioClient();
      final response = await dio
          .get(baseUrl)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final htmlDoc = html_parser.parse(response.data);
        final m3u8Url = _extractM3u8FromHtml(htmlDoc, query, year: year);

        if (m3u8Url != null && await _verifyM3u8Url(m3u8Url)) {
          return {
            'url': m3u8Url,
            'title': query,
            'source': sourceName,
            'type': 'direct_m3u8',
            'isPlayable': true,
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: HTML search error: $e');
      return null;
    }
  }

  /// Search for m3u8 URL in JSON API source
  static Future<Map<String, dynamic>?> _searchInJsonSource(
    String apiUrl,
    String sourceName,
    String query,
  ) async {
    try {
      final dio = PhoneScraperService.getDioClient();
      final response = await dio
          .get(apiUrl)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = response.data;

        if (jsonData is List) {
          // Search in JSON array for matching items
          final match = jsonData.firstWhere(
            (item) =>
                (item['name'] as String?)?.toLowerCase().contains(
                  query.toLowerCase(),
                ) ??
                false,
            orElse: () => null,
          );

          if (match != null && match['url'] != null) {
            final m3u8Url = match['url'] as String;
            if (m3u8Url.contains('.m3u8') && await _verifyM3u8Url(m3u8Url)) {
              return {
                'url': m3u8Url,
                'title': match['name'] ?? query,
                'source': sourceName,
                'type': 'direct_m3u8',
                'isPlayable': true,
              };
            }
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: JSON search error: $e');
      return null;
    }
  }

  /// Extract m3u8 URL from M3U8 playlist content
  static String? _extractM3u8FromPlaylist(
    String content,
    String query, {
    int? year,
  }) {
    try {
      final lines = content.split('\n');
      final lowerQuery = query.toLowerCase();

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        // Skip comment lines that are metadata
        if (line.startsWith('#')) continue;

        // Look for lines containing the query
        if (line.toLowerCase().contains(lowerQuery)) {
          // Check if the next line is a URL
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1].trim();
            if ((nextLine.startsWith('http://') ||
                    nextLine.startsWith('https://')) &&
                nextLine.contains('.m3u8')) {
              return nextLine;
            }
          }

          // Or if this line itself is a URL
          if ((line.startsWith('http://') || line.startsWith('https://')) &&
              line.contains('.m3u8')) {
            return line;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Playlist extraction error: $e');
      return null;
    }
  }

  /// Extract m3u8 URL from HTML document
  static String? _extractM3u8FromHtml(
    html_dom.Document htmlDoc,
    String query, {
    int? year,
  }) {
    try {
      // Search for m3u8 links in various HTML elements
      final m3u8Links = htmlDoc.querySelectorAll('a[href*=".m3u8"]');

      for (final link in m3u8Links) {
        final href = link.attributes['href'];
        if (href != null &&
            (href.toLowerCase().contains(query.toLowerCase()) ||
                href.contains('.m3u8'))) {
          return href;
        }
      }

      // Search for video sources
      final videoSources = htmlDoc.querySelectorAll('source[src*=".m3u8"]');
      for (final source in videoSources) {
        final src = source.attributes['src'];
        if (src != null) {
          return src;
        }
      }

      // Search in script tags for m3u8 URLs
      final scripts = htmlDoc.querySelectorAll('script');
      for (final script in scripts) {
        final scriptContent = script.text;
        final regex = RegExp(r'https?://[^\s<>]+\.m3u8[^\s<>]*');
        final match = regex.firstMatch(scriptContent);
        if (match != null) {
          return match.group(0);
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: HTML extraction error: $e');
      return null;
    }
  }

  /// Verify that an m3u8 URL is accessible and valid
  static Future<bool> _verifyM3u8Url(String url) async {
    try {
      final dio = PhoneScraperService.getDioClient(
        receiveTimeout: const Duration(seconds: 5),
      );

      final response = await dio
          .head(url)
          .timeout(const Duration(seconds: 5))
          .catchError((_) {
            // Try GET if HEAD fails
            return dio.get(
              url,
              options: Options(responseType: ResponseType.bytes),
            );
          });

      final isValid =
          response.statusCode != null &&
          (response.statusCode! == 200 ||
              response.statusCode! == 206 ||
              response.statusCode! == 301 ||
              response.statusCode! == 302);

      if (isValid) {
        debugPrint('$_tag: M3U8 URL verified: $url');
      }

      return isValid;
    } catch (e) {
      debugPrint('$_tag: M3U8 verification failed for $url: $e');
      return false;
    }
  }

  /// Get available m3u8 sources
  static List<Map<String, String>> getAvailableSources() {
    return List<Map<String, String>>.from(_m3u8Sources);
  }

  /// Test a custom m3u8 source
  static Future<bool> testM3u8Source(String url) async {
    return _verifyM3u8Url(url);
  }

  /// Batch verify multiple m3u8 URLs
  static Future<List<Map<String, dynamic>>> verifyMultipleUrls(
    List<String> urls,
  ) async {
    final results = <Map<String, dynamic>>[];

    for (final url in urls) {
      final isValid = await _verifyM3u8Url(url);
      results.add({'url': url, 'isValid': isValid});
    }

    return results;
  }
}
