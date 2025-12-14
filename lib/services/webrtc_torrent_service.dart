import 'package:flutter/foundation.dart';
import 'dart:async';

/// WebRTC-based P2P torrent streaming service
/// Streams video content from magnet links without requiring full download
/// Uses DHT (Distributed Hash Table) and peer discovery
class WebRTCTorrentService {
  static const String _tag = 'WebRTCTorrentService';

  // Torrent metadata cache
  static final Map<String, TorrentMetadata> _metadataCache = {};
  
  // Active streaming sessions
  static final Map<String, TorrentStreamSession> _sessions = {};

  /// Start streaming a torrent via magnet link
  /// Returns a stream URL that can be played directly
  static Future<TorrentStreamSession?> streamMagnet(
    String magnetLink, {
    int? fileIndex,
    Function(StreamProgress)? onProgress,
  }) async {
    try {
      debugPrint('$_tag: Starting WebRTC stream for magnet');
      debugPrint('$_tag: Magnet: ${magnetLink.substring(0, 50)}...');

      // Extract info hash and metadata
      final infoHash = _extractInfoHash(magnetLink);
      if (infoHash == null) {
        throw Exception('Invalid magnet link');
      }

      debugPrint('$_tag: Info hash: $infoHash');

      // Check cache first
      TorrentMetadata? metadata = _metadataCache[infoHash];

      // If not cached, fetch metadata from DHT
      if (metadata == null) {
        metadata = await _fetchMetadata(infoHash, magnetLink);
        if (metadata == null) {
          throw Exception('Could not fetch torrent metadata');
        }
        _metadataCache[infoHash] = metadata;
      }

      debugPrint(
        '$_tag: Found torrent: ${metadata.name} (${metadata.files.length} files)',
      );

      // Select file to stream
      final targetFileIndex = fileIndex ?? _selectLargestFile(metadata);
      final targetFile = metadata.files[targetFileIndex];

      debugPrint(
        '$_tag: Streaming: ${targetFile.name} (${_formatBytes(targetFile.length)})',
      );

      // Create streaming session
      final session = TorrentStreamSession(
        magnetLink: magnetLink,
        infoHash: infoHash,
        metadata: metadata,
        fileIndex: targetFileIndex,
        onProgress: onProgress,
      );

      // Initialize peer discovery and streaming
      await session.initialize();

      // Cache session
      _sessions[infoHash] = session;

      debugPrint('$_tag: Stream session created successfully');
      return session;
    } catch (e) {
      debugPrint('$_tag: Stream initialization error: $e');
      return null;
    }
  }

  /// Stop streaming and cleanup
  static Future<void> stopStream(String infoHash) async {
    final session = _sessions.remove(infoHash);
    if (session != null) {
      await session.stop();
      debugPrint('$_tag: Stream stopped and cleaned up');
    }
  }

  /// Extract info hash from magnet link
  static String? _extractInfoHash(String magnetLink) {
    try {
      final match = RegExp(r'magnet:\?xt=urn:btih:([a-zA-Z0-9]+)')
          .firstMatch(magnetLink);
      return match?.group(1)?.toLowerCase();
    } catch (e) {
      debugPrint('$_tag: Failed to extract info hash: $e');
      return null;
    }
  }

  /// Fetch torrent metadata from DHT/peers
  static Future<TorrentMetadata?> _fetchMetadata(
    String infoHash,
    String magnetLink,
  ) async {
    try {
      debugPrint('$_tag: Fetching metadata for $infoHash');

      // In a real implementation, this would:
      // 1. Connect to DHT (Distributed Hash Table)
      // 2. Find peers via tracker in magnet link
      // 3. Download .torrent metadata from peers
      // 4. Parse and return file structure

      // For now, simulate metadata fetch
      await Future.delayed(const Duration(seconds: 2));

      // Parse magnet link for basic info
      final nameMatch =
          RegExp(r'&dn=([^&]+)').firstMatch(magnetLink);
      final rawName = nameMatch?.group(1);
      final name = rawName != null
          ? rawName.replaceAll('+', ' ').replaceAll('%20', ' ')
          : null;

      return TorrentMetadata(
        infoHash: infoHash,
        name: name ?? 'Unknown Torrent',
        totalSize: 0, // Would be fetched from actual torrent
        files: [
          TorrentFile(
            name: name ?? 'video.mp4',
            length: 0,
            path: ['${name ?? 'video.mp4'}'],
          ),
        ],
      );
    } catch (e) {
      debugPrint('$_tag: Metadata fetch error: $e');
      return null;
    }
  }

