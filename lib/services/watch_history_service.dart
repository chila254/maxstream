import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_scope.dart';

class WatchHistoryService {
  static const int _maxHistoryItems = 50;

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
  }) async {
    if (position.inSeconds <= 30) return;
    final percentage = duration.inSeconds > 0
        ? (position.inSeconds / duration.inSeconds * 100).clamp(0, 100)
        : 0.0;
    final history = <String, dynamic>{
      'tmdbId': tmdbId,
      'title': title,
      if (!isMovie && seriesTitle != null) 'seriesTitle': seriesTitle,
      'isMovie': isMovie,
      'season': season,
      'episode': episode,
      'posterUrl': posterUrl,
      'position': position.inSeconds,
      'duration': duration.inSeconds,
      'watchPercentage': percentage,
      'isWatched': percentage >= 90,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      getWatchHistoryKey(tmdbId, isMovie, season, episode),
      jsonEncode(history),
    );
    await _saveToGlobalHistory(history);
  }

  static Future<void> _saveToGlobalHistory(Map<String, dynamic> history) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decodeList(prefs.getString(_historyListKey));
    list.removeWhere(
      (item) =>
          item['tmdbId'] == history['tmdbId'] &&
          item['isMovie'] == history['isMovie'] &&
          item['season'] == history['season'] &&
          item['episode'] == history['episode'],
    );
    list.insert(0, history);
    if (list.length > _maxHistoryItems) {
      list.removeRange(_maxHistoryItems, list.length);
    }
    await prefs.setString(_historyListKey, jsonEncode(list));
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
    return history.where((item) {
      final position = _integer(item['position']);
      final duration = _integer(item['duration']);
      return position > 30 &&
          duration > 0 &&
          position / duration < .9 &&
          item['isWatched'] != true;
    }).toList()..sort(
      (a, b) => _integer(b['timestamp']).compareTo(_integer(a['timestamp'])),
    );
  }

  static Future<void> removeFromHistory(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(getWatchHistoryKey(tmdbId, isMovie, season, episode));
    final list = _decodeList(prefs.getString(_historyListKey))
      ..removeWhere(
        (item) =>
            item['tmdbId']?.toString() == tmdbId &&
            item['isMovie'] == isMovie &&
            _integer(item['season']) == season &&
            _integer(item['episode']) == episode,
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
