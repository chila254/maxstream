import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _subtitleFontKey = 'subtitle_font';
  static const String _subtitleTextSizeKey = 'subtitle_text_size';
  static const String _subtitlePositionKey = 'subtitle_position';
  static const String _subtitlesEnabledKey = 'subtitles_enabled';
  static const String _subtitleBgColorKey = 'subtitle_bg_color';
  static const String _subtitleTextColorKey = 'subtitle_text_color';
  
  static const String _defaultQualityKey = 'default_quality';
  static const String _defaultResizeModeKey = 'default_resize_mode';
  static const String _autoPlayKey = 'auto_play';
  static const String _showThumbnailsKey = 'show_thumbnails';
  static const String _seekSensitivityKey = 'seek_sensitivity';
  static const String _rememberPositionKey = 'remember_position';

  // Subtitle Settings
  static Future<String> getSubtitleFont() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_subtitleFontKey) ?? 'Default';
  }

  static Future<void> setSubtitleFont(String font) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subtitleFontKey, font);
  }

  static Future<double> getSubtitleTextSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_subtitleTextSizeKey) ?? 16.0;
  }

  static Future<void> setSubtitleTextSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_subtitleTextSizeKey, size);
  }

  static Future<String> getSubtitlePosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_subtitlePositionKey) ?? 'Bottom';
  }

  static Future<void> setSubtitlePosition(String position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subtitlePositionKey, position);
  }

  static Future<bool> getSubtitlesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_subtitlesEnabledKey) ?? true;
  }

  static Future<void> setSubtitlesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subtitlesEnabledKey, enabled);
  }

  static Future<Color> getSubtitleBackgroundColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_subtitleBgColorKey) ?? Colors.black.withOpacity(0.7).value;
    return Color(colorValue);
  }

  static Future<void> setSubtitleBackgroundColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_subtitleBgColorKey, color.value);
  }

  static Future<Color> getSubtitleTextColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_subtitleTextColorKey) ?? Colors.white.value;
    return Color(colorValue);
  }

  static Future<void> setSubtitleTextColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_subtitleTextColorKey, color.value);
  }

  // Player Settings
  static Future<String> getDefaultQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultQualityKey) ?? 'Auto';
  }

  static Future<void> setDefaultQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultQualityKey, quality);
  }

  static Future<String> getDefaultResizeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultResizeModeKey) ?? 'Fit';
  }

  static Future<void> setDefaultResizeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultResizeModeKey, mode);
  }

  static Future<bool> getAutoPlay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPlayKey) ?? true;
  }

  static Future<void> setAutoPlay(bool autoPlay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayKey, autoPlay);
  }

  static Future<bool> getShowThumbnails() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showThumbnailsKey) ?? true;
  }

  static Future<void> setShowThumbnails(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showThumbnailsKey, show);
  }

  static Future<double> getSeekSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_seekSensitivityKey) ?? 1.0;
  }

  static Future<void> setSeekSensitivity(double sensitivity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_seekSensitivityKey, sensitivity);
  }

  static Future<bool> getRememberPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberPositionKey) ?? true;
  }

  static Future<void> setRememberPosition(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberPositionKey, remember);
  }

  // Convenience methods to get all settings at once
  static Future<Map<String, dynamic>> getAllSubtitleSettings() async {
    return {
      'font': await getSubtitleFont(),
      'textSize': await getSubtitleTextSize(),
      'position': await getSubtitlePosition(),
      'enabled': await getSubtitlesEnabled(),
      'backgroundColor': await getSubtitleBackgroundColor(),
      'textColor': await getSubtitleTextColor(),
    };
  }

  static Future<Map<String, dynamic>> getAllPlayerSettings() async {
    return {
      'defaultQuality': await getDefaultQuality(),
      'defaultResizeMode': await getDefaultResizeMode(),
      'autoPlay': await getAutoPlay(),
      'showThumbnails': await getShowThumbnails(),
      'seekSensitivity': await getSeekSensitivity(),
      'rememberPosition': await getRememberPosition(),
    };
  }

  // Reset methods
  static Future<void> resetSubtitleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_subtitleFontKey);
    await prefs.remove(_subtitleTextSizeKey);
    await prefs.remove(_subtitlePositionKey);
    await prefs.remove(_subtitlesEnabledKey);
    await prefs.remove(_subtitleBgColorKey);
    await prefs.remove(_subtitleTextColorKey);
  }

  static Future<void> resetPlayerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_defaultQualityKey);
    await prefs.remove(_defaultResizeModeKey);
    await prefs.remove(_autoPlayKey);
    await prefs.remove(_showThumbnailsKey);
    await prefs.remove(_seekSensitivityKey);
    await prefs.remove(_rememberPositionKey);
  }

  static Future<void> resetAllSettings() async {
    await resetSubtitleSettings();
    await resetPlayerSettings();
  }
}
