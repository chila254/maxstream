import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _memoryChannel = MethodChannel('com.maxstream.app/memory');

bool _installed = false;

/// Callback type for memory pressure events.  Receives the Android
/// `onTrimMemory` level constant so callers can decide how aggressively to
/// release resources.
typedef MemoryPressureCallback = void Function(int level);

/// Registered callback invoked on every `onTrimMemory` event forwarded by
/// [MainActivity].
MemoryPressureCallback? _onPressure;

/// Installs the memory-trim listener and clears the decoded-image cache on
/// every Android `onTrimMemory` callback.  On Android 14 TV boxes (Vitron-
/// class, 1 GB RAM) the Low Memory Killer is the #1 cause of mid-playback
/// process death; clearing Flutter-side caches gives the system a few extra
/// seconds before it resorts to SIGKILL.
///
/// [onPressure] is an optional callback that receives the raw
/// `ComponentCallbacks2` level so higher layers (e.g. the TV video player)
/// can proactively release native ExoPlayer buffers when memory is critical.
void installMemoryTrimHandler({MemoryPressureCallback? onPressure}) {
  if (_installed) return;
  _installed = true;
  _onPressure = onPressure;
  _memoryChannel.setMethodCallHandler((call) async {
    if (call.method != 'onTrimMemory') return null;
    final level = (call.arguments as num?)?.toInt() ?? 0;
    // Always clear Flutter-side image caches – this is cheap and always safe.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint('MaxStream: onTrimMemory level=$level – image cache cleared');
    // Forward to the registered callback so the player screen can release
    // native resources (e.g. dispose ExoPlayer) when memory is critical.
    _onPressure?.call(level);
    return null;
  });
}

/// Whether the device is currently under **critical** memory pressure
/// (`TRIM_MEMORY_RUNNING_CRITICAL` = 15 or higher).  The TV player screen
/// can poll this before creating a second platform view or switching servers.
bool isMemoryCritical(int level) => level >= 15;

/// Allows a screen (e.g. the video player) to register or clear its memory
/// pressure callback **after** [installMemoryTrimHandler] has been called.
/// Only one screen is active at a time, so this simply replaces the previous
/// callback.
void setMemoryPressureCallback(MemoryPressureCallback? callback) {
  _onPressure = callback;
}
