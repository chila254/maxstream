import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service to communicate with MaxStream backend
class BackendService {
  static const String _tag = 'BackendService';
  static const String baseUrl = 'http://192.168.88.16:3000'; // Your laptop IP

  static Dio _getDioClient() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  /// Search for video by title - returns ALL available streams
  static Future<Map<String, dynamic>?> searchVideo(
    String title, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      debugPrint('$_tag: Searching for "$title"');

      final dio = _getDioClient();
      final url =
          '$baseUrl/api/video/search?title=${Uri.encodeComponent(title)}&season=$season&episode=$episode';

      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          final streamCount = data['streamCount'] ?? 1;
          debugPrint('$_tag: Found: ${data['title']} ($streamCount streams available)');
          return data;
        }
      }

      debugPrint('$_tag: Search failed - ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('$_tag: Search error: $e');
      return null;
    }
  }

  /// Get video by direct IDs
  static Future<Map<String, dynamic>?> getVideoDirect(
    String subjectId,
    String detailPath, {
    int season = 1,
    int episode = 1,
  }) async {
    try {
      debugPrint('$_tag: Getting video directly for: $detailPath');

      final dio = _getDioClient();
      final url =
          '$baseUrl/api/video/direct?subjectId=$subjectId&detailPath=$detailPath&season=$season&episode=$episode';

      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          debugPrint('$_tag: Got video - Quality: ${data['quality']}');
          return data;
        }
      }

      debugPrint('$_tag: Failed to get video - ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('$_tag: Error: $e');
      return null;
    }
  }

  /// Check if backend is available
  static Future<bool> healthCheck() async {
    try {
      final dio = _getDioClient();
      final response = await dio.get('$baseUrl/health');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('$_tag: Backend unavailable: $e');
      return false;
    }
  }
}
