import '../services/settings_service.dart';

/// Utility class for managing video player settings
class PlayerSettingsUtils {
  /// Apply all saved player settings to a player instance
  static Future<void> applyPlayerSettings() async {
    try {
      // Settings are applied directly in InAppVideoPlayerScreen via _loadSettings()
      // This method is kept for future extensibility if needed
    } catch (e) {
      print('Error applying player settings: $e');
    }
  }

  /// Apply subtitle settings to match user preferences
  static Future<Map<String, dynamic>> getSubtitleSettings() async {
    return await SettingsService.getAllSubtitleSettings();
  }

  /// Map resize mode string to CSS fit value
  /// Video resize mode mapping used in InAppVideoPlayerScreen
  static String mapResizeModeToFit(String mode) {
    switch (mode) {
      case 'Fill':
        return 'cover';
      case 'Fit':
      case 'Center':
        return 'contain';
      case 'Stretch':
        return 'fill';
      default:
        return 'contain';
    }
  }

  /// Get autoPlay setting
  static Future<bool> shouldAutoPlay() async {
    return await SettingsService.getAutoPlay();
  }

  /// Get remember position setting
  static Future<bool> shouldRememberPosition() async {
    return await SettingsService.getRememberPosition();
  }

  /// Get show thumbnails setting
  static Future<bool> shouldShowThumbnails() async {
    return await SettingsService.getShowThumbnails();
  }

  /// Get seek sensitivity setting
  static Future<double> getSeekSensitivity() async {
    return await SettingsService.getSeekSensitivity();
  }

  /// Get default quality setting
  static Future<String> getDefaultQuality() async {
    return await SettingsService.getDefaultQuality();
  }
}
