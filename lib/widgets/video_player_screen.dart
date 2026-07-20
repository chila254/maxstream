// This file conditionally exports the platform-specific implementation.
// On web: exports the web player. On mobile: exports the native player.
export 'video_player_screen_native.dart'
    if (dart.library.js_interop) 'video_player_screen_web.dart';
