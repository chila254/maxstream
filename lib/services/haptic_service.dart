import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticService {
  static Future<void> lightImpact() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 50, amplitude: 128);
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Fallback to Flutter's haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  static Future<void> mediumImpact() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 100, amplitude: 180);
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      HapticFeedback.mediumImpact();
    }
  }

  static Future<void> heavyImpact() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 150, amplitude: 255);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
    }
  }

  static Future<void> selectionClick() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 30, amplitude: 100);
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (e) {
      HapticFeedback.selectionClick();
    }
  }

  static Future<void> success() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 50, 50, 100], amplitude: 200);
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      HapticFeedback.mediumImpact();
    }
  }

  static Future<void> error() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 100, 100, 100, 100, 100], amplitude: 255);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
    }
  }
}
