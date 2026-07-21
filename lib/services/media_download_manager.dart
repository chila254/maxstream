import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../database/db_helper.dart';
import 'direct_m3u8_service.dart';
import 'download_service_bridge.dart';
import 'media_download_service.dart';
import 'notification_service.dart';

class ActiveMediaDownload {
  const ActiveMediaDownload({
    required this.downloadKey,
    required this.title,
    required this.label,
    required this.thumbnail,
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    this.service,
  });

  final String downloadKey;
  final String title;
  final String label;
  final String thumbnail;
  final double progress;
  final int downloadedBytes;
  final int? totalBytes;
  final MediaDownloadService? service;

  ActiveMediaDownload copyWith({
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    MediaDownloadService? service,
  }) => ActiveMediaDownload(
    downloadKey: downloadKey,
    title: title,
    label: label,
    thumbnail: thumbnail,
    progress: progress ?? this.progress,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    service: service ?? this.service,
  );

  String get sizeLabel {
    final downloaded = _formatBytes(downloadedBytes);
    return totalBytes == null
        ? '$downloaded downloaded'
        : '$downloaded / ${_formatBytes(totalBytes!)}';
  }

  static String _formatBytes(int bytes) {
    const mb = 1024 * 1024;
    const gb = 1024 * mb;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
}

class MediaDownloadManager extends ChangeNotifier {
  MediaDownloadManager._();

  static final MediaDownloadManager instance = MediaDownloadManager._();

  final Map<String, ActiveMediaDownload> _active = {};
  int _completionVersion = 0;

  List<ActiveMediaDownload> get activeDownloads =>
      List.unmodifiable(_active.values);
  int get completionVersion => _completionVersion;

  ActiveMediaDownload? taskFor(String downloadKey) => _active[downloadKey];

