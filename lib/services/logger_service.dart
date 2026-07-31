import 'package:flutter/foundation.dart';

/// Simple logging service for MaxStream
/// Replaces print() and debugPrint() calls with structured logging
class LoggerService {
  static const String _tag = 'MaxStream';

  /// Log debug message
  static void debug(String message) {
    debugLog('DEBUG', message);
  }

  /// Log info message
  static void info(String message) {
    debugLog('INFO', message);
  }

  /// Log warning message
  static void warning(String message) {
    debugLog('WARNING', message);
  }

  /// Log error message
  static void error(
    String message, [
    dynamic exception,
    StackTrace? stackTrace,
  ]) {
    debugLog('ERROR', message);
    if (exception != null) {
      debugLog('ERROR', 'Exception: $exception');
    }
    if (stackTrace != null) {
      debugLog('ERROR', 'StackTrace: $stackTrace');
    }
  }

  /// Internal debug log function
  static void debugLog(String level, String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final formatted = '[$timestamp] [$level] [$_tag] $message';
    // Use debugPrint for better visibility in debug console
    debugPrint(formatted);
  }
}
