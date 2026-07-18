import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef DownloadProgress = void Function(double progress);

class MediaDownloadResult {
  const MediaDownloadResult({required this.localPath, required this.isHls});

  final String localPath;
  final bool isHls;
}

/// Downloads resolved, non-DRM media into the application's private storage.
/// Supports retry with resume for both direct and HLS downloads.
class MediaDownloadService {
  MediaDownloadService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  bool _cancelled = false;

  static const int _maxRetries = 10;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(seconds: 60);

  void cancel() => _cancelled = true;

  Future<MediaDownloadResult> download({
    required String url,
    Map<String, String> headers = const {},
    String? downloadId,
    bool? hls,
    DownloadProgress? onProgress,
  }) async {
    final root = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'media_downloads'),
    );
    await root.create(recursive: true);
    final id = _safeName(
      downloadId ?? DateTime.now().microsecondsSinceEpoch.toString(),
    );
    final partial = Directory(p.join(root.path, '.$id.partial'));
    final completed = Directory(p.join(root.path, id));

    // If a completed directory exists, return it immediately (resume after crash).
    if (await completed.exists()) {
      final existing = await _findExistingOutput(completed);
      if (existing != null) {
        onProgress?.call(1);
        return MediaDownloadResult(localPath: existing, isHls: hls ?? false);
      }
    }

    // Don't delete partial on start — we want to resume from it.
    if (!await partial.exists()) {
      await partial.create(recursive: true);
    }
    onProgress?.call(0);
    try {
      final uri = Uri.parse(url);
      final isHls =
          hls ??
          uri.path.toLowerCase().endsWith('.m3u8') ||
              uri.path.toLowerCase().endsWith('.m3u');
      late final String outputName;
      if (isHls) {
        outputName = await _downloadHls(uri, partial, headers, onProgress);
      } else {
        outputName = await _downloadDirect(uri, partial, headers, onProgress);
      }

      await _deleteIfPresent(completed);
      await partial.rename(completed.path);
      onProgress?.call(1);
      return MediaDownloadResult(
        localPath: p.join(completed.path, outputName),
        isHls: isHls,
      );
    } catch (_) {
      // Keep partial directory for resume — only delete if explicitly cancelled.
      if (_cancelled) {
        await _deleteIfPresent(partial);
      }
      rethrow;
    }
  }

  Future<String> _downloadDirect(
    Uri uri,
    Directory directory,
    Map<String, String> headers,
    DownloadProgress? onProgress,
  ) async {
    final extension = p.extension(uri.path);
    final name = 'video${extension.isEmpty ? '.mp4' : extension}';
    final file = File(p.join(directory.path, name));
    var received = 0;

    // Check if we have partial data to resume from.
    if (await file.exists()) {
      received = await file.length();
    }

    await _retryWithResume(
      description: 'direct download ${uri.path}',
      onProgress: onProgress,
      totalGetter: () async {
        final headResponse = await _client.head(uri, headers: headers);
        return headResponse.contentLength;
      },
      execute: (total) async {
        final requestHeaders = Map<String, String>.from(headers);
        if (received > 0) {
          requestHeaders['Range'] = 'bytes=$received-';
        }
        final request = http.Request('GET', uri)..headers.addAll(requestHeaders);
        final response = await _client.send(request);

        if (received > 0 && response.statusCode == 206) {
          // Resuming — open file in append mode.
        } else if (received > 0 && response.statusCode == 200) {
          // Server doesn't support range — restart from beginning.
          received = 0;
        } else {
          _checkResponse(response.statusCode, uri);
        }

        final sink = file.openWrite(mode: received > 0 ? FileMode.append : FileMode.write);
        try {
          await for (final bytes in response.stream) {
            if (_cancelled) break;
            sink.add(bytes);
            received += bytes.length;
            if (total != null && total > 0) {
              onProgress?.call((received / total).clamp(0, 1));
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
      },
      cleanup: () async {
        if (_cancelled) await _deleteIfPresent(File(p.join(directory.path, name)).parent);
      },
    );
    return name;
  }

  Future<String> _downloadHls(
    Uri initialUri,
    Directory directory,
    Map<String, String> headers,
    DownloadProgress? onProgress,
  ) async {
    var playlistUri = initialUri;
    var playlist = await _getText(playlistUri, headers);
    _validateEncryption(playlist);
    for (var depth = 0; _isMaster(playlist) && depth < 5; depth++) {
      playlistUri = playlistUri.resolve(_highestVariant(playlist));
      playlist = await _getText(playlistUri, headers);
      _validateEncryption(playlist);
    }
    if (_isMaster(playlist)) {
      throw const FormatException('Too many nested HLS master playlists');
    }

    final lines = const LineSplitter().convert(playlist);
    final resources = <Uri, String>{};
    var resourceIndex = 0;
    String localName(Uri uri) {
      return resources.putIfAbsent(uri, () {
        final extension = p.extension(uri.path);
        return 'resource_${resourceIndex++}${extension.isEmpty ? '.bin' : extension}';
      });
    }

    final rewritten = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#EXT-X-KEY:')) {
        final method = _attribute(trimmed, 'METHOD')?.toUpperCase();
        if (method != null && method != 'NONE' && method != 'AES-128') {
          throw UnsupportedError('Unsupported encrypted HLS method: $method');
        }
        if (trimmed.toUpperCase().contains('KEYFORMAT=') &&
            !trimmed.toUpperCase().contains('KEYFORMAT="IDENTITY"')) {
          throw UnsupportedError('DRM HLS key formats are not supported');
        }
        rewritten.add(_rewriteAttributeUri(trimmed, playlistUri, localName));
      } else if (trimmed.startsWith('#EXT-X-MAP:')) {
        rewritten.add(_rewriteAttributeUri(trimmed, playlistUri, localName));
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        final uri = playlistUri.resolve(trimmed);
        rewritten.add(localName(uri));
      } else {
        rewritten.add(line);
      }
    }

    var done = 0;
    for (final entry in resources.entries) {
      if (_cancelled) break;
      final file = File(p.join(directory.path, entry.value));

      // Skip already-downloaded segments.
      if (await file.exists() && await file.length() > 0) {
        done++;
        onProgress?.call(done / (resources.length + 1));
        continue;
      }

      await _retryWithResume(
        description: 'HLS segment ${entry.value}',
        onProgress: null,
        execute: (_) async {
          await _downloadResource(
            entry.key,
            file,
            headers,
          );
        },
      );
      done++;
      onProgress?.call(done / (resources.length + 1));
    }

    const playlistName = 'playlist.m3u8';
    await File(
      p.join(directory.path, playlistName),
    ).writeAsString('${rewritten.join('\n')}\n', flush: true);
    return playlistName;
  }

  Future<void> _downloadResource(
    Uri uri,
    File file,
    Map<String, String> headers,
  ) async {
    final request = http.Request('GET', uri)..headers.addAll(headers);
    final response = await _client.send(request);
    _checkResponse(response.statusCode, uri);
    final sink = file.openWrite();
    try {
      await response.stream.pipe(sink);
    } finally {
      await sink.close();
    }
  }

  /// Retries an operation with exponential backoff.
  Future<void> _retryWithResume({
    required String description,
    required Future<void> Function(int? total) execute,
    DownloadProgress? onProgress,
    Future<int?> Function()? totalGetter,
    Future<void> Function()? cleanup,
  }) async {
    var delay = _initialRetryDelay;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      if (_cancelled) {
        await cleanup?.call();
        throw StateError('Download cancelled');
      }
      try {
        final total = totalGetter != null ? await totalGetter() : null;
        await execute(total);
        return;
      } catch (e) {
        final isRetryable = e is SocketException ||
            e is HttpException ||
            e is TimeoutException ||
            e is ClientException ||
            e.toString().contains('Software caused connection abort') ||
            e.toString().contains('Connection reset') ||
            e.toString().contains('Connection refused') ||
            e.toString().contains('Connection closed');

        if (!isRetryable || attempt == _maxRetries - 1) {
          await cleanup?.call();
          rethrow;
        }

        // Exponential backoff with jitter.
        final jitter = Duration(milliseconds: (delay.inMilliseconds * 0.5 * (DateTime.now().millisecond % 100) / 100).round());
        final waitTime = delay + jitter;
        await Future.delayed(waitTime);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(0, _maxRetryDelay.inMilliseconds),
        );
      }
    }
    throw StateError('Download failed after $_maxRetries retries: $description');
  }

  Future<String?> _findExistingOutput(Directory dir) async {
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name == 'playlist.m3u8' || name.startsWith('video')) {
            return entity.path;
          }
        }
      }
    }
    return null;
  }

  Future<String> _getText(Uri uri, Map<String, String> headers) async {
    final response = await _client.get(uri, headers: headers);
    _checkResponse(response.statusCode, uri);
    return utf8.decode(response.bodyBytes);
  }

  bool _isMaster(String playlist) => playlist.contains('#EXT-X-STREAM-INF:');

  void _validateEncryption(String playlist) {
    for (final line in const LineSplitter().convert(playlist)) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('#EXT-X-KEY:') &&
          !trimmed.startsWith('#EXT-X-SESSION-KEY:')) {
        continue;
      }
      final method = _attribute(trimmed, 'METHOD')?.toUpperCase();
      if (method != null && method != 'NONE' && method != 'AES-128') {
        throw UnsupportedError('Unsupported encrypted HLS method: $method');
      }
      final keyFormat = _attribute(trimmed, 'KEYFORMAT');
      if (keyFormat != null && keyFormat.toUpperCase() != 'IDENTITY') {
        throw UnsupportedError('DRM HLS key formats are not supported');
      }
    }
  }

  String _highestVariant(String playlist) {
    final lines = const LineSplitter().convert(playlist);
    String? best;
    var bestPixels = -1;
    var bestBandwidth = -1;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      var next = index + 1;
      while (next < lines.length &&
          (lines[next].trim().isEmpty || lines[next].trim().startsWith('#'))) {
        next++;
      }
      if (next >= lines.length) continue;
      final resolution = _attribute(line, 'RESOLUTION')?.split('x');
      final pixels = resolution != null && resolution.length == 2
          ? (int.tryParse(resolution[0]) ?? 0) *
                (int.tryParse(resolution[1]) ?? 0)
          : 0;
      final bandwidth = int.tryParse(_attribute(line, 'BANDWIDTH') ?? '') ?? 0;
      if (pixels > bestPixels ||
          (pixels == bestPixels && bandwidth > bestBandwidth)) {
        best = lines[next].trim();
        bestPixels = pixels;
        bestBandwidth = bandwidth;
      }
    }
    if (best == null) throw const FormatException('HLS master has no variants');
    return best;
  }

  String _rewriteAttributeUri(
    String line,
    Uri base,
    String Function(Uri) localName,
  ) {
    final match = RegExp(
      r'URI=("([^"]+)"|([^,]+))',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return line;
    final source = match.group(2) ?? match.group(3)!;
    final replacement = 'URI="${localName(base.resolve(source))}"';
    return line.replaceRange(match.start, match.end, replacement);
  }

  String? _attribute(String line, String name) {
    final match = RegExp(
      '(?:^|,)$name=("([^"]*)"|[^,]*)',
      caseSensitive: false,
    ).firstMatch(line.substring(line.indexOf(':') + 1));
    final value = match?.group(1);
    return value?.startsWith('"') == true ? match?.group(2) : value;
  }

  void _checkResponse(int statusCode, Uri uri) {
    if (statusCode < 200 || statusCode >= 300) {
      throw HttpException('HTTP $statusCode while downloading $uri', uri: uri);
    }
  }

  String _safeName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'download' : safe;
  }

  Future<void> _deleteIfPresent(FileSystemEntity entity) async {
    if (await entity.exists()) await entity.delete(recursive: true);
  }

  void dispose() {
    _cancelled = true;
    if (_ownsClient) _client.close();
  }
}
