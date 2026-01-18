import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

/// Service to fetch video streams from Net20
class Net20Service {
  static const String _tag = 'Net20Service';
  static const String baseUrl = 'https://net20.cc';

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

  /// Get video URL directly (bypasses search if you have the IDs)
  static Future<Map<String, dynamic>?> getVideoUrlDirect(
    String detailPath,
    String subjectId, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      debugPrint('$_tag: Getting video directly for: $detailPath');

      return await extractVideoUrl(
        detailPath,
        season: season,
        episode: episode,
        subjectId: subjectId,
      );
    } catch (e) {
      debugPrint('$_tag: getVideoUrlDirect error: $e');
      return null;
    }
  }

  /// Search and get video URL in one call
  static Future<Map<String, dynamic>?> getVideoUrl(
    String title, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      final searchResult = await searchContent(title, true);
      if (searchResult == null) {
        debugPrint(
          '$_tag: Search returned null - Net20 search uses JavaScript',
        );
        debugPrint(
          '$_tag: Use getVideoUrlDirect() if you have the subjectId and detailPath',
        );
        return null;
      }

      final subjectId = searchResult['subjectId'] as String?;
      final detailPath = searchResult['detailPath'] as String?;

      if (subjectId == null || detailPath == null) {
        debugPrint('$_tag: Missing subjectId or detailPath from search');
        return null;
      }

      final videoData = await extractVideoUrl(
        detailPath,
        season: season,
        episode: episode,
        subjectId: subjectId,
      );

      if (videoData != null) {
        return {...videoData, 'title': searchResult['title']};
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: getVideoUrl error: $e');
      return null;
    }
  }

  /// Search for a movie/series on Net20
  static Future<Map<String, dynamic>?> searchContent(
    String title,
    bool isMovie,
  ) async {
    try {
      debugPrint('$_tag: Searching for "$title" on Net20...');

      final dio = _getDioClient();
      final searchUrl = '$baseUrl/search?q=${Uri.encodeComponent(title)}';

      final response = await dio.get(searchUrl);
      if (response.statusCode != 200) {
        debugPrint('$_tag: Search failed: ${response.statusCode}');
        return null;
      }

      final html = response.data as String;
      final document = parse(html);

      // Look for all links that match the video page pattern
      // Pattern: /spa/videoPlayPage/{type}/{slug}?id={subjectId}
      final allLinks = document.querySelectorAll('a');

      debugPrint('$_tag: Found ${allLinks.length} links in page');

      for (final link in allLinks) {
        final href = link.attributes['href'] ?? '';

        // Check if link matches video page pattern
        if (!href.contains('/spa/videoPlayPage/')) {
          continue;
        }

        final subjectIdMatch = RegExp(r'[?&]id=(\d+)').firstMatch(href);
        final detailPathMatch = RegExp(
          r'/(?:movies|series)/([a-zA-Z0-9\-_]+)',
        ).firstMatch(href);

        if (subjectIdMatch == null || detailPathMatch == null) {
          continue;
        }

        final subjectId = subjectIdMatch.group(1);
        final detailPath = detailPathMatch.group(1);

        // Try to get the title from the link text or nearby elements
        String? resultTitle = link.text.trim();

        if (resultTitle.isEmpty) {
          // Try to find title in parent or sibling elements
          final parent = link.parent;
          final titleEl =
              parent?.querySelector('[class*="title"]') ??
              parent?.querySelector('h1') ??
              parent?.querySelector('h2') ??
              parent?.querySelector('h3');
          resultTitle = titleEl?.text.trim() ?? title;
        }

        debugPrint(
          '$_tag: Found: $resultTitle (id: $subjectId, path: $detailPath)',
        );

        return {
          'title': resultTitle,
          'url': href,
          'subjectId': subjectId,
          'detailPath': detailPath,
          'source': 'Net20',
        };
      }

      debugPrint('$_tag: No results matching video page pattern');
      return null;
    } catch (e) {
      debugPrint('$_tag: Search error: $e');
      return null;
    }
  }

  /// Extract video URL from Net20 API
  static Future<Map<String, dynamic>?> extractVideoUrl(
    String detailPath, {
    int season = 1,
    int episode = 1,
    String? subjectId,
  }) async {
    try {
      debugPrint('$_tag: Extracting video for: $detailPath');

      final dio = _getDioClient();

      if (subjectId == null) {
        debugPrint('$_tag: subjectId is required');
        return null;
      }

      // Call the video source API
      final apiUrl =
          '$baseUrl/wefeed-h5-bff/web/subject/play?subjectId=$subjectId&se=$season&ep=$episode&detail_path=$detailPath';

      debugPrint('$_tag: Calling API: $apiUrl');

      final response = await dio.get(apiUrl);

      if (response.statusCode != 200) {
        debugPrint('$_tag: API call failed: ${response.statusCode}');
        return null;
      }

      debugPrint('$_tag: API response: ${response.data}');

      final data = response.data as Map<String, dynamic>?;

      if (data == null) {
        debugPrint('$_tag: API response is null');
        return null;
      }

      if (data['code'] != 0) {
        debugPrint('$_tag: API error: ${data['message']}');
        return null;
      }

      final streams = (data['data']?['streams'] as List?)
          ?.cast<Map<String, dynamic>>();

      if (streams == null || streams.isEmpty) {
        debugPrint('$_tag: No video streams found in response');
        debugPrint('$_tag: Response data: ${data['data']}');
        return null;
      }

      debugPrint('$_tag: Found ${streams.length} streams');

      // Prefer highest resolution (1080p > 480p)
      streams.sort((a, b) {
        final resA = int.tryParse(a['resolutions']?.toString() ?? '0') ?? 0;
        final resB = int.tryParse(b['resolutions']?.toString() ?? '0') ?? 0;
        return resB.compareTo(resA);
      });

      final bestStream = streams.first;
      final videoUrl = bestStream['url'] as String?;
      final resolution = bestStream['resolutions'] as String?;
      final duration = bestStream['duration'] as int?;

      if (videoUrl == null) {
        debugPrint('$_tag: No video URL in stream');
        return null;
      }

      debugPrint('$_tag: Selected ${resolution}p stream');

      return {
        'videoUrl': videoUrl,
        'source': 'Net20',
        'type': 'mp4',
        'quality': '${resolution}p',
        'duration': duration,
        'isPlayable': true,
      };
    } catch (e) {
      debugPrint('$_tag: Extraction error: $e');
      return null;
    }
  }
}