  Future<bool> resolveAndStart({
    required String downloadKey,
    required String mediaId,
    required bool isMovie,
    required String title,
    required String thumbnail,
    String? resolverTitle,
    int seasonNumber = 1,
    int episodeNumber = 1,
  }) async {
    final lookupTitle = resolverTitle ?? title;
    final stream = isMovie
        ? await DirectM3u8Service.fetchMovieStreamUrl(
            lookupTitle,
            null,
            mediaId,
          )
        : await DirectM3u8Service.fetchSeriesStreamUrl(
            lookupTitle,
            seasonNumber,
            episodeNumber,
            mediaId,
          );
    final url = stream?['url']?.toString() ?? '';
    if (stream == null || url.isEmpty) return false;
    final headers = <String, String>{};
    if (stream['referer'] != null) {
      headers['Referer'] = stream['referer'].toString();
    }
    if (stream['headers'] is Map) {
      (stream['headers'] as Map).forEach((key, value) {
        headers[key.toString()] = value.toString();
      });
    }
    await start(
      downloadKey: downloadKey,
      url: url,
      headers: headers,
      isHls:
          stream['type'] == 'direct_m3u8' ||
          url.toLowerCase().contains('.m3u8'),
      mediaId: mediaId,
      isMovie: isMovie,
      title: title,
      thumbnail: thumbnail,
      seriesId: isMovie ? null : mediaId,
      seasonNumber: isMovie ? null : seasonNumber,
      episodeNumber: isMovie ? null : episodeNumber,
      subtitles: (stream['subtitles'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (track) =>
                track.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(),
    );
    return true;
  }

  Future<void> _ensureForegroundService() async {
    if (_active.isEmpty) {
      await WakelockPlus.enable();
      await DownloadServiceBridge.startForegroundService(
        downloadCount: 1,
        title: _active.values.first.title,
      );
    } else {
      // Update count.
      await DownloadServiceBridge.startForegroundService(
        downloadCount: _active.length + 1,
        title: _active.values.first.title,
      );
    }
  }

  Future<void> _updateOrStopForegroundService() async {
    if (_active.isEmpty) {
      await DownloadServiceBridge.stopForegroundService();
      await WakelockPlus.disable();
    } else {
      await DownloadServiceBridge.startForegroundService(
        downloadCount: _active.length,
        title: _active.values.first.title,
      );
    }
  }

  Future<void> start({
    required String downloadKey,
    required String url,
    required Map<String, String> headers,
    required bool isHls,
    required String mediaId,
    required bool isMovie,
    required String title,
    required String thumbnail,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    List<Map<String, dynamic>> subtitles = const [],
  }) async {
    if (_active.containsKey(downloadKey)) return;
    final label = title;
    final notificationId = downloadKey.hashCode & 0x7fffffff;
    var lastNotificationProgress = -1;
    final service = MediaDownloadService();
    _active[downloadKey] = ActiveMediaDownload(
      downloadKey: downloadKey,
      title: title,
      label: label,
      thumbnail: thumbnail,
      progress: 0,
      downloadedBytes: 0,
      totalBytes: null,
      service: service,
    );
    notifyListeners();

    // Start foreground service and wakelock when first download begins.
    await _ensureForegroundService();

    try {
      await NotificationService().showDownloadProgress(
        id: notificationId,
        title: isMovie ? 'Downloading movie' : 'Downloading episode',
        label: label,
        progress: 0,
      );
      final result = await service.download(
        url: url,
        headers: headers,
        downloadId: downloadKey,
        hls: isHls,
        onProgress: (progress) {
          _active[downloadKey] = _active[downloadKey]!.copyWith(
            progress: progress,
          );
          notifyListeners();
          final percent = (progress * 100).round().clamp(0, 100);
          if (percent != lastNotificationProgress) {
            lastNotificationProgress = percent;
            unawaited(
              NotificationService().showDownloadProgress(
                id: notificationId,
                title: isMovie ? 'Downloading movie' : 'Downloading episode',
                label: label,
                progress: percent,
                size: _active[downloadKey]!.sizeLabel,
              ),
            );
          }
        },
        onBytesProgress: (downloadedBytes, totalBytes) {
          _active[downloadKey] = _active[downloadKey]!.copyWith(
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
          );
          notifyListeners();
        },
      );
      final localSubtitles = await _downloadSubtitles(
        subtitles,
        File(result.localPath).parent,
        headers,
      );
      await DBHelper.insertMediaDownload(
        downloadKey: downloadKey,
        mediaId: mediaId,
        mediaType: isMovie ? 'movie' : 'episode',
        seriesId: seriesId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        title: title,
        thumbnail: thumbnail,
        localPath: result.localPath,
        subtitles: localSubtitles,
      );
      _completionVersion++;
      await NotificationService().showDownloadFinished(
        id: notificationId,
        label: label,
      );
    } catch (error) {
      await NotificationService().showDownloadFinished(
        id: notificationId,
        label: label,
        error: error.toString(),
      );
      rethrow;
    } finally {
      service.dispose();
      _active.remove(downloadKey);
      notifyListeners();
      await _updateOrStopForegroundService();
    }
  }

  Future<List<Map<String, dynamic>>> _downloadSubtitles(
    List<Map<String, dynamic>> tracks,
    Directory directory,
    Map<String, String> streamHeaders,
  ) async {
    final downloaded = <Map<String, dynamic>>[];
    for (var index = 0; index < tracks.length; index++) {
      final track = tracks[index];
      final rawUrl = track['url']?.toString() ?? '';
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) continue;
      try {
        final headers = <String, String>{
          if (track['source']?.toString() != 'Vidflix') ...streamHeaders,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/vtt, application/x-subrip, text/plain, */*',
        };
        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            response.bodyBytes.isEmpty) {
          continue;
        }
        var extension = p.extension(uri.path).toLowerCase();
        if (!{
          '.vtt',
          '.srt',
          '.ass',
          '.ssa',
          '.ttml',
          '.xml',
          '.json',
        }.contains(extension)) {
          extension = '.vtt';
        }
        final file = File(p.join(directory.path, 'subtitle_$index$extension'));
        await file.writeAsBytes(response.bodyBytes, flush: true);
        downloaded.add({
          'label': track['label']?.toString() ?? 'Subtitle ${index + 1}',
          'url': file.path,
          'default': track['default'] == true,
          'source': 'Downloaded',
        });
      } catch (_) {
        // A broken subtitle must not fail the video download.
      }
    }
    return downloaded;
  }
}
