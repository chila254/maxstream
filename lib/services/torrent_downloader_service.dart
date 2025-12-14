import 'package:flutter/foundation.dart';
import 'dart:io';

/// Service for downloading and streaming torrents via magnet links
/// Uses WebRTC or local torrent client for playback
class TorrentDownloaderService {
  static const String _tag = 'TorrentDownloaderService';

  /// Convert magnet link to streaming URL
  /// This is a placeholder - actual implementation depends on your streaming method
  ///
  /// Options:
  /// 1. Use webtorrent (browser-based P2P streaming)
  /// 2. Use aria2c or transmission for local downloads
  /// 3. Use a torrent-to-HTTP service (RealDebrid, Premiumize, etc.)
  static Future<String?> magnetToStreamUrl(
    String magnetLink, {
    String? fileIndex,
  }) async {
    try {
      debugPrint('$_tag: Converting magnet link to stream URL');
      debugPrint('$_tag: Magnet: ${magnetLink.substring(0, 50)}...');

      // Option 1: Use WebRTC-based streaming (requires browser)
      // This would stream directly without downloading
      if (magnetLink.startsWith('magnet:')) {
        return _createWebRTCStreamUrl(magnetLink, fileIndex);
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Magnet conversion error: $e');
      return null;
    }
  }

  /// Create WebRTC streaming URL using webtorrent protocol
  /// This allows streaming without full download
  static String _createWebRTCStreamUrl(
    String magnetLink,
    String? fileIndex,
  ) {
    // In a real implementation, you would:
    // 1. Use a WebRTC torrent library
    // 2. Extract the info hash from magnet link
    // 3. Set up peer connections
    // 4. Stream the file as HTTP while downloading

    try {
      final infoHashMatch =
          RegExp(r'magnet:\?xt=urn:btih:([a-zA-Z0-9]+)').firstMatch(magnetLink);
      if (infoHashMatch != null) {
        final infoHash = infoHashMatch.group(1)!.toLowerCase();
        debugPrint('$_tag: Extracted info hash: $infoHash');

        // Return a URL that would be handled by a WebRTC torrent plugin
        // In practice, you'd use something like:
        // - webtorrent-desktop
        // - stremio with torrentio addon
        // - A custom WebRTC implementation
        return 'magnet-stream://$infoHash?fileIndex=${fileIndex ?? '0'}';
      }
    } catch (e) {
      debugPrint('$_tag: WebRTC URL creation error: $e');
    }

    return magnetLink;
  }

  /// Check if aria2c (torrent downloader) is available locally
  static Future<bool> isAria2cAvailable() async {
    try {
      final result = await Process.run('aria2c', ['--version'],
          runInShell: Platform.isWindows);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('$_tag: aria2c not available: $e');
      return false;
    }
  }

  /// Check if transmission daemon is running
  static Future<bool> isTransmissionAvailable() async {
    try {
      final result = await Process.run('transmission-remote', ['--version'],
          runInShell: Platform.isWindows);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('$_tag: Transmission not available: $e');
      return false;
    }
  }

  /// Download torrent via aria2c and return local stream URL
  static Future<String?> downloadViaAria2c(
    String magnetLink, {
    String outputDir = '/tmp/maxstream-torrents',
  }) async {
    try {
      final isAvailable = await isAria2cAvailable();
      if (!isAvailable) {
        debugPrint('$_tag: aria2c is not installed');
        return null;
      }

      debugPrint('$_tag: Starting aria2c download');

      // Ensure output directory exists
      final dir = Directory(outputDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Download with aria2c
      final result = await Process.run(
        'aria2c',
        [
          '--dir=$outputDir',
          '--max-concurrent-downloads=5',
          '--split=5',
          '--min-split-size=1M',
          magnetLink,
        ],
        runInShell: Platform.isWindows,
      );

      if (result.exitCode == 0) {
        debugPrint('$_tag: Download completed successfully');
        // Return path to the largest downloaded file
        return _findLargestFile(outputDir);
      } else {
        debugPrint('$_tag: Download failed: ${result.stderr}');
        return null;
      }
    } catch (e) {
      debugPrint('$_tag: aria2c download error: $e');
      return null;
    }
  }

  /// Download torrent via transmission and return stream URL
  static Future<String?> downloadViaTransmission(
    String magnetLink, {
    String outputDir = '/tmp/maxstream-torrents',
  }) async {
    try {
      final isAvailable = await isTransmissionAvailable();
      if (!isAvailable) {
        debugPrint('$_tag: Transmission is not installed');
        return null;
      }

      debugPrint('$_tag: Adding torrent to transmission');

      // Add torrent to transmission
      final result = await Process.run(
        'transmission-remote',
        [
          '--add',
          magnetLink,
          '--download-dir=$outputDir',
        ],
        runInShell: Platform.isWindows,
      );

      if (result.exitCode == 0) {
        debugPrint('$_tag: Torrent added to transmission');
        // In a real implementation, you would:
        // 1. Poll transmission status
        // 2. Wait for download to start streaming
        // 3. Return the local file path or stream URL
        return 'transmission-stream://$magnetLink';
      } else {
        debugPrint('$_tag: Failed to add torrent: ${result.stderr}');
        return null;
      }
    } catch (e) {
      debugPrint('$_tag: Transmission download error: $e');
      return null;
    }
  }

  /// Find the largest file in directory (likely the video)
  static String? _findLargestFile(String dirPath) {
    try {
      final dir = Directory(dirPath);
      var largestFile = '';
      var largestSize = 0;

      for (final file in dir.listSync(recursive: true)) {
        if (file is File) {
          final size = file.lengthSync();
          if (size > largestSize) {
            largestSize = size;
            largestFile = file.path;
          }
        }
      }

      return largestFile.isNotEmpty ? largestFile : null;
    } catch (e) {
      debugPrint('$_tag: Error finding largest file: $e');
      return null;
    }
  }

  /// Cleanup torrent downloads
  static Future<void> cleanup(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
        debugPrint('$_tag: Cleanup completed');
      }
    } catch (e) {
      debugPrint('$_tag: Cleanup error: $e');
    }
  }
}
