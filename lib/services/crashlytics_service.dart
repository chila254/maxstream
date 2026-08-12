import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../widgets/crash_screen.dart';

FirebaseCrashlytics? crashlytics;

/// Enables Crashlytics once Firebase is initialized. Must be called after
/// `Firebase.initializeApp` because it needs the native Firebase core.
Future<void> enableCrashlyticsReporting() async {
  try {
    final instance = FirebaseCrashlytics.instance;
    await instance.setCrashlyticsCollectionEnabled(true);
    crashlytics = instance;
  } catch (_) {
    crashlytics = null;
  }
}

/// Wraps the existing Flutter error handlers so fatal Dart errors also reach
/// Crashlytics (with the local report gate still shown). Native crashes are
/// captured by the Crashlytics NDK automatically once the SDK is initialized.
void attachCrashlyticsFatalHandlers() {
  final previousFlutter = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    // Let the local handlers do their thing (they filter benign errors), but
    // never record a benign video player channel race to Crashlytics - it is
    // a progress nicety, not a failure, and recording it as "fatal" would be
    // worse than the non-fatal noise it replaced.
    previousFlutter?.call(details);
    if (isBenignVideoPlayerChannelError(details.exception)) return;
    unawaited(crashlytics?.recordFlutterFatalError(details));
  };
  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final handled = previousPlatform?.call(error, stack) ?? true;
    if (!isBenignVideoPlayerChannelError(error)) {
      unawaited(crashlytics?.recordError(error, stack, fatal: true));
    }
    return handled;
  };
}

/// Best-effort record for zone-level errors.
Future<void> reportCrashlytics(
  String tag,
  Object error,
  StackTrace stack,
) async {
  final instance = crashlytics;
  if (instance == null) return;
  try {
    await instance.setCustomKey('tag', tag);
    await instance.recordError(error, stack, reason: tag);
  } catch (_) {}
}
