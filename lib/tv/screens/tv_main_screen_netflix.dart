import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/tv_netflix_dpad_mixin.dart';
import '../widgets/tv_netflix_sidebar.dart';
import '../providers/tv_navigation_provider.dart';
import 'tv_home_screen_v2.dart';
import 'tv_search_screen.dart';
import 'tv_genre_screen.dart';
import 'tv_series_list_screen.dart';
import 'tv_watchlist_screen.dart';
import 'tv_more_screen.dart';

/// Netflix-style TV main screen with smooth sidebar-to-content navigation
/// - Instant sidebar selection with visual feedback
/// - Non-blocking content loading (data loads in background)
/// - Smooth transitions between tabs
class TvMainScreenNetflix extends StatefulWidget {
  const TvMainScreenNetflix({super.key});

  @override
  State<TvMainScreenNetflix> createState() => _TvMainScreenNetflixState();
}

class _TvMainScreenNetflixState extends State<TvMainScreenNetflix>
    with TvNetflixDpadMixin {
  late PageController _contentPageController;
  int _focusedTabIndex = 0;
  bool _focusOnSidebar = true;

  final List<String> _titles = [
    'Home',
    'Search',
    'Genres',
    'Series',
    'Watchlist',
    'More',
  ];

  final List<IconData> _icons = [
    Icons.home,
    Icons.search,
    Icons.theaters,
    Icons.tv,
    Icons.bookmark,
    Icons.more_horiz,
  ];

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _contentPageController = PageController();
    _screens = [
      TvHomeScreenV2(onReturnToSidebar: _returnToSidebar),
      TvSearchScreen(onReturnToSidebar: _returnToSidebar),
      TvGenreScreen(onReturnToSidebar: _returnToSidebar),
      TvSeriesListScreen(onReturnToSidebar: _returnToSidebar),
      TvWatchlistScreen(onReturnToSidebar: _returnToSidebar),
      TvMoreScreen(onReturnToSidebar: _returnToSidebar),
    ];
  }

  @override
  void dispose() {
    _contentPageController.dispose();
    super.dispose();
  }

  // Netflix-style navigation mixin implementation
  @override
  int get tabCount => _titles.length;

  @override
  void onTabChanged(int index) {
    // Instant UI update - visual feedback happens immediately
    setState(() {
      _focusedTabIndex = index;
    });
    // Content loads asynchronously in background (non-blocking)
    _contentPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void onFocusToSidebar() {
    setState(() => _focusOnSidebar = true);
  }

  @override
  void onFocusToContent() {
    setState(() => _focusOnSidebar = false);
  }

  void _returnToSidebar() {
    setState(() => _focusOnSidebar = true);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TvNavigationProvider(),
      child: RawKeyboardListener(
        onKey: handleKeyEvent,
        focusNode: focusNode,
        child: WillPopScope(
          onWillPop: () async {
            if (_focusedTabIndex != 0) {
              setState(() => _focusedTabIndex = 0);
              _contentPageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
              );
              return false;
            }
            return true;
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: Row(
              children: [
                // Sidebar - Always visible, instant selection
                TvNetflixSidebar(
                  selectedIndex: _focusedTabIndex,
                  isFocused: _focusOnSidebar,
                  titles: _titles,
                  icons: _icons,
                  onItemSelected: (index) {
                    // Tap on sidebar item: instant visual feedback
                    setState(() {
                      _focusedTabIndex = index;
                      _focusOnSidebar = false; // Automatically move to content
                    });
                    // Animate to content screen (non-blocking)
                    _contentPageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
                // Content Area - Loads async while UI is responsive
                Expanded(
                  child: PageView(
                    controller: _contentPageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
