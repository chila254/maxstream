import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static late FlutterLocalNotificationsPlugin _notificationsPlugin;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'maxstream_channel',
      'MaxStream Notifications',
      channelDescription: 'Notifications for content availability',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> notifyNewContent({
    required String contentTitle,
    required String providerName,
    required String mediaType,
  }) async {
    await showNotification(
      id: DateTime.now().millisecond,
      title: 'New on $providerName!',
      body: '$contentTitle is now available on $providerName ($mediaType)',
      payload: 'new_content:$contentTitle:$providerName',
    );
  }

  Future<void> notifyMultipleProvidersAdded({
    required String contentTitle,
    required List<String> providerNames,
    required String mediaType,
  }) async {
    final providers = providerNames.join(', ');
    await showNotification(
      id: DateTime.now().millisecond,
      title: '$contentTitle is now on multiple platforms!',
      body: 'Available on: $providers',
      payload: 'content_expanded:$contentTitle',
    );
  }

  Future<void> notifyPreferredProviderUpdate({
    required String contentTitle,
    required String providerName,
  }) async {
    await showNotification(
      id: DateTime.now().millisecond,
      title: 'Your Favorite Provider Has It!',
      body: '$contentTitle just became available on $providerName',
      payload: 'preferred:$contentTitle:$providerName',
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
