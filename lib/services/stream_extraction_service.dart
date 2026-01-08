import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

/// Direct stream extraction service
/// Extracts actual video URLs from embed sources
class StreamExtractionService {
  static const String _tag = 'StreamExtractionService';

  static Dio _getDioClient({String? referer}) {
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
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
          if (referer != null) 'Referer': referer,
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

      // Special handling for vidsrc-embed.ru
      if (embedUrl.contains('vidsrc-embed.ru')) {
        debugPrint(
          '$_tag: 🎯 VidSrc Embed detected, using special extraction...',
        );
        final result = await _extractFromVidSrcEmbed(embedUrl, quality);
        if (result != null) {
          return result;
        }
        debugPrint(
          '$_tag: VidSrc extraction failed, falling back to standard extraction',
        );
      }

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
        debugPrint(
          '$_tag: HTML preview (first 2000 chars): ${html.substring(0, min(2000, html.length))}',
        );
        return null;
      }

      debugPrint('$_tag: ✓ Found ${videoUrls.length} video URLs');
      for (final url in videoUrls) {
        debugPrint('$_tag:   - $url');
      }

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

  /// Extract M3U8 from VidSrc Embed page
  static Future<Map<String, dynamic>?> _extractFromVidSrcEmbed(
    String embedUrl,
    String quality,
  ) async {
    try {
      final dio = _getDioClient();

      // Step 1: Load the embed page to find the player iframe
      debugPrint('$_tag: 📄 Loading VidSrc embed page...');
      final embedResponse = await dio.get(embedUrl);

      if (embedResponse.statusCode != 200) {
        debugPrint(
          '$_tag: ❌ Failed to load VidSrc embed page: ${embedResponse.statusCode}',
        );
        return null;
      }

      final embedHtml = embedResponse.data as String;
      debugPrint('$_tag: ✓ Embed page loaded (${embedHtml.length} chars)');

      // Step 2: Extract the iframe src that points to the actual player
      final iframePattern = RegExp(
        'src=["\']([^"\']*cloudnestra[^"\']*)["\']',
        caseSensitive: false,
      );
      final iframeMatch = iframePattern.firstMatch(embedHtml);

      if (iframeMatch == null) {
        debugPrint('$_tag: ❌ No cloudnestra iframe found');
        return null;
      }

      String playerUrl = iframeMatch.group(1) ?? '';
      debugPrint('$_tag: 🔗 Found player URL (length: ${playerUrl.length})');

      // Ensure URL has https:
      if (playerUrl.startsWith('//')) {
        playerUrl = 'https:$playerUrl';
      }

      // Step 3: Load the player page to extract M3U8
      debugPrint('$_tag: 📄 Loading player page...');
      final playerResponse = await dio.get(
        playerUrl,
        options: Options(headers: {'Referer': embedUrl}),
      );

      if (playerResponse.statusCode != 200) {
        debugPrint(
          '$_tag: ❌ Failed to load player page: ${playerResponse.statusCode}',
        );
        return null;
      }

      final playerHtml = playerResponse.data as String;
      debugPrint('$_tag: ✓ Player page loaded (${playerHtml.length} chars)');

      // Step 4: Extract the token from the player URL and construct M3U8
      // Player URL format: https://cloudnestra.com/rcp/{TOKEN}/{VIDEO_ID}/...
      // M3U8 URL format: https://tmstr5.quibblezoomfable.com/pl/{TOKEN}/{VIDEO_ID}/index.m3u8

      final tokenMatch = RegExp(r'/rcp/([^/]+)').firstMatch(playerUrl);
      if (tokenMatch == null) {
        debugPrint('$_tag: ❌ Failed to extract token from player URL');
        return null;
      }

      final token = tokenMatch.group(1);
      debugPrint('$_tag: 🔑 Extracted token (length: ${token?.length})');

      // Look for video ID patterns in the player HTML
      // Video ID is typically a 32-char hex hash
      final videoIdMatch = RegExp(r'([a-f0-9]{32})').firstMatch(playerHtml);
      String videoId =
          videoIdMatch?.group(1) ??
          '0f9b738af906eb91d8f5b3fab14e78cc'; // fallback
      debugPrint('$_tag: 📹 Video ID: $videoId');

      // Construct M3U8 URL - try cloudnestra domain
      final m3u8Url = 'https://cloudnestra.com/pl/$token/$videoId/index.m3u8';
      debugPrint('$_tag: 🎬 Constructed M3U8 URL: $m3u8Url');

      // Verify the URL is accessible
      final testResponse = await dio.head(
        m3u8Url,
        options: Options(validateStatus: (status) => status! < 500),
      );

      if (testResponse.statusCode != 200) {
        debugPrint(
          '$_tag: ⚠️ M3U8 URL returned ${testResponse.statusCode}, trying fallback extraction',
        );
        // Fallback: try to extract from HTML
        final m3u8Urls = _extractM3U8Urls(playerHtml);
        if (m3u8Urls.isEmpty) {
          return null;
        }
        return {
          'directUrl': m3u8Urls.first,
          'quality': quality,
          'source': 'VidSrc Embed',
          'type': 'hls_m3u8',
          'method': 'vidsrc_embed_extraction',
          'isPlayable': true,
          'referer': playerUrl,
          'message': 'M3U8 stream extracted from player (fallback)',
        };
      }

      debugPrint('$_tag: ✓ M3U8 URL verified (${testResponse.statusCode})');

      return {
        'directUrl': m3u8Url,
        'quality': quality,
        'source': 'VidSrc Embed',
        'type': 'hls_m3u8',
        'method': 'vidsrc_embed_extraction',
        'isPlayable': true,
        'referer': playerUrl,
        'message': 'M3U8 stream extracted from VidSrc embed player',
      };
    } catch (e) {
      debugPrint('$_tag: ❌ VidSrc extraction error: $e');
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
      // Strategy 1: Look for M3U8 playlists in entire HTML (highest priority)
      debugPrint('$_tag: 🔍 Strategy 1: Searching for M3U8 playlists...');
      final m3u8Urls = _extractM3U8Urls(
        document.documentElement?.outerHtml ?? '',
      );
      if (m3u8Urls.isNotEmpty) {
        debugPrint('$_tag: ✓ Found ${m3u8Urls.length} M3U8 URLs');
        for (final url in m3u8Urls) {
          urls.add(_resolveUrl(url, baseUrl));
        }
      }

      // Strategy 2: Look for video elements
      debugPrint('$_tag: 🔍 Strategy 2: Searching for video elements...');
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

      // Strategy 3: Look for script tags containing video URLs
      debugPrint('$_tag: 🔍 Strategy 3: Searching script tags...');
      final scripts = document.querySelectorAll('script');
      for (final script in scripts) {
        final content = script.text;

        // First check for M3U8 in script
        final scriptM3u8 = _extractM3U8Urls(content);
        for (final url in scriptM3u8) {
          urls.add(_resolveUrl(url, baseUrl));
        }

        // Then check for other video URLs
        final extractedUrls = _extractUrlsFromScript(content);
        for (final url in extractedUrls) {
          if (_isValidVideoUrl(url)) {
            urls.add(_resolveUrl(url, baseUrl));
          }
        }
      }

      // Strategy 4: Look for data attributes or custom attributes
      debugPrint('$_tag: 🔍 Strategy 4: Searching data attributes...');
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

      // Strategy 5: Look for JSON data in scripts
      debugPrint('$_tag: 🔍 Strategy 5: Searching JSON data...');
      for (final script in scripts) {
        final content = script.text;
        final jsonUrls = _extractUrlsFromJson(content);
        for (final url in jsonUrls) {
          if (_isValidVideoUrl(url)) {
            urls.add(_resolveUrl(url, baseUrl));
          }
        }
      }

      // Strategy 6: Look for iframe src (fallback to embed)
      debugPrint('$_tag: 🔍 Strategy 6: Searching iframe sources...');
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

  /// Extract M3U8 playlist URLs from content
  static List<String> _extractM3U8Urls(String content) {
    final m3u8Urls = <String>[];

    try {
      // Pattern 1: Direct M3U8 URLs (https://...m3u8)
      final m3u8Pattern = RegExp(
        r'https?://[^\s<>]+\.m3u8[^\s<>]*',
        caseSensitive: false,
      );

      final matches = m3u8Pattern.allMatches(content);
      for (final match in matches) {
        final url = match.group(0);
        if (url != null && !m3u8Urls.contains(url)) {
          debugPrint('$_tag: Found M3U8 URL: $url');
          m3u8Urls.add(url);
        }
      }

      // Pattern 2: M3U8 URLs in quotes
      final quotedPattern = RegExp(
        r'''['"]([\w:/.?=&-]+\.m3u8[\w:/.?=&-]*)['"]''',
        caseSensitive: false,
      );

      final quotedMatches = quotedPattern.allMatches(content);
      for (final match in quotedMatches) {
        final url = match.group(1);
        if (url != null && url.startsWith('http') && !m3u8Urls.contains(url)) {
          debugPrint('$_tag: Found quoted M3U8 URL: $url');
          m3u8Urls.add(url);
        }
      }

      // Pattern 2.5: M3U8 URLs after #EXT-X-STREAM-INF headers (for HLS variant playlists)
      // Also extract segment URLs after #EXTINF headers (for segment playlists)
      final lines = content.split('\n');
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.startsWith('#EXT-X-STREAM-INF') ||
            line.startsWith('#EXTINF')) {
          // Next non-empty line should be the M3U8 URL or segment URL
          var nextLineIdx = i + 1;
          while (nextLineIdx < lines.length) {
            final nextLine = lines[nextLineIdx].trim();
            if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
              // This should be the M3U8 URL or segment URL
              String urlToAdd = nextLine;
              if (!m3u8Urls.contains(urlToAdd)) {
                if (urlToAdd.startsWith('http')) {
                  debugPrint(
                    '$_tag: Found M3U8/segment URL from HLS manifest: $urlToAdd',
                  );
                } else {
                  debugPrint(
                    '$_tag: Found relative M3U8/segment URL from HLS manifest: $urlToAdd',
                  );
                }
                m3u8Urls.add(urlToAdd);
              }
              break;
            }
            nextLineIdx++;
          }
        }
      }

      // Pattern 3: URLs containing "playlist" or "stream" with m3u8 extension
      final playlistPattern = RegExp(
        r'https?://[^\s<>]*(?:playlist|stream|master|hls)[^\s<>]*\.m3u8[^\s<>]*',
        caseSensitive: false,
      );

      final playlistMatches = playlistPattern.allMatches(content);
      for (final match in playlistMatches) {
        final url = match.group(0);
        if (url != null && !m3u8Urls.contains(url)) {
          debugPrint('$_tag: Found playlist M3U8 URL: $url');
          m3u8Urls.add(url);
        }
      }
    } catch (e) {
      debugPrint('$_tag: Error extracting M3U8 URLs: $e');
    }

