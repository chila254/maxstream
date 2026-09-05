import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync_service.dart';
import 'user_scope.dart';

class WatchHistoryService {
  static const int _maxHistoryItems = 50;

  /// Bumped whenever local watch history changes (movie/series/episode watched).
  /// Recommendations screen listens to this for immediate refresh (faster than
  /// waiting for the CloudSync RTDB round-trip).
  static final ValueNotifier<int> localHistoryRevision = ValueNotifier<int>(0);

  static String get _historyListKey =>
      'watch_history_list_${UserScope.currentOwner}';

  static String getWatchHistoryKey(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) {
    final item = isMovie ? 'movie_$tmdbId' : 'tv_${tmdbId}_${season}_$episode';
    return 'watch_history_${UserScope.currentOwner}_$item';
  }

  static Map<String, dynamic>? _decodeMap(String? value) {
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _decodeList(String? value) {
    if (value == null) return [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static int _integer(dynamic value, [int fallback = 0]) =>
      value is num ? value.toInt() : fallback;

  /// Movies ignore season/episode entirely, so they are always stored as
  /// season 1, episode 1. Series values are clamped to be >= 1 so a bad
  /// cloud record (season 0 / episode 0) never produces a dead stream URL.
  static (int, int) _normalizedSeasonEpisode(
    bool isMovie,
    int season,
    int episode,
  ) {
    if (isMovie) return (1, 1);
    return (season < 1 ? 1 : season, episode < 1 ? 1 : episode);
  }

  static Future<Duration> loadWatchPosition(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final history = _decodeMap(
      prefs.getString(getWatchHistoryKey(tmdbId, isMovie, season, episode)),
    );
    return Duration(seconds: _integer(history?['position']));
  }

  static Future<void> saveWatchProgress({
    required String tmdbId,
    required String title,
    required bool isMovie,
    required int season,
    required int episode,
    required Duration position,
    required Duration duration,
    String posterUrl = '',
    String? seriesTitle,
    String? episodeName,
    List<int> genreIds = const [],
  }) async {
    if (position.inSeconds <= 30) return;
    (season, episode) = _normalizedSeasonEpisode(isMovie, season, episode);
    final percentage = duration.inSeconds > 0
        ? (position.inSeconds / duration.inSeconds * 100).clamp(0, 100)
        : 0.0;
    final history = <String, dynamic>{
      'tmdbId': tmdbId,
      'title': title,
      if (!isMovie && seriesTitle != null) 'seriesTitle': seriesTitle,
      if (!isMovie && episodeName != null && episodeName.isNotEmpty)
        'episodeName': episodeName,
      'isMovie': isMovie,
      'season': season,
      'episode': episode,
      'posterUrl': posterUrl,
      'position': position.inSeconds,
      'duration': duration.inSeconds,
      'watchPercentage': percentage,
      'isWatched': percentage >= 90,
      'genreIds': genreIds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      getWatchHistoryKey(tmdbId, isMovie, season, episode),
      jsonEncode(history),
    );
    await _saveToGlobalHistory(history);
    unawaited(CloudSyncService.pushWatchProgress(history));
  }

  /// Persists a history item fetched from the cloud into local storage without
  /// pushing it back up (avoids a push loop). Item keys are deterministic, so
  /// re-importing is idempotent. Non-JSON fields (e.g. the Firestore
  /// `updatedAt` Timestamp) are stripped before encoding.
  static Future<void> importWatchProgress(
    Map<String, dynamic> history,
  ) async {
    final tmdbId = (history['tmdbId'] ?? '').toString();
    final isMovie = history['isMovie'] == true;
    var season = _integer(history['season'], 0);
    var episode = _integer(history['episode'], 0);
    if (tmdbId.isEmpty) return;
    (season, episode) = _normalizedSeasonEpisode(isMovie, season, episode);
    final clean = <String, dynamic>{
      'tmdbId': tmdbId,
      'title': history['title']?.toString() ?? '',
      if (history['seriesTitle'] != null)
        'seriesTitle': history['seriesTitle'].toString(),
      if (history['episodeName'] != null &&
          history['episodeName'].toString().isNotEmpty)
        'episodeName': history['episodeName'].toString(),
      'isMovie': isMovie,
      'season': season,
      'episode': episode,
      'posterUrl': history['posterUrl']?.toString() ?? '',
      'position': _integer(history['position']),
      'duration': _integer(history['duration']),
      'watchPercentage':
          (history['watchPercentage'] as num?)?.toDouble() ?? 0.0,
      'isWatched': history['isWatched'] == true,
      'timestamp': _integer(history['timestamp']),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      getWatchHistoryKey(tmdbId, isMovie, season, episode),
      jsonEncode(clean),
    );
    await _saveToGlobalHistory(clean);
  }

  static Future<void> _saveToGlobalHistory(Map<String, dynamic> history) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decodeList(prefs.getString(_historyListKey));
    list.removeWhere(
      (item) {
        if (item['tmdbId']?.toString() != history['tmdbId']?.toString()) {
          return false;
        }
        if (item['isMovie'] != history['isMovie']) return false;
        // Movies never use season/episode in their key, so the same movie can
        // be saved with (0,0) or (1,1) depending on the entry point. Treat any
        // movie with the same tmdbId as a duplicate to avoid showing the same
        // movie twice in Continue Watching.
        if (history['isMovie'] == true) return true;
        return item['season'] == history['season'] &&
            item['episode'] == history['episode'];
      },
    );
    list.insert(0, history);
    if (list.length > _maxHistoryItems) {
      list.removeRange(_maxHistoryItems, list.length);
    }
    await prefs.setString(_historyListKey, jsonEncode(list));
    // Notify listeners (e.g. Recommendations) immediately – faster than waiting
    // for the CloudSync RTDB echo which may take seconds or fail offline.
    localHistoryRevision.value++;
  }

  static Future<List<Map<String, dynamic>>> getWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeList(prefs.getString(_historyListKey));
  }

  static Future<List<Map<String, dynamic>>> getGroupedWatchHistory() async {
    final history = await getWatchHistory();
    final series = <String, Map<String, dynamic>>{};
    final episodes = <String, Set<String>>{};
    final result = <Map<String, dynamic>>[];
    for (final item in history) {
      if (item['isMovie'] == true) {
        result.add(Map<String, dynamic>.from(item));
        continue;
      }
      final id = item['tmdbId']?.toString() ?? '';
      if (id.isEmpty) continue;
      episodes
          .putIfAbsent(id, () => {})
          .add(
            '${_integer(item['season'], 1)}_${_integer(item['episode'], 1)}',
          );
      if (!series.containsKey(id) ||
          _integer(item['timestamp']) > _integer(series[id]?['timestamp'])) {
        series[id] = Map<String, dynamic>.from(item);
      }
    }
    for (final entry in series.entries) {
      final item = entry.value;
      final seriesTitle = item['seriesTitle']?.toString().trim() ?? '';
      final episodeTitle = item['title']?.toString() ?? 'Unknown Series';
      item['title'] = seriesTitle.isNotEmpty
          ? seriesTitle
          : episodeTitle.replaceFirst(
              RegExp(r'\s*-\s*S\d+E\d+.*$', caseSensitive: false),
              '',
            );
      item['groupedEpisodeCount'] = episodes[entry.key]?.length ?? 1;
      result.add(item);
    }
    result.sort(
      (a, b) => _integer(b['timestamp']).compareTo(_integer(a['timestamp'])),
    );
    return result;
  }

  static Future<List<Map<String, dynamic>>> getContinueWatching() async {
    final history = await getWatchHistory();
    final result = <Map<String, dynamic>>[];
    for (final raw in history) {
      final isMovie = raw['isMovie'] == true;
      final item = Map<String, dynamic>.from(raw);
      final (season, episode) = _normalizedSeasonEpisode(
        isMovie,
        _integer(item['season'], 1),
        _integer(item['episode'], 1),
      );
      item['season'] = season;
      item['episode'] = episode;
      final position = _integer(item['position']);
      final duration = _integer(item['duration']);
      if (position > 30 &&
          duration > 0 &&
          position / duration < .9 &&
          item['isWatched'] != true) {
        result.add(item);
      }
    }
    result.sort(
      (a, b) => _integer(b['timestamp']).compareTo(_integer(a['timestamp'])),
    );
    return result;
  }

  static Future<void> removeFromHistory(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    await removeFromHistoryLocal(tmdbId, isMovie, season, episode);
    unawaited(
      CloudSyncService.deleteWatchProgress(tmdbId, isMovie, season, episode),
    );
  }

  /// Removes an item from local storage only (used by the cloud listener to
  /// apply a remote deletion without pushing it back).
  static Future<void> removeFromHistoryLocal(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(getWatchHistoryKey(tmdbId, isMovie, season, episode));
    final list = _decodeList(prefs.getString(_historyListKey))
      ..removeWhere(
        (item) {
          if (item['tmdbId']?.toString() != tmdbId) return false;
          if (item['isMovie'] != isMovie) return false;
          if (isMovie) return true;
          return _integer(item['season']) == season &&
              _integer(item['episode']) == episode;
        },
      );
    await prefs.setString(_historyListKey, jsonEncode(list));
  }

  static Future<void> removeSeriesFromHistory(String tmdbId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decodeList(prefs.getString(_historyListKey));
    final matches = list.where(
      (item) => item['isMovie'] != true && item['tmdbId']?.toString() == tmdbId,
    );
    for (final item in matches) {
      await prefs.remove(
        getWatchHistoryKey(
          tmdbId,
          false,
          _integer(item['season'], 1),
          _integer(item['episode'], 1),
        ),
      );
    }
    list.removeWhere(
      (item) => item['isMovie'] != true && item['tmdbId']?.toString() == tmdbId,
    );
    await prefs.setString(_historyListKey, jsonEncode(list));
    for (final item in matches) {
      unawaited(
        CloudSyncService.deleteWatchProgress(
          tmdbId,
          false,
          _integer(item['season'], 1),
          _integer(item['episode'], 1),
        ),
      );
    }
  }

  static Future<void> clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    for (final item in await getWatchHistory()) {
      await prefs.remove(
        getWatchHistoryKey(
          item['tmdbId']?.toString() ?? '',
          item['isMovie'] == true,
          _integer(item['season'], 1),
          _integer(item['episode'], 1),
        ),
      );
    }
    await prefs.remove(_historyListKey);
  }

