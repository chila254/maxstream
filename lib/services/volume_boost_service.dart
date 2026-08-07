import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the in-app audio boost (in decibels) applied to video playback.
///
/// The gain is applied by the patched `video_player_android` plugin through an
/// ExoPlayer audio processor, so it works even for streams whose audio is mixed
/// much quieter than normal (these sources do no loudness normalization). The
/// level is persisted so it survives app restarts.
class VolumeBoostService {
  static const MethodChannel _channel = MethodChannel('maxstream/volume_boost');
  static const String _prefsKey = 'volume_boost_db';

  /// Selectable boost levels in dB. The first entry is the default when the
  /// user has never changed the setting.
  static const List<double> levels = [6, 0, 12, 18];

  static double defaultGainDb = levels.first;

  /// Reads the currently applied gain from the native player.
  static Future<double> getGainDb() async {
    try {
      final value = await _channel.invokeMethod<double>('getGainDb');
      if (value != null) return value;
    } catch (_) {}
    return 0;
  }

  /// Applies a gain level (dB) to every currently and future playing video.
  static Future<void> setGainDb(double db) async {
    try {
      await _channel.invokeMethod<void>('setGainDb', db);
    } catch (_) {}
  }

  /// Loads the persisted boost level, or the default when never set.
  static Future<double> loadPersistedGainDb() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKey);
    if (saved != null) return saved;
    return defaultGainDb;
  }

  /// Persists the boost level so it survives app restarts.
  static Future<void> persistGainDb(double db) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, db);
  }
}
