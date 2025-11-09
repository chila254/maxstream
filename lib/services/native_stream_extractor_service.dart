import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Service class to extract streaming URLs using native platform bridges
/// This service communicates with native Android and iOS implementations
/// to extract M3U8 URLs from embed pages using WebView
class NativeStreamExtractorService {
  static const platform = MethodChannel('com.maxstream/stream_extractor');

  /// Extract stream URL from an embed page using native WebView
  ///
  /// [embedUrl] - The embed page URL (e.g., https://vidsrc.to/embed/movie/tt1375666)
  /// [timeout] - Timeout duration in seconds (default: 30)
  /// Returns the extracted stream URL or null if not found
  static Future<StreamExtractionResult> extractStream(
    String embedUrl, {
    int timeoutSeconds = 30,
  }) async {
    try {
      debugPrint(
        'NativeStreamExtractorService: Starting extraction for: $embedUrl',
      );

      final result = await platform
          .invokeMethod<Map<dynamic, dynamic>>(
            'extractStream',
            {
              'url': embedUrl,
              'timeout': timeoutSeconds,
            },
          )
          .timeout(
            Duration(seconds: timeoutSeconds + 5),
            onTimeout: () => throw TimeoutException(
              'Stream extraction timed out after $timeoutSeconds seconds',
            ),
          );

      if (result == null) {
        return StreamExtractionResult.failure(
          'No response from native platform',
        );
      }

      final success = result['success'] as bool? ?? false;
      final streamUrl = result['streamUrl'] as String?;
      final error = result['error'] as String?;
      final source = result['source'] as String? ?? 'native_bridge';

      debugPrint(
        'NativeStreamExtractorService: Extraction result - success: $success, source: $source',
      );

      if (success && streamUrl != null && streamUrl.isNotEmpty) {
        debugPrint(
          'NativeStreamExtractorService: Stream found: $streamUrl',
        );
        return StreamExtractionResult.success(
          streamUrl: streamUrl,
          source: source,
          message: 'Stream extracted successfully using native bridge',
        );
      } else {
        final errorMsg = error ?? 'Failed to extract stream from embed page';
        debugPrint(
          'NativeStreamExtractorService: Extraction failed - $errorMsg',
        );
        return StreamExtractionResult.failure(errorMsg);
      }
    } on TimeoutException catch (e) {
      debugPrint('NativeStreamExtractorService: Timeout - ${e.message}');
      return StreamExtractionResult.failure(
        'Extraction timeout: ${e.message}',
      );
    } on PlatformException catch (e) {
      debugPrint(
        'NativeStreamExtractorService: Platform exception - ${e.code}: ${e.message}',
      );
      return StreamExtractionResult.failure(
        'Platform error: ${e.message ?? e.code}',
      );
    } catch (e) {
      debugPrint('NativeStreamExtractorService: Error - $e');
      return StreamExtractionResult.failure(
        'Error extracting stream: ${e.toString()}',
      );
    }
  }

  /// Check if the native stream extractor is available and healthy
  static Future<bool> isAvailable() async {
    try {
      final result = await platform
          .invokeMethod<bool>('isAvailable')
          .timeout(const Duration(seconds: 5));
      return result ?? false;
    } catch (e) {
      debugPrint('NativeStreamExtractorService: Availability check failed - $e');
      return false;
    }
  }

  /// Clear WebView cache (optional, for cleanup)
  static Future<void> clearCache() async {
    try {
      await platform.invokeMethod('clearCache');
      debugPrint('NativeStreamExtractorService: Cache cleared');
    } catch (e) {
      debugPrint('NativeStreamExtractorService: Cache clear failed - $e');
    }
  }

  /// Dispose resources used by native stream extractor
  static Future<void> dispose() async {
    try {
      await platform.invokeMethod('dispose');
      debugPrint('NativeStreamExtractorService: Disposed');
    } catch (e) {
      debugPrint('NativeStreamExtractorService: Dispose failed - $e');
    }
  }
}

/// Result class for stream extraction
class StreamExtractionResult {
  final bool success;
  final String? streamUrl;
  final String? error;
  final String? message;
  final String source;

  const StreamExtractionResult({
    required this.success,
    this.streamUrl,
    this.error,
    this.message,
    required this.source,
  });

  /// Create successful result
  factory StreamExtractionResult.success({
    required String streamUrl,
    required String source,
    String? message,
  }) {
    return StreamExtractionResult(
      success: true,
      streamUrl: streamUrl,
      source: source,
      message: message ?? 'Stream extracted successfully',
    );
  }

  /// Create failure result
  factory StreamExtractionResult.failure(String error) {
    return StreamExtractionResult(
      success: false,
      error: error,
      source: 'native_bridge',
    );
  }

  @override
  String toString() {
    return 'StreamExtractionResult(success: $success, streamUrl: $streamUrl, error: $error, message: $message, source: $source)';
  }
}
