import 'package:flutter/material.dart';
import '../widgets/profile_menu_button.dart';
import 'maxstream_watchlist_screen.dart';
import 'downloads_screen.dart';
import 'watch_history_screen.dart';

class MaxStreamLibraryScreen extends StatefulWidget {
  const MaxStreamLibraryScreen({super.key});

  @override
  State<MaxStreamLibraryScreen> createState() => _MaxStreamLibraryScreenState();
}

class _MaxStreamLibraryScreenState extends State<MaxStreamLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Library',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ProfileMenuButton(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.bookmark, size: 20), text: 'Watchlist'),
            Tab(icon: Icon(Icons.download, size: 20), text: 'Downloads'),
            Tab(icon: Icon(Icons.history, size: 20), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MaxStreamWatchlistScreen(embedded: true),
          DownloadsScreen(embedded: true),
          WatchHistoryScreen(embedded: true),
        ],
      ),
    );
  }
}
