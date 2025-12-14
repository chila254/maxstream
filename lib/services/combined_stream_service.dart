import 'package:flutter/foundation.dart';
import 'torrent_stream_service.dart';
import 'webrtc_torrent_service.dart';

/// Stream extraction service using WebRTC P2P torrent technology
/// Uses distributed hash table (DHT) for peer discovery and magnet link extraction
class CombinedStreamService {
  static const String _tag = 'CombinedStreamService';

  /// Extract stream URL using WebRTC P2P torrent technology
  ///
  /// [tmdbId] - The TMDB ID of the content
  /// [isMovie] - Whether this is a movie (true) or TV show (false)
  /// [season] - TV show season number (ignored for movies)
  /// [episode] - TV show episode number (ignored for movies)
  ///
  /// Returns a map with magnet link and metadata
  static Future<Map<String, dynamic>?> extractStream(
    String tmdbId,
    bool isMovie, {
    int season = 1,
    int episode = 1,
  }) async {
    debugPrint(
      '$_tag: Starting WebRTC P2P stream extraction for ${isMovie ? 'movie' : 'tv'} $tmdbId',
    );

    // Use torrent/magnet extraction via WebRTC
    final torrentResult = await _extractTorrentMagnet(
      tmdbId,
      isMovie,
      season: season,
      episode: episode,
    );

    if (torrentResult != null) {
      debugPrint(
        '$_tag: ✓ WebRTC torrent extraction succeeded - Found ${torrentResult['magnetCount']} sources',
      );
      return torrentResult;
    }

    debugPrint(
      '$_tag: ✗ WebRTC torrent extraction failed',
    );
    return null;
  }

  /// Extract magnet links for WebRTC P2P streaming
  static Future<Map<String, dynamic>?> _extractTorrentMagnet(
    String tmdbId,
    bool isMovie, {
    required int season,
    required int episode,
  }) async {
    try {
      final result = await TorrentStreamService.extractTorrentStreams(
        tmdbId,
        isMovie: isMovie,
        season: season,
        episode: episode,
      );

      if (result.success && result.magnets != null && result.magnets!.isNotEmpty) {
        debugPrint(
          '$_tag: Torrent extraction success with ${result.magnets!.length} sources',
        );

        // Return best quality magnet with WebRTC metadata
        final bestMagnet = result.magnets!.first;
        return {
          'streamUrl': bestMagnet.url,
          'source': result.source,
          'type': 'magnet',
          'method': 'webrtc_p2p',
          'title': bestMagnet.title,
          'quality': bestMagnet.quality,
          'seeders': bestMagnet.seeders,
          'magnetCount': result.magnets!.length,
          'message':
              'WebRTC P2P Stream: ${bestMagnet.title} (${bestMagnet.seeders} peers)',
          'magnets': result.magnets!
              .map((m) => {
                    'url': m.url,
                    'title': m.title,
                    'quality': m.quality,
                    'seeders': m.seeders,
                  })
              .toList(),
        };
      }

      debugPrint('$_tag: Torrent extraction failed: ${result.error}');
      return null;
    } catch (e) {
      debugPrint('$_tag: Torrent extraction error: $e');
      return null;
    }
  }

  /// Health check - verify torrent sources are available
  static Future<Map<String, bool>> checkHealth() async {
    try {
      // Check if torrent service can discover peers
      final testResult =
          await TorrentStreamService.extractTorrentStreams('550', isMovie: true);

      return {
        'webrtc_p2p': testResult.success,
        'overall': testResult.success,
      };
    } catch (e) {
      debugPrint('$_tag: Health check error: $e');
      return {'webrtc_p2p': false, 'overall': false};
    }
  }

  /// Test a magnet link source
  static Future<bool> testMagnetSource(String magnetLink) async {
    try {
      if (!magnetLink.startsWith('magnet:')) {
        return false;
      }

      // Test by trying to start a session
      final session = await WebRTCTorrentService.streamMagnet(magnetLink);
      if (session != null) {
        await WebRTCTorrentService.stopStream(session.infoHash);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('$_tag: Test magnet source error: $e');
      return false;
    }
  }

  /// Clear caches
  static Future<void> clearCaches() async {
    try {
      TorrentStreamService.dispose();
      await WebRTCTorrentService.disposeAll();
      debugPrint('$_tag: All caches cleared');
    } catch (e) {
      debugPrint('$_tag: Cache clear error: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      TorrentStreamService.dispose();
      await WebRTCTorrentService.disposeAll();
      debugPrint('$_tag: All services disposed');
    } catch (e) {
      debugPrint('$_tag: Dispose error: $e');
    }
  }
}
