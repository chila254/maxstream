import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/db_helper.dart';
import 'direct_m3u8_service.dart';
import 'media_download_service.dart';
import 'notification_service.dart';

class ActiveMediaDownload {
  const ActiveMediaDownload({
    required this.downloadKey,
    required this.title,
    required this.label,
    required this.thumbnail,
    required this.progress,
  });

  final String downloadKey;
  final String title;
  final String label;
  final String thumbnail;
  final double progress;

  ActiveMediaDownload copyWith({double? progress}) => ActiveMediaDownload(
    downloadKey: downloadKey,
    title: title,
    label: label,
    thumbnail: thumbnail,
    progress: progress ?? this.progress,
  );
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
    );
    return true;
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
  }) async {
    if (_active.containsKey(downloadKey)) return;
    final label = title;
    final notificationId = downloadKey.hashCode & 0x7fffffff;
    var lastNotificationProgress = -1;
    _active[downloadKey] = ActiveMediaDownload(
      downloadKey: downloadKey,
      title: title,
      label: label,
      thumbnail: thumbnail,
      progress: 0,
    );
    notifyListeners();
    final service = MediaDownloadService();
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
              ),
            );
          }
        },
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
    }
  }
}
