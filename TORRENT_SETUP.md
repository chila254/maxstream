# Torrent/Magnet Support Setup

This guide explains how to set up torrent and magnet link streaming support in MaxStream.

## Overview

The app now supports two streaming methods with fallback:
1. **Scrapper API** (primary) - Direct m3u8/streaming links
2. **Torrent/Magnet** (fallback) - P2P streaming from torrents

## Architecture

### TorrentStreamService
- Extracts magnet links using Stremio Torrentio addon
- Returns sorted list of magnets by quality and seeders
- Uses public torrent metadata (no downloading needed)

### TorrentDownloaderService  
- Converts magnet links to stream URLs
- Supports multiple backends:
  - WebRTC (browser-based, no server needed)
  - aria2c (local download + stream)
  - transmission (daemon-based downloading)

### CombinedStreamService
- Orchestrates both methods
- Falls back to torrents if API fails

## Setup Options

### Option 1: WebRTC Streaming (Recommended for legal content)
No additional setup needed. Uses browser-based P2P streaming.

```dart
// Automatic - handled by TorrentDownloaderService
final streamUrl = await TorrentDownloaderService.magnetToStreamUrl(magnetLink);
```

### Option 2: aria2c (Linux/Mac/Windows)

Install aria2c:
```bash
# Ubuntu/Debian
sudo apt-get install aria2

# macOS
brew install aria2

# Windows
choco install aria2
```

Use in code:
```dart
final streamUrl = await TorrentDownloaderService.downloadViaAria2c(
  magnetLink,
  outputDir: '/home/user/torrents',
);
```

### Option 3: Transmission (Linux/Mac/Windows)

Install transmission-daemon:
```bash
# Ubuntu/Debian
sudo apt-get install transmission-daemon transmission-cli

# macOS
brew install transmission-cli

# Windows
choco install transmission
```

Start daemon:
```bash
transmission-daemon -f
```

Use in code:
```dart
final streamUrl = await TorrentDownloaderService.downloadViaTransmission(
  magnetLink,
  outputDir: '/home/user/torrents',
);
```

## Legal Considerations

This implementation is designed for:
- ✅ Public domain content
- ✅ Creative Commons licensed content
- ✅ Open source projects
- ✅ Content you own the rights to
- ❌ Copyrighted material without authorization

**Important**: Users are responsible for ensuring their use complies with local laws.

## Magnet Link Format

Magnet links from Torrentio addon look like:
```
magnet:?xt=urn:btih:ABC123&tr=http://tracker.example.com&dn=Movie%20Name
```

## Quality Sorting

Magnets are automatically sorted by:
1. Video quality (1080p > 720p > 480p)
2. Number of seeders (more seeds = faster)

## Limitations

1. **Streaming requires peers** - Can't stream without active seeders
2. **WebRTC has bandwidth limits** - Not suitable for very large files
3. **No subtitle support** - Torrents don't include subtitles metadata
4. **Network dependent** - P2P requires good upload/download speeds

## Error Handling

The app gracefully falls back:
```
Scrapper API → (fails) → Torrent/Magnet → (fails) → Error message
```

## Testing

Test torrent extraction:
```dart
final result = await TorrentStreamService.extractTorrentStreams(
  '550', // Fight Club
  isMovie: true,
);
print('Found ${result.magnets?.length} sources');
```

Test torrent download:
```dart
final isAvailable = await TorrentDownloaderService.isAria2cAvailable();
print('aria2c available: $isAvailable');
```

## Performance Tips

1. Use WebRTC for small files (< 1GB)
2. Use aria2c for larger downloads
3. Filter by seeders (higher = faster)
4. Limit concurrent downloads

## Troubleshooting

### No magnet links found
- Check internet connection
- Verify TMDB ID is correct
- Try different content

### Magnet link won't play
- WebRTC needs peer connections - ensure torrent has seeders
- Check firewall settings
- Try aria2c download instead

### High resource usage
- Reduce concurrent connections
- Disable P2P features if not needed
- Use smaller video files

## References

- [Stremio Torrentio Addon](https://github.com/TheBeastLT/torrentio-stremio)
- [WebTorrent](https://webtorrent.io/)
- [aria2](https://aria2.github.io/)
- [Transmission](https://transmissionbt.com/)
