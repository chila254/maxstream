import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_api_service.dart';
import '../database/db_helper.dart';

class ContentNotificationService {
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings darwinInitializationSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidInitializationSettings,
          iOS: darwinInitializationSettings,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('ContentNotificationService: Initialized');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  static Future<void> checkAndNotifyNewContent() async {
    try {
      debugPrint('ContentNotificationService: Checking for new content...');

      // Get preferred providers
      final preferredProviders = await DBHelper.getPreferredProviders();

      if (preferredProviders.isEmpty) {
        debugPrint('ContentNotificationService: No preferred providers');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Check movies for each provider
      for (final provider in preferredProviders) {
        await _checkProviderMovies(provider, prefs);
        await _checkProviderShows(provider, prefs);
      }
    } catch (e) {
      debugPrint('ContentNotificationService Error: $e');
    }
  }

  static Future<void> _checkProviderMovies(
    Map<String, dynamic> provider,
    SharedPreferences prefs,
  ) async {
    try {
      final providerId = provider['providerId'] as int;
      final providerName = provider['providerName'] as String? ?? 'Provider';

      debugPrint(
        'ContentNotificationService: Checking movies for $providerName (ID: $providerId)',
      );

      final movies = await TmdbApiService.getMoviesByProvider(
        providerId,
        page: 1,
      );

      if (movies.isEmpty) {
        debugPrint(
          'ContentNotificationService: No movies found for $providerName',
        );
        return;
      }

      final lastCheckedKey = 'last_movie_check_$providerId';
      final previousMovieIds = _getStoredIds(prefs, lastCheckedKey);

      final newMovies = movies
          .where(
            (movie) =>
                !(previousMovieIds.contains(movie['id'] as int?)) &&
                movie['poster_path'] != null,
          )
          .toList();

      if (newMovies.isNotEmpty) {
        debugPrint(
          'ContentNotificationService: Found ${newMovies.length} new movies for $providerName',
        );

        // Send notification for new movies
        await _sendNewContentNotification(
          providerName: providerName,
          contentType: 'movie',
          newContentCount: newMovies.length,
          newContent: newMovies,
        );

        // Store the current movie IDs
        final currentIds = movies
            .map((m) => (m['id'] as int?).toString())
            .whereType<String>()
            .toList();
        await prefs.setStringList(lastCheckedKey, currentIds);
      }
    } catch (e) {
      debugPrint('ContentNotificationService: Error checking movies: $e');
    }
  }

  static Future<void> _checkProviderShows(
    Map<String, dynamic> provider,
    SharedPreferences prefs,
  ) async {
    try {
      final providerId = provider['providerId'] as int;
      final providerName = provider['providerName'] as String? ?? 'Provider';

      debugPrint(
        'ContentNotificationService: Checking shows for $providerName (ID: $providerId)',
      );

      final shows = await TmdbApiService.getSeriesByProvider(
        providerId,
        page: 1,
      );

      if (shows.isEmpty) {
        debugPrint(
          'ContentNotificationService: No shows found for $providerName',
        );
        return;
      }

      final lastCheckedKey = 'last_show_check_$providerId';
      final previousShowIds = _getStoredIds(prefs, lastCheckedKey);

      final newShows = shows
          .where(
            (show) =>
                !(previousShowIds.contains(show['id'] as int?)) &&
                show['poster_path'] != null,
          )
          .toList();

      if (newShows.isNotEmpty) {
        debugPrint(
          'ContentNotificationService: Found ${newShows.length} new shows for $providerName',
        );

        // Send notification for new shows
        await _sendNewContentNotification(
          providerName: providerName,
          contentType: 'show',
          newContentCount: newShows.length,
          newContent: newShows,
        );

        // Store the current show IDs
        final currentIds = shows
            .map((s) => (s['id'] as int?).toString())
            .whereType<String>()
            .toList();
        await prefs.setStringList(lastCheckedKey, currentIds);
      }
    } catch (e) {
      debugPrint('ContentNotificationService: Error checking shows: $e');
    }
  }

  static Set<int> _getStoredIds(SharedPreferences prefs, String key) {
    final stored = prefs.getStringList(key) ?? [];
    return stored
        .map((id) => int.tryParse(id) ?? 0)
        .where((id) => id != 0)
        .toSet();
  }

  static Future<void> _sendNewContentNotification({
    required String providerName,
    required String contentType,
    required int newContentCount,
    required List<Map<String, dynamic>> newContent,
  }) async {
    try {
      final title =
          '$newContentCount new ${contentType == 'movie' ? 'movies' : 'shows'} on $providerName';
      final firstContent = newContent.isNotEmpty
          ? newContent[0]['title'] ?? newContent[0]['name'] ?? 'New Content'
          : 'New Content';

      final body = newContentCount > 1
          ? '$firstContent + ${newContentCount - 1} more'
          : firstContent;

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
            'maxstream_content_channel',
            'New Content Notifications',
            channelDescription:
                'Notifications for new content on your favorite providers',
            importance: Importance.max,
            priority: Priority.high,
            showProgress: false,
            autoCancel: true,
          );

      const DarwinNotificationDetails darwinNotificationDetails =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: darwinNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        providerName.hashCode,
        title,
        body,
        notificationDetails,
        payload: 'provider:$providerName',
      );

      debugPrint(
        'ContentNotificationService: Notification sent for $providerName',
      );
    } catch (e) {
      debugPrint('ContentNotificationService: Error sending notification: $e');
    }
  }

  static Future<void> schedulePeriodicCheck() async {
    try {
      // Check immediately
      await checkAndNotifyNewContent();

      // Schedule periodic checks every 6 hours
      debugPrint('ContentNotificationService: Scheduled periodic checks');
    } catch (e) {
      debugPrint('ContentNotificationService: Error scheduling checks: $e');
    }
  }
}
