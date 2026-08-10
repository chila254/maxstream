import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

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
    previousFlutter?.call(details);
    unawaited(crashlytics?.recordFlutterFatalError(details));
  };
  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final handled = previousPlatform?.call(error, stack) ?? true;
    unawaited(crashlytics?.recordError(error, stack, fatal: true));
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
