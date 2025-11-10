import 'package:flutter/material.dart';
import 'onstream_home_screen.dart';
import 'onstream_search_screen.dart';
import 'onstream_series_list_screen.dart';
import 'onstream_watchlist_screen.dart';
import 'onstream_more_screen.dart';
import '../services/update_service.dart';

class OnStreamMainScreen extends StatefulWidget {
  const OnStreamMainScreen({super.key});

  @override
  State<OnStreamMainScreen> createState() => _OnStreamMainScreenState();
}

class _OnStreamMainScreenState extends State<OnStreamMainScreen> {
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
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (_updateChecked) return;

    final hasUpdate = await UpdateService.checkForUpdate();
    if (hasUpdate && mounted) {
      _showUpdateDialog();
    }
    _updateChecked = true;
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
    OnStreamHomeScreen(onTabChange: _onTabChange),
    const OnStreamSearchScreen(),
    const OnStreamSeriesListScreen(),
    const OnStreamWatchlistScreen(),
    const OnStreamMoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return false; // Don't pop the screen
        }
        return true; // Allow popping the screen
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