  static Future<bool> hasWatchProgress(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async =>
      (await loadWatchPosition(tmdbId, isMovie, season, episode)).inSeconds >
      30;

  static Future<double> getWatchProgressPercentage(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final value = _decodeMap(
      prefs.getString(getWatchHistoryKey(tmdbId, isMovie, season, episode)),
    );
    final duration = _integer(value?['duration']);
    return duration > 0 ? _integer(value?['position']) / duration : 0;
  }

  static Future<bool> isWatched(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeMap(
          prefs.getString(getWatchHistoryKey(tmdbId, isMovie, season, episode)),
        )?['isWatched'] ==
        true;
  }

  static Future<bool> isResumable(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final value = await getWatchProgressPercentage(
      tmdbId,
      isMovie,
      season,
      episode,
    );
    return value > .1 && value < .9;
  }

  static Future<void> markAsWatched(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    (season, episode) = _normalizedSeasonEpisode(isMovie, season, episode);
    final key = getWatchHistoryKey(tmdbId, isMovie, season, episode);
    final history =
        _decodeMap(prefs.getString(key)) ??
        <String, dynamic>{
          'tmdbId': tmdbId,
          'isMovie': isMovie,
          'season': season,
          'episode': episode,
          'position': 0,
          'duration': 0,
        };
    history['isWatched'] = true;
    history['watchPercentage'] = 100.0;
    history['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(key, jsonEncode(history));
    await _saveToGlobalHistory(history);
  }
}
