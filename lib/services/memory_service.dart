import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _memoryChannel = MethodChannel('com.maxstream.app/memory');

bool _installed = false;

/// Listens for Android's `onTrimMemory` warning (forwarded by MainActivity)
/// and releases the decoded image cache - the Flutter-side memory we can give
/// back to the system so the Low Memory Killer doesn't kill the video player.
void installMemoryTrimHandler() {
  if (_installed) return;
  _installed = true;
  _memoryChannel.setMethodCallHandler((call) async {
    if (call.method != 'onTrimMemory') return null;
    final level = (call.arguments as num?)?.toInt() ?? 0;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint('MaxStream: memory trim level=$level - image cache cleared');
    return null;
  });
}
