import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WatchHistoryService {
  static const String _historyListKey = 'watch_history_list';
  static const int _maxHistoryItems = 50;

  /// Get the watch history key for a specific item
  static String getWatchHistoryKey(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) {
    if (isMovie) {
      return 'watch_history_movie_$tmdbId';
    } else {
      return 'watch_history_tv_${tmdbId}_${season}_$episode';
    }
  }

  /// Load watch position for a specific item
  static Future<Duration> loadWatchPosition(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = getWatchHistoryKey(tmdbId, isMovie, season, episode);
    final historyJson = prefs.getString(key);

    if (historyJson != null) {
      final history = json.decode(historyJson);
      return Duration(seconds: history['position'] ?? 0);
    }

    return Duration.zero;
  }

  /// Save watch progress for a specific item
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
    final prefs = await SharedPreferences.getInstance();
    final key = getWatchHistoryKey(tmdbId, isMovie, season, episode);

    // Calculate watch percentage
    final watchPercentage = duration.inSeconds > 0
        ? (position.inSeconds / duration.inSeconds * 100).clamp(0, 100)
        : 0.0;

    // Mark as watched if >90% complete
    final isWatched = watchPercentage >= 90;

    // Only save if watched more than 30 seconds
    if (position.inSeconds <= 30) {
      return;
    }

    final history = {
      'tmdbId': tmdbId,
      'title': title,
      if (!isMovie && seriesTitle != null) 'seriesTitle': seriesTitle,
      'isMovie': isMovie,
      'season': season,
      'episode': episode,
      'posterUrl': posterUrl,
      'position': position.inSeconds,
      'duration': duration.inSeconds,
      'watchPercentage': watchPercentage,
      'isWatched': isWatched,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Save individual item history
    await prefs.setString(key, json.encode(history));

    // Save to global history list
    await _saveToGlobalHistory(history);
  }

  /// Save to global watch history list
  static Future<void> _saveToGlobalHistory(Map<String, dynamic> history) async {
    final prefs = await SharedPreferences.getInstance();
    final historyListJson = prefs.getString(_historyListKey) ?? '[]';
    final historyList = List<Map<String, dynamic>>.from(
      json.decode(historyListJson),
    );

    // Remove existing entry for this content
    historyList.removeWhere(
      (item) =>
          item['tmdbId'] == history['tmdbId'] &&
          item['isMovie'] == history['isMovie'] &&
          item['season'] == history['season'] &&
          item['episode'] == history['episode'],
    );

    // Add new entry at the beginning
    historyList.insert(0, history);

    // Keep only last N entries
    if (historyList.length > _maxHistoryItems) {
      historyList.removeRange(_maxHistoryItems, historyList.length);
    }

    await prefs.setString(_historyListKey, json.encode(historyList));
  }

  /// Get all watch history
  static Future<List<Map<String, dynamic>>> getWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyListJson = prefs.getString(_historyListKey) ?? '[]';
    return List<Map<String, dynamic>>.from(json.decode(historyListJson));
  }

  /// Group episodes from the same series into one entry represented by the
  /// most recently watched episode. Movies remain as individual entries.
  static Future<List<Map<String, dynamic>>> getGroupedWatchHistory() async {
    final history = await getWatchHistory();
    final groupedSeries = <String, Map<String, dynamic>>{};
    final episodeKeys = <String, Set<String>>{};
    final result = <Map<String, dynamic>>[];

    for (final item in history) {
      if (item['isMovie'] == true) {
        result.add(Map<String, dynamic>.from(item));
        continue;
      }

      final tmdbId = item['tmdbId']?.toString() ?? '';
      if (tmdbId.isEmpty) continue;
      episodeKeys
          .putIfAbsent(tmdbId, () => <String>{})
          .add('${item['season'] ?? 1}_${item['episode'] ?? 1}');
      final existing = groupedSeries[tmdbId];
      final timestamp = (item['timestamp'] as num?)?.toInt() ?? 0;
      final existingTimestamp = (existing?['timestamp'] as num?)?.toInt() ?? -1;
      if (existing == null || timestamp > existingTimestamp) {
        groupedSeries[tmdbId] = Map<String, dynamic>.from(item);
      }
    }

    for (final entry in groupedSeries.entries) {
      final item = entry.value;
      final storedTitle = item['seriesTitle']?.toString().trim();
      final episodeTitle = item['title']?.toString() ?? 'Unknown Series';
      item['title'] = storedTitle?.isNotEmpty == true
          ? storedTitle
          : episodeTitle.replaceFirst(
              RegExp(r'\s*-\s*S\d+E\d+.*$', caseSensitive: false),
              '',
            );
      item['groupedEpisodeCount'] = episodeKeys[entry.key]?.length ?? 1;
      result.add(item);
    }

    result.sort(
      (a, b) => ((b['timestamp'] as num?)?.toInt() ?? 0).compareTo(
        (a['timestamp'] as num?)?.toInt() ?? 0,
      ),
    );
    return result;
  }

  /// Get only unfinished items that can be resumed from the home screen.
  static Future<List<Map<String, dynamic>>> getContinueWatching() async {
    final history = await getWatchHistory();
    return history.where((item) {
      final position = (item['position'] as num?)?.toInt() ?? 0;
      final duration = (item['duration'] as num?)?.toInt() ?? 0;
      if (position <= 30 || duration <= 0) return false;
      return position / duration < 0.9 && item['isWatched'] != true;
    }).toList()..sort(
      (a, b) => ((b['timestamp'] as num?)?.toInt() ?? 0).compareTo(
        (a['timestamp'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  /// Remove specific item from history
  static Future<void> removeFromHistory(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove from individual history
    final key = getWatchHistoryKey(tmdbId, isMovie, season, episode);
    await prefs.remove(key);

    // Remove from global history list
    final historyListJson = prefs.getString(_historyListKey) ?? '[]';
    final historyList = List<Map<String, dynamic>>.from(
      json.decode(historyListJson),
    );

    historyList.removeWhere(
      (item) =>
          item['tmdbId'] == tmdbId &&
          item['isMovie'] == isMovie &&
          item['season'] == season &&
          item['episode'] == episode,
    );

    await prefs.setString(_historyListKey, json.encode(historyList));
  }

  /// Remove every watched episode belonging to one series.
  static Future<void> removeSeriesFromHistory(String tmdbId) async {
    final prefs = await SharedPreferences.getInstance();
    final historyListJson = prefs.getString(_historyListKey) ?? '[]';
    final historyList = List<Map<String, dynamic>>.from(
      json.decode(historyListJson),
    );
    final episodes = historyList.where(
      (item) => item['isMovie'] != true && item['tmdbId']?.toString() == tmdbId,
    );
    for (final item in episodes) {
      await prefs.remove(
        getWatchHistoryKey(
          tmdbId,
          false,
          (item['season'] as num?)?.toInt() ?? 1,
          (item['episode'] as num?)?.toInt() ?? 1,
        ),
      );
    }
    historyList.removeWhere(
      (item) => item['isMovie'] != true && item['tmdbId']?.toString() == tmdbId,
    );
    await prefs.setString(_historyListKey, json.encode(historyList));
  }

  /// Clear all watch history
  static Future<void> clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // Get all history items to remove individual entries
    final historyList = await getWatchHistory();
    for (final item in historyList) {
      final key = getWatchHistoryKey(
        item['tmdbId'],
        item['isMovie'],
        item['season'] ?? 1,
        item['episode'] ?? 1,
      );
      await prefs.remove(key);
    }

    // Clear global history list
    await prefs.remove(_historyListKey);
  }

  /// Check if item has watch progress
  static Future<bool> hasWatchProgress(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final position = await loadWatchPosition(tmdbId, isMovie, season, episode);
    return position.inSeconds > 30;
  }

  /// Get watch progress percentage
  static Future<double> getWatchProgressPercentage(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = getWatchHistoryKey(tmdbId, isMovie, season, episode);
    final historyJson = prefs.getString(key);

    if (historyJson != null) {
      final history = json.decode(historyJson);
      final position = history['position'] ?? 0;
      final duration = history['duration'] ?? 1;
      return position / duration;
    }

    return 0.0;
  }

  /// Check if episode/movie is watched (>90% complete)
  static Future<bool> isWatched(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = getWatchHistoryKey(tmdbId, isMovie, season, episode);
    final historyJson = prefs.getString(key);

    if (historyJson != null) {
      final history = json.decode(historyJson);
      return history['isWatched'] ?? false;
    }

    return false;
  }

  /// Check if resumable (>10% watched and not complete)
  static Future<bool> isResumable(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final watchPercentage = await getWatchProgressPercentage(
      tmdbId,
      isMovie,
      season,
      episode,
    );
    return watchPercentage > 0.1 && watchPercentage < 0.9;
  }

  /// Mark episode as watched
  static Future<void> markAsWatched(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = getWatchHistoryKey(tmdbId, isMovie, season, episode);
    final historyJson = prefs.getString(key);

    Map<String, dynamic> history;
    if (historyJson != null) {
      history = json.decode(historyJson);
    } else {
      history = {
        'tmdbId': tmdbId,
        'isMovie': isMovie,
        'season': season,
        'episode': episode,
        'position': 0,
        'duration': 0,
      };
    }

    history['isWatched'] = true;
    history['watchPercentage'] = 100.0;
    history['timestamp'] = DateTime.now().millisecondsSinceEpoch;

    await prefs.setString(key, json.encode(history));
    await _saveToGlobalHistory(history);
  }
}
