import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPermissionService {
  static const String _notificationPermissionKey =
      'notification_permission_requested';

  static Future<bool> hasRequestedNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationPermissionKey) ?? false;
  }

  static Future<void> markNotificationPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationPermissionKey, true);
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  static Future<bool> isNotificationPermissionGranted() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      return false;
    }
  }

  static Future<void> showNotificationPermissionDialog(
    BuildContext context, {
    required VoidCallback onAllow,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Stay Updated',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get notifications when new content arrives on your favorite streaming services',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[300], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Benefits:',
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Instant alerts for new releases\n'
                    '• Trending content notifications\n'
                    '• Personalized recommendations\n'
                    '• New episodes of your shows',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              markNotificationPermissionRequested();
            },
            child: Text(
              'Not Now',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await markNotificationPermissionRequested();
              final isGranted = await requestNotificationPermission();
              if (isGranted) {
                onAllow.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifications enabled successfully!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Allow Notifications',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
