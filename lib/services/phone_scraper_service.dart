import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// General HTTP client service for streaming and media operations
/// Provides a pre-configured Dio client with proper headers, timeouts, and error handling
class PhoneScraperService {
  static const String _tag = 'HttpClientService';

  /// Get a pre-configured Dio client for HTTP requests
  /// 
  /// Features:
  /// - 15 second connection, receive, and send timeouts
  /// - Browser user-agent spoofing
  /// - Accept all content types
  /// - Redirect following enabled (max 5 redirects)
  /// - Gzip compression support
  static Dio getDioClient({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, String>? customHeaders,
  }) {
    return Dio(
      BaseOptions(
        connectTimeout: connectTimeout ?? const Duration(seconds: 15),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 15),
        sendTimeout: sendTimeout ?? const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate, br',
          'Referer': 'https://www.google.com/',
          ...?customHeaders,
        },
        followRedirects: true,
        maxRedirects: 5,
      ),
    );
  }

  /// Check if a URL is accessible
  /// Returns true if URL responds with 2xx, 3xx status codes
  static Future<bool> isUrlAccessible(
    String url, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      debugPrint('$_tag: Checking URL accessibility: $url');
      
      final dio = getDioClient(receiveTimeout: timeout);
      final response = await dio
          .head(url)
          .timeout(timeout)
          .catchError((e) {
        // Try GET if HEAD fails
        return dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
      });

      final isAccessible = response.statusCode! >= 200 && 
                          response.statusCode! < 400;
      
      debugPrint(
        '$_tag: URL accessibility check - $url: ${isAccessible ? 'OK' : 'FAILED'} '
        '(Status: ${response.statusCode})',
      );
      
      return isAccessible;
    } catch (e) {
      debugPrint('$_tag: URL accessibility check failed for $url: $e');
      return false;
    }
  }

  /// Fetch content from URL
  /// Returns the response data as String or Bytes depending on responseType
  static Future<dynamic> fetchContent(
    String url, {
    ResponseType responseType = ResponseType.plain,
    Duration timeout = const Duration(seconds: 30),
    Map<String, String>? headers,
  }) async {
    try {
      debugPrint('$_tag: Fetching content from: $url');
      
      final dio = getDioClient(
        receiveTimeout: timeout,
        customHeaders: headers,
      );
      
      final response = await dio
          .get<dynamic>(
            url,
            options: Options(responseType: responseType),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        debugPrint('$_tag: Successfully fetched content from $url');
        return response.data;
      }

      throw Exception('HTTP ${response.statusCode}: Failed to fetch content');
    } catch (e) {
      debugPrint('$_tag: Content fetch error: $e');
      rethrow;
    }
  }

  /// Check multiple URLs and return the first accessible one
  /// Useful for fallback URLs or mirror selection
  static Future<String?> findAccessibleUrl(
    List<String> urls, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      debugPrint('$_tag: Checking ${urls.length} URLs for accessibility...');
      
      for (final url in urls) {
        final isAccessible = await isUrlAccessible(url, timeout: timeout);
        if (isAccessible) {
          debugPrint('$_tag: Found accessible URL: $url');
          return url;
        }
      }

      debugPrint('$_tag: No accessible URLs found');
      return null;
    } catch (e) {
      debugPrint('$_tag: Error finding accessible URL: $e');
      return null;
    }
  }

  /// Verify if a URL is valid and accessible
  /// Combines URL validation with accessibility check
  static Future<bool> verifyUrl(
    String url, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      if (url.isEmpty) {
        debugPrint('$_tag: Empty URL provided for verification');
        return false;
      }

      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        debugPrint('$_tag: Invalid URL scheme: $url');
        return false;
      }

      return await isUrlAccessible(url, timeout: timeout);
    } catch (e) {
      debugPrint('$_tag: URL verification error: $e');
      return false;
    }
  }

  /// Make a HEAD request to check URL status
  /// Returns the HTTP status code or null if failed
  static Future<int?> getUrlStatus(
    String url, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final dio = getDioClient(receiveTimeout: timeout);
      
      final response = await dio
          .head(url)
          .timeout(timeout)
          .catchError((e) {
        return dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
      });

      return response.statusCode;
    } catch (e) {
      debugPrint('$_tag: Failed to get URL status: $e');
      return null;
    }
  }
}
