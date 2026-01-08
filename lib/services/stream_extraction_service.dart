import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

/// Direct stream extraction service
/// Extracts actual video URLs from embed sources
class StreamExtractionService {
  static const String _tag = 'StreamExtractionService';

  static Dio _getDioClient() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
        },
        followRedirects: true,
        maxRedirects: 5,
      ),
    );
  }

  /// Extract direct video URL from embed URL
  static Future<Map<String, dynamic>?> extractDirectUrl(
    String embedUrl, {
    String quality = '720p',
  }) async {
    try {
      debugPrint('');
      debugPrint('$_tag: ╔════════════════════════════════════════════╗');
      debugPrint('$_tag: ║     DIRECT URL EXTRACTION STARTED         ║');
      debugPrint('$_tag: ╚════════════════════════════════════════════╝');
      debugPrint('$_tag: Embed URL: $embedUrl');
      debugPrint('$_tag: Target Quality: $quality');
      debugPrint('');

      final dio = _getDioClient();

      // Load the embed page
      debugPrint('$_tag: 📄 Loading embed page...');
      final response = await dio.get(embedUrl);

      if (response.statusCode != 200) {
        debugPrint(
          '$_tag: ❌ Failed to load embed page: ${response.statusCode}',
        );
        return null;
      }

      final html = response.data as String;
      debugPrint('$_tag: ✓ Embed page loaded (${html.length} chars)');

      // Parse HTML
      final document = parse(html);

      // Extract video URLs using multiple strategies
      final videoUrls = await _extractVideoUrls(document, embedUrl);

      if (videoUrls.isEmpty) {
        debugPrint('$_tag: ❌ No video URLs found');
        return null;
      }

      debugPrint('$_tag: ✓ Found ${videoUrls.length} video URLs');

      // Select best quality URL
      final bestUrl = _selectBestQualityUrl(videoUrls, quality);

      if (bestUrl == null) {
        debugPrint('$_tag: ❌ No suitable video URL found');
        return null;
      }

      debugPrint('');
      debugPrint('$_tag: ╔════════════════════════════════════════════╗');
      debugPrint('$_tag: ║     DIRECT URL EXTRACTION SUCCESS ✓       ║');
      debugPrint('$_tag: ╚════════════════════════════════════════════╝');
      debugPrint('$_tag: 🎬 Direct Video URL: $bestUrl');
      debugPrint('$_tag: 🎯 Quality: $quality');
      debugPrint('');

      return {
        'directUrl': bestUrl,
        'quality': quality,
        'source': _getSourceFromUrl(embedUrl),
        'type': 'direct',
        'method': 'html_parsing',
        'isPlayable': true,
        'message': 'Direct video stream extracted successfully',
      };
    } catch (e) {
      debugPrint('$_tag: ❌ EXTRACTION ERROR: $e');
      return null;
    }
  }

  /// Extract video URLs from HTML document
  static Future<List<String>> _extractVideoUrls(
    Document document,
    String baseUrl,
  ) async {
    final urls = <String>{}; // Use Set to avoid duplicates

    try {
      // Strategy 1: Look for video elements
      final videoElements = document.querySelectorAll('video');
      for (final video in videoElements) {
        final src = video.attributes['src'];
        if (src != null && _isValidVideoUrl(src)) {
          urls.add(_resolveUrl(src, baseUrl));
        }

        // Check source elements within video
        final sources = video.querySelectorAll('source');
        for (final source in sources) {
          final src = source.attributes['src'];
          if (src != null && _isValidVideoUrl(src)) {
            urls.add(_resolveUrl(src, baseUrl));
          }
        }
      }

      // Strategy 2: Look for script tags containing video URLs
      final scripts = document.querySelectorAll('script');
      for (final script in scripts) {
        final content = script.text;
        final extractedUrls = _extractUrlsFromScript(content);
        for (final url in extractedUrls) {
          if (_isValidVideoUrl(url)) {
            urls.add(_resolveUrl(url, baseUrl));
          }
        }
      }

      // Strategy 3: Look for data attributes or custom attributes
      final allElements = document.querySelectorAll(
        '[src], [data-src], [data-video], [data-url]',
      );
      for (final element in allElements) {
        final attributes = ['src', 'data-src', 'data-video', 'data-url'];
        for (final attr in attributes) {
          final value = element.attributes[attr];
          if (value != null && _isValidVideoUrl(value)) {
            urls.add(_resolveUrl(value, baseUrl));
          }
        }
      }

      // Strategy 4: Look for JSON data in scripts
      for (final script in scripts) {
        final content = script.text;
        final jsonUrls = _extractUrlsFromJson(content);
        for (final url in jsonUrls) {
          if (_isValidVideoUrl(url)) {
            urls.add(_resolveUrl(url, baseUrl));
          }
        }
      }

      // Strategy 5: Look for iframe src (fallback to embed)
      final iframes = document.querySelectorAll('iframe');
      for (final iframe in iframes) {
        final src = iframe.attributes['src'];
        if (src != null && _isValidVideoUrl(src)) {
          urls.add(_resolveUrl(src, baseUrl));
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error extracting URLs: $e');
    }

    return urls.toList();
  }

  /// Extract URLs from JavaScript content using simple string operations
  static List<String> _extractUrlsFromScript(String script) {
    final urls = <String>[];

    try {
      // Split script into lines for easier processing
      final lines = script.split('\n');

      for (final line in lines) {
        // Look for common video URL patterns
        final urlCandidates = _findUrlCandidates(line);

        for (final candidate in urlCandidates) {
          if (_isValidVideoUrl(candidate)) {
            urls.add(candidate);
          }
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error in script parsing: $e');
    }

    return urls;
  }

  /// Find URL candidates in a line of text
  static List<String> _findUrlCandidates(String line) {
    final candidates = <String>[];

    // Look for URLs starting with http/https
    final httpIndex = line.indexOf('http');
    if (httpIndex != -1) {
      // Find the end of the URL (look for quotes, spaces, or other delimiters)
      var endIndex = httpIndex;
      final delimiters = [
        '"',
        "'",
        ' ',
        '\t',
        '\n',
        '\r',
        ',',
        ';',
        ')',
        ']',
        '}',
        '|',
      ];

      while (endIndex < line.length) {
        final char = line[endIndex];
        if (delimiters.contains(char)) {
          break;
        }
        endIndex++;
      }

      if (endIndex > httpIndex) {
        final url = line.substring(httpIndex, endIndex);
        if (url.length > 10) {
          // Minimum reasonable URL length
          candidates.add(url);
        }
      }
    }

    // Look for URLs in quotes
    final quotePatterns = ['"', "'"];
    for (final quote in quotePatterns) {
      var startIndex = 0;
      while (true) {
        final quoteStart = line.indexOf(quote, startIndex);
        if (quoteStart == -1) break;

        final quoteEnd = line.indexOf(quote, quoteStart + 1);
        if (quoteEnd == -1) break;

        final content = line.substring(quoteStart + 1, quoteEnd);
        if (content.startsWith('http') && content.length > 10) {
          candidates.add(content);
        }

        startIndex = quoteEnd + 1;
      }
    }

    return candidates;
  }

  /// Extract URLs from JSON content
  static List<String> _extractUrlsFromJson(String content) {
    final urls = <String>[];

    try {
      // Try to parse as JSON
      final jsonData = json.decode(content);
      _extractUrlsFromJsonObject(jsonData, urls);
    } catch (e) {
      // Not valid JSON, skip
    }

    return urls;
  }

  /// Recursively extract URLs from JSON object
  static void _extractUrlsFromJsonObject(dynamic obj, List<String> urls) {
    if (obj is String && _isValidVideoUrl(obj)) {
      urls.add(obj);
    } else if (obj is Map) {
      for (final value in obj.values) {
        _extractUrlsFromJsonObject(value, urls);
      }
    } else if (obj is List) {
      for (final item in obj) {
        _extractUrlsFromJsonObject(item, urls);
      }
    }
  }

  /// Check if URL is a valid video URL
  static bool _isValidVideoUrl(String url) {
    if (url.isEmpty) return false;

    final videoExtensions = [
      '.m3u8',
      '.mp4',
      '.avi',
      '.mkv',
      '.webm',
      '.flv',
      '.mov',
      '.wmv',
    ];
    final streamingProtocols = ['rtmp://', 'rtsp://', 'mms://'];

    final lowerUrl = url.toLowerCase();

    // Check for video file extensions
    if (videoExtensions.any((ext) => lowerUrl.contains(ext))) {
      return true;
    }

    // Check for streaming protocols
    if (streamingProtocols.any((protocol) => lowerUrl.startsWith(protocol))) {
      return true;
    }

    // Check for common video hosting patterns
    if (lowerUrl.contains('.m3u8') ||
        lowerUrl.contains('playlist') ||
        lowerUrl.contains('stream') ||
        lowerUrl.contains('video') ||
        lowerUrl.contains('cdn') ||
        lowerUrl.contains('media')) {
      return true;
    }

    return false;
  }

  /// Resolve relative URLs to absolute URLs
  static String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    try {
      final baseUri = Uri.parse(baseUrl);
      final resolvedUri = baseUri.resolve(url);
      return resolvedUri.toString();
    } catch (e) {
      return url;
    }
  }

  /// Select best quality URL from available options
  static String? _selectBestQualityUrl(
    List<String> urls,
    String targetQuality,
  ) {
    if (urls.isEmpty) return null;

    // Quality preferences
    final qualityPreferences = {
      '1080p': ['1080', 'fullhd', 'fhd', 'hd'],
      '720p': ['720', 'hd'],
      '480p': ['480', 'sd'],
    };

    final targetKeywords = qualityPreferences[targetQuality] ?? [targetQuality];

    // First, try to find URLs matching target quality
    for (final keyword in targetKeywords) {
      for (final url in urls) {
        if (url.toLowerCase().contains(keyword.toLowerCase())) {
          return url;
        }
      }
    }

    // Fallback: return first valid URL
    return urls.first;
  }

  /// Get source name from URL
  static String _getSourceFromUrl(String url) {
    if (url.contains('vidsrc.me')) return 'VidSrc.me';
    if (url.contains('vidsrc.icu')) return 'VidSrc.icu';
    if (url.contains('vidsrc.pro')) return 'VidSrc.pro';
    if (url.contains('moviesapi.club')) return 'MoviesAPI';
    return 'Unknown Source';
  }

  /// Test if a direct URL is accessible
  static Future<bool> testUrlAccessibility(String url) async {
    try {
      final dio = _getDioClient();
      final response = await dio.head(
        url,
        options: Options(validateStatus: (status) => status! < 500),
      );
      return response.statusCode! < 400;
    } catch (e) {
      return false;
    }
  }

  /// Health check
  static Future<Map<String, bool>> checkHealth() async {
    try {
      // Test with a known working embed URL
      const testUrl =
          'https://vidsrc.me/embed/movie/278'; // The Shawshank Redemption
      final result = await extractDirectUrl(testUrl);
      final isHealthy = result != null && result['directUrl'] != null;
      return {'stream_extraction': isHealthy, 'overall': isHealthy};
    } catch (e) {
      debugPrint('$_tag: Health check error: $e');
      return {'stream_extraction': false, 'overall': false};
    }
  }

  /// Clear caches
  static Future<void> clearCaches() async {
    try {
      debugPrint('$_tag: Caches cleared');
    } catch (e) {
      debugPrint('$_tag: Cache clear error: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      debugPrint('$_tag: Service disposed');
    } catch (e) {
      debugPrint('$_tag: Dispose error: $e');
    }
  }
}
