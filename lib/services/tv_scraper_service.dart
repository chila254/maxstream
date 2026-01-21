import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

/// Service to fetch direct m3u8 URLs for TV channels
class TvScraperService {
  static const String _tag = 'TvScraperService';

  // TV scraper API sources that provide direct m3u8 URLs
  static const List<Map<String, String>> _sources = [
    {
      'name': 'TvStreamLive',
      'baseUrl': 'https://www.tvstreamlive.net',
      'type': 'html',
    },
    {
      'name': 'FreeTVChannels',
      'baseUrl': 'https://m3u.freetv.ch',
      'type': 'playlist',
    },
    {
      'name': 'IPTV Stalker',
      'baseUrl': 'https://iptvx.one',
      'type': 'html',
    },
    {
      'name': 'IPTV Org',
      'baseUrl': 'https://iptv-org.github.io',
      'type': 'json',
    },
    {
      'name': 'IPTV Playlist',
      'baseUrl': 'https://raw.githubusercontent.com/iptv-org/iptv/master/index.m3u',
      'type': 'playlist',
    },
  ];

  // Public getter for sources
  static List<Map<String, String>> getSources() {
    return _sources;
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
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate, br',
          'Referer': 'https://www.google.com/',
        },
        followRedirects: true,
        maxRedirects: 5,
      ),
    );
  }

  /// Search for a TV channel and get direct m3u8 URL
  static Future<Map<String, dynamic>?> searchTvChannel(String channelName) async {
    try {
      debugPrint('$_tag: Searching for TV channel: "$channelName"');

      // Try each source in order until one works
      for (final source in _sources) {
        try {
          final result = await _fetchFromSource(
            source['baseUrl']!,
            source['name']!,
            source['type']!,
            channelName,
          );

          if (result != null) {
            return result;
          }
        } catch (e) {
          debugPrint('$_tag: Error searching ${source['name']}: $e');
          continue;
        }
      }

      debugPrint('$_tag: No m3u8 URL found for channel: $channelName');
      return null;
    } catch (e) {
      debugPrint('$_tag: Search error: $e');
      return null;
    }
  }

  /// Fetch m3u8 playlist and search for channel
  static Future<Map<String, dynamic>?> getM3u8Playlist(String playlistUrl) async {
    try {
      debugPrint('$_tag: Fetching M3U8 playlist from: $playlistUrl');

      final dio = getDioClient();
      final response = await dio.get(playlistUrl);

      if (response.statusCode == 200) {
        final content = response.data as String;
        debugPrint('$_tag: Successfully fetched playlist (${content.length} bytes)');

        return {
          'playlistUrl': playlistUrl,
          'content': content,
          'type': 'm3u8',
          'isPlayable': true,
        };
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Playlist fetch error: $e');
      return null;
    }
  }

  /// Get M3U8 URL for IPTV Org source
  static Future<Map<String, dynamic>?> getIPTVOrgPlaylists() async {
    try {
      debugPrint('$_tag: Fetching IPTV Org playlists');

      final dio = getDioClient();
      final url =
          'https://iptv-org.github.io/api/channels.json'; // Returns JSON with m3u8 info

      final response = await dio.get(url);

      if (response.statusCode == 200) {
        debugPrint('$_tag: Successfully fetched IPTV Org channels');

        return {
          'source': 'IPTV Org',
          'data': response.data,
          'type': 'json',
          'isPlayable': true,
        };
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: IPTV Org fetch error: $e');
      return null;
    }
  }

  /// Fetch from a specific source
  static Future<Map<String, dynamic>?> _fetchFromSource(
    String baseUrl,
    String sourceName,
    String sourceType,
    String channelName,
  ) async {
    try {
      debugPrint('$_tag: Trying $sourceName...');

      final dio = getDioClient();

      switch (sourceType) {
        case 'playlist':
          return await _fetchPlaylist(baseUrl, sourceName, channelName, dio);

        case 'html':
          return await _fetchFromHtml(baseUrl, sourceName, channelName, dio);

        case 'json':
          return await _fetchFromJson(baseUrl, sourceName, channelName, dio);

        default:
          return null;
      }
    } catch (e) {
      debugPrint('$_tag: Source fetch error: $e');
      return null;
    }
  }

  /// Fetch and parse M3U8 playlist format
  static Future<Map<String, dynamic>?> _fetchPlaylist(
    String baseUrl,
    String sourceName,
    String channelName,
    Dio dio,
  ) async {
    try {
      final response = await dio.get(baseUrl).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final content = response.data as String;
        final m3u8Url = _searchInPlaylist(content, channelName);

        if (m3u8Url != null) {
          debugPrint('$_tag: Found m3u8 URL in $sourceName: $m3u8Url');
          return {
            'm3u8Url': m3u8Url,
            'title': channelName,
            'source': sourceName,
            'type': 'direct_m3u8',
            'isPlayable': true,
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Playlist fetch error for $sourceName: $e');
      return null;
    }
  }

  /// Fetch from HTML source
  static Future<Map<String, dynamic>?> _fetchFromHtml(
    String baseUrl,
    String sourceName,
    String channelName,
    Dio dio,
  ) async {
    try {
      final response = await dio.get(baseUrl).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final htmlDoc = html_parser.parse(response.data);

        // Look for m3u8 links in various HTML elements
        final m3u8Url = _extractM3u8FromHtml(htmlDoc, channelName);

        if (m3u8Url != null) {
          debugPrint('$_tag: Found m3u8 URL in $sourceName: $m3u8Url');
          return {
            'm3u8Url': m3u8Url,
            'title': channelName,
            'source': sourceName,
            'type': 'direct_m3u8',
            'isPlayable': true,
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: HTML fetch error for $sourceName: $e');
      return null;
    }
  }

  /// Fetch from JSON API
  static Future<Map<String, dynamic>?> _fetchFromJson(
    String baseUrl,
    String sourceName,
    String channelName,
    Dio dio,
  ) async {
    try {
      final response = await dio.get(baseUrl).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = response.data;

        if (jsonData is List) {
          final channel = jsonData.firstWhere(
            (item) => (item['name'] as String?)
                    ?.toLowerCase()
                    .contains(channelName.toLowerCase()) ??
                false,
            orElse: () => {},
          );

          if (channel != null && channel['url'] != null) {
            final m3u8Url = channel['url'] as String;
            debugPrint('$_tag: Found m3u8 URL in $sourceName: $m3u8Url');

            return {
              'm3u8Url': m3u8Url,
              'title': channel['name'] ?? channelName,
              'source': sourceName,
              'type': 'direct_m3u8',
              'isPlayable': true,
            };
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: JSON fetch error for $sourceName: $e');
      return null;
    }
  }

  /// Search for m3u8 URL in M3U8 playlist format
  static String? _searchInPlaylist(String content, String channelName) {
    try {
      final lines = content.split('\n');
      final lowerChannelName = channelName.toLowerCase();

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Look for lines containing the channel name
        if (line.toLowerCase().contains(lowerChannelName)) {
          // Check if the next line is a URL
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1].trim();
            if (nextLine.startsWith('http://') || nextLine.startsWith('https://')) {
              return nextLine;
            }
          }
        }

        // Also check for lines starting with http that contain channel name
        if ((line.startsWith('http://') || line.startsWith('https://')) &&
            line.toLowerCase().contains(lowerChannelName)) {
          return line;
        }
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Playlist search error: $e');
      return null;
    }
  }

  /// Extract m3u8 URL from HTML document
  static String? _extractM3u8FromHtml(
    html_dom.Document htmlDoc,
    String channelName,
  ) {
    try {
      // Search for links containing m3u8
      final links = htmlDoc.querySelectorAll('a[href*="m3u8"]');
      for (final link in links) {
        final href = link.attributes['href'];
        if (href != null &&
            (href.contains(channelName, 0) ||
                href.contains(channelName.toLowerCase()))) {
          return href;
        }
      }

      // Search for video src attributes
      final videos = htmlDoc.querySelectorAll('video source[src*="m3u8"]');
      for (final video in videos) {
        final src = video.attributes['src'];
        if (src != null) {
          return src;
        }
      }

      // Search for any m3u8 reference in script or data attributes
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

  /// Verify if m3u8 URL is accessible and valid
  static Future<bool> verifyM3u8Url(String m3u8Url) async {
    try {
      debugPrint('$_tag: Verifying m3u8 URL: $m3u8Url');

      final dio = getDioClient();
      final response = await dio
          .head(m3u8Url)
          .timeout(const Duration(seconds: 8))
          .catchError((e) {
        // Try GET if HEAD fails
        return dio.get(m3u8Url, options: Options(responseType: ResponseType.bytes));
      });

      final isValid = response.statusCode == 200 || response.statusCode == 206;

      if (isValid) {
        debugPrint('$_tag: M3U8 URL verified successfully');
      }

      return isValid;
    } catch (e) {
      debugPrint('$_tag: URL verification error: $e');
      return false;
    }
  }
}
