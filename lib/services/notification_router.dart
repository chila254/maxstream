import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/movie.dart';
import '../screens/maxstream_details_screen.dart';
import '../screens/maxstream_series_screen.dart';
import 'update_service.dart';

/// Central handler for notification taps. Dispatches by payload prefix and
/// navigates using a global navigator key, so it works from the phone's
/// notification panel regardless of which screen is currently visible.
class NotificationRouter {
  static GlobalKey<NavigatorState>? navigatorKey;
  static String? _pendingPayload;

  /// Called once the root navigator is attached (after the first frame).
  static void registerNavigator(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
    final pending = _pendingPayload;
    _pendingPayload = null;
    if (pending != null) _openPayload(pending);
  }

  /// Entry point wired into flutter_local_notifications.
  static void handleTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    if (navigatorKey?.currentContext == null) {
      _pendingPayload = payload;
      return;
    }
    _openPayload(payload);
  }

  static Future<void> _openPayload(String payload) async {
    if (payload.startsWith('update:')) {
      final context = navigatorKey?.currentContext;
      if (context == null || !context.mounted) return;
      final url = payload.substring('update:'.length);
      UpdateService.downloadAndInstallUpdate(context, url);
      return;
    }

    if (payload.startsWith('content:')) {
      // Only open details screens once the user is signed in.
      if (FirebaseAuth.instance.currentUser == null) return;
      final context = navigatorKey?.currentContext;
      if (context == null || !context.mounted) return;
      final parts = payload.split(':');
      if (parts.length < 3) return;
      final mediaType = parts[1];
      final id = parts[2];
      final item = Movie.fromJson({
        'id': id,
        'media_type': mediaType,
        'title': ' ',
        'name': ' ',
        'overview': '',
        'poster_path': '',
        'vote_average': 0,
      });
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => mediaType == 'tv'
              ? MaxStreamSeriesScreen(seriesItem: item)
              : MaxStreamDetailsScreen(item: item, mediaType: 'movie'),
        ),
      );
    }
  }
}
