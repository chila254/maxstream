# StreamExtractionService - Quick Reference

## Single Service for All Stream Operations

### Main Method
```dart
final result = await StreamExtractionService.extractStream(
  tmdbId,      // TMDB ID (e.g., "83533")
  isMovie,     // true for movies, false for TV series
  season: 1,   // Optional: TV season number
  episode: 1,  // Optional: TV episode number
);
```

### Return Value
```dart
{
  'streamUrl': 'https://stream.example.com/video.m3u8',
  'source': 'Vidsrc Icu',
  'type': 'hls',        // 'hls', 'dash', or 'mp4'
  'quality': '720p',
  'embedUrl': 'https://vidsrc.icu/embed/movie/83533',
  'method': 'unified_extraction',
  'headers': { /* HTTP headers */ },
  'isPlayable': true,
}
```

### Lifecycle
```dart
// Initialize (once at app startup)
await StreamExtractionService.initialize();

// Use (multiple times)
final result = await StreamExtractionService.extractStream(...);

// Cleanup (on app shutdown)
await StreamExtractionService.dispose();
```

### Other Useful Methods
```dart
// Get list of available providers
final providers = await StreamExtractionService.getAvailableProviders(
  tmdbId,
  isMovie: true,
);
// Returns: List<StreamProvider>
//   - url
//   - quality
//   - source

// Health check
final health = await StreamExtractionService.checkHealth();
// Returns: {'extraction_service': true/false, 'overall': true/false}

// Clear caches
await StreamExtractionService.clearCaches();
```

## How It Works

### Three Strategies (in order):
1. **Android Native** ← Preferred on Android (no ORB issues)
2. **WebView** ← Fallback for desktop/iOS
3. **Proxy Fetch** ← Last resort

### Stream URL Extraction
Automatically detects and extracts:
- HLS (m3u8) streams
- DASH (mpd) manifests  
- Direct MP4 links
- JSON-encoded URLs

## Platform Support
- ✅ Android (optimal - native fetch)
- ✅ iOS (WebView)
- ✅ Web (Proxy fetch)
- ✅ Windows/Linux (Proxy fetch)

## Error Handling
```dart
try {
  final result = await StreamExtractionService.extractStream(
    '83533',
    true,
  );
  
  if (result == null) {
    print('No stream found');
  } else {
    print('Stream: ${result["streamUrl"]}');
  }
} catch (e) {
  print('Error: $e');
}
```

## Real-World Example
```dart
// Load a movie
final result = await StreamExtractionService.extractStream(
  '278',  // The Shawshank Redemption
  true,   // is movie
);

if (result != null && result['isPlayable'] == true) {
  // Play the stream
  await player.play(
    result['streamUrl'],
    headers: result['headers'],
  );
}
```

## Debugging
Enable logging to see extraction details:
```
I/flutter: StreamExtractionService: ╔════════════════════════════════════════════╗
I/flutter: StreamExtractionService: ║       STREAM EXTRACTION STARTED             ║
I/flutter: StreamExtractionService: ╚════════════════════════════════════════════╝
I/flutter: StreamExtractionService: 📍 STEP 1: Discovering Stremio Providers
I/flutter: StreamExtractionService: ✓ STEP 1 SUCCESS: Found 2 providers
I/flutter: StreamExtractionService: 📍 STEP 2: Resolving Embed URLs
I/flutter: StreamExtractionService: Attempting to resolve Vidsrc Icu - 720p
I/flutter: StreamExtractionService: [Android] Fetching Vidsrc Icu...
I/flutter: StreamExtractionService: ✓ Successfully resolved via Android native
```

## No More Multiple Services!
- ❌ ~~CombinedStreamService~~ 
- ❌ ~~StreamResolverService~~
- ❌ ~~StreamProxyService~~
- ❌ ~~StreamExtractorHelper~~
- ❌ ~~StreamFallbackService~~
- ❌ ~~AndroidWebViewBridge~~

✅ **Just use StreamExtractionService**
