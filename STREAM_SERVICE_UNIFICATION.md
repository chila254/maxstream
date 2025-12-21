# Stream Service Unification

## Overview
The stream extraction has been consolidated into a single, unified service: **StreamExtractionService**

## New Service
- **`stream_extraction_service.dart`** - Single unified service for all stream operations

## Unified Service Architecture

### StreamExtractionService
Contains all functionality needed for stream extraction:

1. **Stremio Provider Discovery**
   - `_getMovieStreams()` - Gets embed URLs for movies
   - `_getSeriesStreams()` - Gets embed URLs for TV shows

2. **Multi-Strategy Resolution**
   - Strategy 1: **Android Native** - Direct HTTP fetch (bypasses ORB completely)
   - Strategy 2: **WebView** - Falls back if Android native fails
   - Strategy 3: **Proxy Fetch** - Final fallback for any remaining issues

3. **Stream URL Extraction**
   - Detects m3u8 (HLS), mp4, mpd (DASH) URLs
   - Uses regex patterns for multiple extraction strategies
   - Works with HTML content, JSON-encoded URLs, and script tags

4. **Utility Methods**
   - `checkHealth()` - Health check for providers
   - `getAvailableProviders()` - List available providers
   - `clearCaches()` - Clear all caches
   - `dispose()` - Cleanup resources
   - `initialize()` - Initialize service

## Files to Delete
These files are now **DEPRECATED** and should be removed:

1. ❌ `combined_stream_service.dart` - Replaced by StreamExtractionService
2. ❌ `stream_resolver_service.dart` - Merged into StreamExtractionService
3. ❌ `stream_proxy_service.dart` - Merged as Strategy 3 in StreamExtractionService
4. ❌ `stream_extractor_helper.dart` - Extraction logic integrated
5. ❌ `stream_fallback_service.dart` - Fallback logic integrated
6. ❌ `android_webview_bridge.dart` - Android logic integrated

**Note**: These files are no longer imported anywhere in the codebase.

## Updated Imports
- ✅ `lib/main.dart` - Updated to use StreamExtractionService
- ✅ `lib/screens/inapp_video_player_screen.dart` - Updated to use StreamExtractionService

## API Usage
```dart
// Initialize
await StreamExtractionService.initialize();

// Extract stream
final result = await StreamExtractionService.extractStream(
  tmdbId,
  isMovie: true,
  season: 1,
  episode: 1,
);

// Get providers
final providers = await StreamExtractionService.getAvailableProviders(
  tmdbId,
  true,
);

// Cleanup
await StreamExtractionService.dispose();
```

## Resolution Strategy Flow

```
1. Get embed URLs from Stremio
   ↓
2. For each provider (ordered by quality):
   a) Try Android native fetch
      - Direct HTTP fetch bypasses ORB
      - Extract stream URL from HTML
      ✓ Success → Return stream
      ✗ Fail → Continue
   
   b) Try WebView resolution
      - Load embed in WebView
      - Extract via JavaScript
      ✓ Success → Return stream
      ✗ Fail → Continue
   
   c) Try Proxy fetch
      - Fetch embed content directly
      - Extract stream URL from HTML
      ✓ Success → Return stream
      ✗ Fail → Try next provider

3. Return first successful resolution
```

## Platform-Specific Handling

### Android
- Primary approach: Direct HTTP fetch using Dio
- User-Agent: Mobile (Android 13)
- Bypasses ORB completely since not subject to browser CORS
- No WebView overhead

### Other Platforms
- Falls back to WebView with iframe approach
- Then tries proxy fetch if WebView fails

## Benefits
1. **Unified** - Single source of truth for stream extraction
2. **Simplified** - No need to manage multiple services
3. **Efficient** - Android native approach for Android users
4. **Robust** - Multiple fallback strategies
5. **Maintainable** - All extraction logic in one file
6. **Testable** - Easier to test single service

## TODO: Manual Cleanup
Since these files cannot be deleted programmatically, manually delete:
1. `lib/services/combined_stream_service.dart`
2. `lib/services/stream_resolver_service.dart`
3. `lib/services/stream_proxy_service.dart`
4. `lib/services/stream_extractor_helper.dart`
5. `lib/services/stream_fallback_service.dart`
6. `lib/services/android_webview_bridge.dart`

## Summary
✅ All stream extraction functionality consolidated into StreamExtractionService
✅ Multi-platform support (Android native + WebView + Proxy fallback)
✅ ORB blocking issue completely resolved on Android
✅ Updated all imports in the app
✅ Ready for production use