  /// Select largest file (usually the video)
  static int _selectLargestFile(TorrentMetadata metadata) {
    var largestIndex = 0;
    var largestSize = 0;

    for (var i = 0; i < metadata.files.length; i++) {
      if (metadata.files[i].length > largestSize) {
        largestSize = metadata.files[i].length;
        largestIndex = i;
      }
    }

    return largestIndex;
  }

  /// Format bytes to human readable
  static String _formatBytes(int bytes) {
    const suffix = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var index = 0;

    while (size >= 1024 && index < suffix.length - 1) {
      size /= 1024;
      index++;
    }

    return '${size.toStringAsFixed(2)} ${suffix[index]}';
  }

  /// Get stream URL for a session
  static String getStreamUrl(String infoHash) {
    return 'webrtc-stream://$infoHash';
  }

  /// Get session stats
  static StreamProgress? getSessionProgress(String infoHash) {
    return _sessions[infoHash]?.progress;
  }

  /// Cleanup all sessions
  static Future<void> disposeAll() async {
    final sessions = List.from(_sessions.values);
    for (final session in sessions) {
      await session.stop();
    }
    _sessions.clear();
    _metadataCache.clear();
    debugPrint('$_tag: All sessions disposed');
  }
}

/// Streaming session for a single torrent
class TorrentStreamSession {
  static const String _tag = 'TorrentStreamSession';

  final String magnetLink;
  final String infoHash;
  final TorrentMetadata metadata;
  final int fileIndex;
  final Function(StreamProgress)? onProgress;

  late StreamProgress progress;
  late Timer _progressTimer;
  bool _initialized = false;

  List<TorrentPeer> peers = [];
  int _downloadedBytes = 0;
  int _uploadedBytes = 0;

  TorrentStreamSession({
    required this.magnetLink,
    required this.infoHash,
    required this.metadata,
    required this.fileIndex,
    this.onProgress,
  });

  /// Initialize stream session
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('$_tag: Initializing stream session');

      // Initialize progress tracking
      progress = StreamProgress(
        magnetLink: magnetLink,
        infoHash: infoHash,
        fileName: metadata.files[fileIndex].name,
        fileSize: metadata.files[fileIndex].length,
        downloadedBytes: 0,
        uploadedBytes: 0,
        peers: 0,
        downloadSpeed: 0,
        uploadSpeed: 0,
        bufferHealth: 0.0,
      );

      // Start DHT peer discovery
      await _discoverPeers();

      // Start peer connections
      await _connectToPeers();

      // Start streaming chunks
      _startStreaming();

      // Start progress monitoring
      _startProgressTracking();

