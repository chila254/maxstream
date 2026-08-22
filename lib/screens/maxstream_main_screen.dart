import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'maxstream_home_screen.dart';
import 'maxstream_search_screen.dart';
import 'maxstream_series_list_screen.dart';
import 'maxstream_watchlist_screen.dart';
import 'maxstream_recommendations_screen.dart';
import 'maxstream_more_screen.dart';
import '../services/update_service.dart';
import '../services/notification_permission_service.dart';
import '../services/content_notification_service.dart';
import '../services/recommendation_notification_service.dart';

class MaxStreamMainScreen extends StatefulWidget {
  const MaxStreamMainScreen({super.key});

  @override
  State<MaxStreamMainScreen> createState() => _MaxStreamMainScreenState();
}

class _MaxStreamMainScreenState extends State<MaxStreamMainScreen> {
  int _currentIndex = 0;
  Timer? _updateTimer;
  Timer? _contentCheckTimer;
  Timer? _recommendationTimer;
  bool _checkingForUpdate = false;

  void _onTabChange(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeServices();
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _contentCheckTimer?.cancel();
    _recommendationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    unawaited(_checkForUpdates());
    _updateTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => unawaited(_checkForUpdates()),
    );
    _checkNotificationPermission();
    _contentCheckTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => unawaited(ContentNotificationService.checkAndNotifyNewContent()),
    );
    unawaited(ContentNotificationService.checkAndNotifyNewContent());
    _recommendationTimer = Timer.periodic(
      const Duration(hours: 8),
      (_) => unawaited(RecommendationNotificationService.checkAndNotify()),
    );
    unawaited(RecommendationNotificationService.checkAndNotify());
  }

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdate) return;
    _checkingForUpdate = true;
    try {
      final info = await UpdateService.checkForUpdate();
      if (info == null) return;
      try {
        await UpdateService.checkAndNotify(info: info);
      } catch (error) {
        debugPrint('Could not show update notification: $error');
      }
      if (mounted && UpdateService.reserveUpdateDialog(info.version)) {
        _showUpdateDialog(info);
      }
    } catch (error) {
      debugPrint('Could not check for updates: $error');
    } finally {
      _checkingForUpdate = false;
    }
  }

  Future<void> _checkNotificationPermission() async {
    final hasRequested =
        await NotificationPermissionService.hasRequestedNotificationPermission();
    final isGranted =
        await NotificationPermissionService.isNotificationPermissionGranted();

    if (!hasRequested && !isGranted && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        NotificationPermissionService.showNotificationPermissionDialog(
          context,
          onAllow: () {
            debugPrint('User allowed notifications');
          },
        );
      }
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Update to v${info.version}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A new version is available. Would you like to download it?',
                style: TextStyle(fontSize: 14),
              ),
              if (info.changelog.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'What\'s New:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      info.changelog,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              UpdateService.downloadAndInstallUpdate(context, info.downloadUrl);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  List<Widget> get _screens => [
    MaxStreamHomeScreen(onTabChange: _onTabChange),
    const MaxStreamRecommendationsScreen(),
    const MaxStreamSearchScreen(),
    const MaxStreamSeriesListScreen(),
    const MaxStreamWatchlistScreen(),
    const MaxStreamMoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _screens[_currentIndex],
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: Colors.red,
              unselectedItemColor: Colors.grey,
              currentIndex: _currentIndex,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              elevation: 0,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.explore), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.tv), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
