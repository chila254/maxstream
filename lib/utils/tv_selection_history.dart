import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage TV screen selection history
/// Stores the last focused item index for each screen
class TvSelectionHistory {
  static const String _prefix = 'tv_focus_';

  /// Save the focused index for a specific screen
  static Future<bool> saveFocusIndex(String screenName, int focusIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.setInt('$_prefix$screenName', focusIndex);
    } catch (e) {
      print('Error saving focus index: $e');
      return false;
    }
  }

  /// Get the last focused index for a specific screen
  static Future<int?> getFocusIndex(String screenName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_prefix$screenName');
    } catch (e) {
      print('Error getting focus index: $e');
      return null;
    }
  }

  /// Save focused index and section (for multi-section screens)
  static Future<bool> saveFocusIndexWithSection(
    String screenName,
    int focusIndex,
    String section,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefix${screenName}_index', focusIndex);
      await prefs.setString('$_prefix${screenName}_section', section);
      return true;
    } catch (e) {
      print('Error saving focus with section: $e');
      return false;
    }
  }

  /// Get focused index and section
  static Future<Map<String, dynamic>> getFocusWithSection(String screenName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'index': prefs.getInt('$_prefix${screenName}_index') ?? 0,
        'section': prefs.getString('$_prefix${screenName}_section') ?? '',
      };
    } catch (e) {
      print('Error getting focus with section: $e');
      return {'index': 0, 'section': ''};
    }
  }

  /// Clear focus history for a specific screen
  static Future<bool> clearFocusIndex(String screenName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$screenName');
      await prefs.remove('$_prefix${screenName}_index');
      await prefs.remove('$_prefix${screenName}_section');
      return true;
    } catch (e) {
      print('Error clearing focus index: $e');
      return false;
    }
  }

  /// Clear all focus history
  static Future<bool> clearAllHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith(_prefix)) {
          await prefs.remove(key);
        }
      }
      return true;
    } catch (e) {
      print('Error clearing all history: $e');
      return false;
    }
  }
}