      _initialized = true;
      debugPrint('$_tag: Stream session initialized');
    } catch (e) {
      debugPrint('$_tag: Initialization error: $e');
      rethrow;
    }
  }

  /// Discover peers via DHT
  Future<void> _discoverPeers() async {
    try {
      debugPrint('$_tag: Discovering peers via DHT');

      // In real implementation:
      // 1. Connect to DHT nodes
      // 2. Query for info_hash
      // 3. Get peer list (IP:port)
      // 4. Add to peers list

      // Simulate peer discovery
      await Future.delayed(const Duration(seconds: 1));

      // Example peers (would be discovered from DHT)
      peers = [
        TorrentPeer(
          ip: '192.168.1.100',
          port: 6881,
          peerId: 'peer1',
          hasBlocks: [],
        ),
        TorrentPeer(
          ip: '192.168.1.101',
          port: 6881,
          peerId: 'peer2',
          hasBlocks: [],
        ),
        TorrentPeer(
          ip: '192.168.1.102',
          port: 6881,
          peerId: 'peer3',
          hasBlocks: [],
        ),
      ];

      debugPrint('$_tag: Found ${peers.length} peers');
    } catch (e) {
      debugPrint('$_tag: Peer discovery error: $e');
    }
  }

  /// Connect to peers and establish BitTorrent protocol
  Future<void> _connectToPeers() async {
    try {
      debugPrint('$_tag: Connecting to peers');

      // In real implementation:
      // 1. Establish TCP connections to peers
      // 2. Exchange BitTorrent handshake
      // 3. Request piece hashes
      // 4. Build have-map for each peer

      // Simulate connections
      for (var peer in peers) {
        // Mark some blocks as available
        final blockCount = (metadata.files[fileIndex].length / 16384).ceil();
        peer.hasBlocks = List.generate(
          blockCount,
          (i) => i % 3 == 0, // Every 3rd block available
        );
      }

      debugPrint('$_tag: Connected to ${peers.length} peers');
    } catch (e) {
      debugPrint('$_tag: Peer connection error: $e');
    }
  }

  /// Start streaming video blocks
  void _startStreaming() {
    try {
      debugPrint('$_tag: Starting chunk streaming');

      // In real implementation:
      // 1. Request blocks from peers with rarest-first strategy
      // 2. Download blocks in sequence for playback
      // 3. Cache next segment ahead of playhead
      // 4. Handle peer churn (disconnects/reconnects)

      // Simulate downloads
      _downloadedBytes = 0;
    } catch (e) {
      debugPrint('$_tag: Streaming error: $e');
    }
  }

  /// Track and report progress
  void _startProgressTracking() {
    var lastDownloaded = 0;
    var lastUploaded = 0;
    var lastTime = DateTime.now();

    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) {
        final now = DateTime.now();
        final elapsed = now.difference(lastTime).inMilliseconds / 1000;

        // Simulate download progress
        _downloadedBytes += (300 * elapsed).toInt(); // 300KB/s simulation
        if (_downloadedBytes > metadata.files[fileIndex].length) {
          _downloadedBytes = metadata.files[fileIndex].length.toInt();
        }

        final downloadSpeed = (_downloadedBytes - lastDownloaded) / elapsed;
        final uploadSpeed = (_uploadedBytes - lastUploaded) / elapsed;
        final bufferHealth =
            (_downloadedBytes / metadata.files[fileIndex].length).clamp(0.0, 1.0);

        progress = StreamProgress(
          magnetLink: magnetLink,
          infoHash: infoHash,
          fileName: metadata.files[fileIndex].name,
          fileSize: metadata.files[fileIndex].length,
          downloadedBytes: _downloadedBytes,
          uploadedBytes: _uploadedBytes,
          peers: peers.length,
          downloadSpeed: downloadSpeed.toInt(),
          uploadSpeed: uploadSpeed.toInt(),
          bufferHealth: bufferHealth,
        );

        onProgress?.call(progress);

        lastDownloaded = _downloadedBytes;
        lastUploaded = _uploadedBytes;
        lastTime = now;
      },
    );
  }

  /// Stop streaming
  Future<void> stop() async {
    _progressTimer.cancel();
    _initialized = false;
    debugPrint('$_tag: Stream session stopped');
  }
}

/// Torrent metadata
class TorrentMetadata {
  final String infoHash;
  final String name;
  final int totalSize;
  final List<TorrentFile> files;

  const TorrentMetadata({
    required this.infoHash,
    required this.name,
    required this.totalSize,
    required this.files,
  });
}

/// Individual torrent file
class TorrentFile {
  final String name;
  final int length;
  final List<String> path;

  const TorrentFile({
    required this.name,
    required this.length,
    required this.path,
  });
}

/// Peer in torrent swarm
class TorrentPeer {
  final String ip;
  final int port;
  final String peerId;
  List<bool> hasBlocks;

  TorrentPeer({
    required this.ip,
    required this.port,
    required this.peerId,
    required this.hasBlocks,
  });
}

/// Stream progress/stats
class StreamProgress {
  final String magnetLink;
  final String infoHash;
  final String fileName;
  final int fileSize;
  final int downloadedBytes;
  final int uploadedBytes;
  final int peers;
  final int downloadSpeed; // bytes per second
  final int uploadSpeed; // bytes per second
  final double bufferHealth; // 0.0 to 1.0

  const StreamProgress({
    required this.magnetLink,
    required this.infoHash,
    required this.fileName,
    required this.fileSize,
    required this.downloadedBytes,
    required this.uploadedBytes,
    required this.peers,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.bufferHealth,
  });

  /// Download progress percentage
  double get downloadPercent => downloadedBytes / fileSize;

  /// Download ETA in seconds
  int get eta {
    if (downloadSpeed == 0) return 0;
    final remaining = fileSize - downloadedBytes;
    return (remaining / downloadSpeed).toInt();
  }

  /// Formatted download speed
  String get downloadSpeedStr => _formatBytes(downloadSpeed) + '/s';

  /// Formatted upload speed
  String get uploadSpeedStr => _formatBytes(uploadSpeed) + '/s';

  /// Formatted ETA
  String get etaStr {
    final seconds = eta;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).toStringAsFixed(1)}m';
    return '${(seconds / 3600).toStringAsFixed(1)}h';
  }

  static String _formatBytes(int bytes) {
    const suffix = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var index = 0;

    while (size >= 1024 && index < suffix.length - 1) {
      size /= 1024;
      index++;
    }

    return size.toStringAsFixed(2) + suffix[index];
  }

  @override
  String toString() =>
      'StreamProgress(file: $fileName, downloaded: ${downloadPercent.toStringAsFixed(2)}%, peers: $peers, speed: $downloadSpeedStr)';
}
