import 'package:flutter/material.dart';
import 'maxstream_home_screen.dart';
import 'maxstream_search_screen.dart';
import 'maxstream_series_list_screen.dart';
import 'maxstream_watchlist_screen.dart';
import 'maxstream_more_screen.dart';
import '../services/update_service.dart';
import '../services/notification_permission_service.dart';
import '../services/content_notification_service.dart';

class MaxStreamMainScreen extends StatefulWidget {
  const MaxStreamMainScreen({super.key});

  @override
  State<MaxStreamMainScreen> createState() => _MaxStreamMainScreenState();
}

class _MaxStreamMainScreenState extends State<MaxStreamMainScreen> {
  int _currentIndex = 0;
  bool _updateChecked = false;

  void _onTabChange(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _checkForUpdates();
    _checkNotificationPermission();
    // Initialize notification service and schedule periodic checks
    await ContentNotificationService.initialize();
    await ContentNotificationService.schedulePeriodicCheck();
  }

  Future<void> _checkForUpdates() async {
    if (_updateChecked) return;

    final hasUpdate = await UpdateService.checkForUpdate();
    if (hasUpdate && mounted) {
      _showUpdateDialog();
    }
    _updateChecked = true;
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

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of MaxStream is available. Would you like to download and install it now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              UpdateService.downloadAndInstallUpdate(context);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  List<Widget> get _screens => [
    MaxStreamHomeScreen(onTabChange: _onTabChange),
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
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF1A1A1A),
          selectedItemColor: Colors.red,
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Series'),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark),
              label: 'Watchlist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