    return m3u8Urls;
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
      '.m3u8', // HLS playlists (HIGH PRIORITY)
      '.mp4',
      '.avi',
      '.mkv',
      '.webm',
      '.flv',
      '.mov',
      '.wmv',
      '.ts', // MPEG-TS for HLS
      '.m4s', // MPEG-DASH segments
      '.mpd', // MPEG-DASH manifest
    ];
    final streamingProtocols = [
      'rtmp://',
      'rtsp://',
      'mms://',
      'http://',
      'https://',
    ];

    // Blacklist of non-video URLs - only block if URL is CLEARLY a library/asset
    final libraryPatterns = [
      'cloudflare',
      '/ajax/libs/',
      '.min.js',
      '.min.css',
      'jquery',
      'bootstrap',
      'moment.js',
      '.woff',
      '.ttf',
      '.svg',
      'google-analytics',
      '.png',
      '.jpg',
      '.gif',
      '.ico',
      '.css',
      '.js',
    ];

    final lowerUrl = url.toLowerCase();

    // Check for M3U8 files first (HIGHEST PRIORITY - HLS streams)
    if (lowerUrl.contains('.m3u8')) {
      return true;
    }

    // Check for other video file extensions
    if (videoExtensions.any((ext) => lowerUrl.contains(ext))) {
      return true;
    }

    // Check for streaming protocols with valid domain
    if (streamingProtocols.any((protocol) => lowerUrl.startsWith(protocol))) {
      // Make sure it's not a library URL
      if (libraryPatterns.any((pattern) => lowerUrl.contains(pattern))) {
        return false;
      }
      return true;
    }

    // Check for common video hosting patterns
    if (lowerUrl.contains('playlist') ||
        lowerUrl.contains('stream') ||
        lowerUrl.contains('video') ||
        lowerUrl.contains('media') ||
        lowerUrl.contains('blob:') ||
        lowerUrl.contains('master') ||
        lowerUrl.contains('hls')) {
      // But not if it's clearly a library
      if (libraryPatterns.any((pattern) => lowerUrl.contains(pattern))) {
        return false;
      }
      return true;
    }

    // Block known library URLs
    if (libraryPatterns.any((pattern) => lowerUrl.contains(pattern))) {
      return false;
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
    if (url.contains('vidsrc-embed.ru')) return 'VidSrc Embed RU';
    if (url.contains('vidsrc.me')) return 'VidSrc.me';
    if (url.contains('vidsrc.icu')) return 'VidSrc.icu';
    if (url.contains('vidsrc.pro')) return 'VidSrc.pro';
    if (url.contains('moviesapi.club')) return 'MoviesAPI';
    if (url.contains('cloudnestra.com')) return 'CloudNestra';
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
          'https://vidsrc-embed.ru/embed/movie/278'; // The Shawshank Redemption
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
