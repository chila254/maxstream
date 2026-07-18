import 'package:flutter/services.dart';

class DownloadServiceBridge {
  static const _channel = MethodChannel('com.maxstream.app/download_service');

  static Future<void> startForegroundService({
    int downloadCount = 1,
    String title = 'Downloading media',
  }) async {
    await _channel.invokeMethod('startForegroundService', {
      'downloadCount': downloadCount,
      'title': title,
    });
  }

  static Future<void> stopForegroundService() async {
    await _channel.invokeMethod('stopForegroundService');
  }
}
