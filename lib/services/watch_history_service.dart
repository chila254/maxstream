import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WatchHistoryService {
  static const String _historyListKey = 'watch_history_list';
  static const int _maxHistoryItems = 50;

  /// Get the watch history key for a specific item
  static String getWatchHistoryKey(String tmdbId, bool isMovie, int season, int episode) {
    if (isMovie) {
      return 'watch_history_movie_$tmdbId';
    } else {
      return 'watch_history_tv_${tmdbId}_${season}_$episode';
    }
  }

  /// Load watch position for a specific item
  static Future<Duration> loadWatchPosition(String tmdbId, bool isMovie, int season, int episode) async {
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
  }) async {
    // Only save if watched more than 30 seconds and less than 90% complete
    if (position.inSeconds <= 30 || position.inSeconds >= duration.inSeconds * 0.9) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = getWatchHistoryKey(tmdbId, isMovie, season, episode);
    
    final history = {
      'tmdbId': tmdbId,
      'title': title,
      'isMovie': isMovie,
      'season': season,
      'episode': episode,
      'position': position.inSeconds,
      'duration': duration.inSeconds,
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
    final historyList = List<Map<String, dynamic>>.from(json.decode(historyListJson));
    
    // Remove existing entry for this content
    historyList.removeWhere((item) => 
      item['tmdbId'] == history['tmdbId'] && 
      item['isMovie'] == history['isMovie'] &&
      item['season'] == history['season'] &&
      item['episode'] == history['episode']
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

  /// Remove specific item from history
  static Future<void> removeFromHistory(String tmdbId, bool isMovie, int season, int episode) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove from individual history
    final key = getWatchHistoryKey(tmdbId, isMovie, season, episode);
    await prefs.remove(key);
    
    // Remove from global history list
    final historyListJson = prefs.getString(_historyListKey) ?? '[]';
    final historyList = List<Map<String, dynamic>>.from(json.decode(historyListJson));
    
    historyList.removeWhere((item) => 
      item['tmdbId'] == tmdbId && 
      item['isMovie'] == isMovie &&
      item['season'] == season &&
      item['episode'] == episode
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
  static Future<bool> hasWatchProgress(String tmdbId, bool isMovie, int season, int episode) async {
    final position = await loadWatchPosition(tmdbId, isMovie, season, episode);
    return position.inSeconds > 30;
  }

  /// Get watch progress percentage
  static Future<double> getWatchProgressPercentage(String tmdbId, bool isMovie, int season, int episode) async {
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
}