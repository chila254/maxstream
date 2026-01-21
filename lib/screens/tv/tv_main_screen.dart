import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/tv_utils.dart';
import '../../utils/tv_dpad_navigation_mixin.dart';
import '../../widgets/tv_focus_widget.dart';
import 'tv_home_screen.dart';
import 'tv_search_screen.dart';
import 'tv_genre_screen.dart';
import 'tv_series_list_screen.dart';
import 'tv_watchlist_screen.dart';
import 'tv_more_screen.dart';

class TvMainScreen extends StatefulWidget {
  const TvMainScreen({super.key});

  @override
  State<TvMainScreen> createState() => _TvMainScreenState();
}

class _TvMainScreenState extends State<TvMainScreen> with TvDpadNavigationMixin {
  int _currentIndex = 0;
  bool _focusOnSidebar = true; // Track if focus is on sidebar or content

  // Screens corresponding to phone app structure
  late List<Widget> _screens;

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

  @override
  void initState() {
    super.initState();
    _screens = [
      TvHomeScreen(onReturnToSidebar: _returnToSidebar),
      TvSearchScreen(onReturnToSidebar: _returnToSidebar),
      TvGenreScreen(onReturnToSidebar: _returnToSidebar),
      TvSeriesListScreen(onReturnToSidebar: _returnToSidebar),
      TvWatchlistScreen(onReturnToSidebar: _returnToSidebar),
      TvMoreScreen(onReturnToSidebar: _returnToSidebar),
    ];
  }

  void _returnToSidebar() {
    setState(() => _focusOnSidebar = true);
  }

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex => _titles.length - 1; // Home, Search, Genres, Series, Watchlist, More

  @override
  void onFocusChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void onSelectPressed() {
    // Screen changes are handled by onFocusChanged
  }

  @override
  void handleKeyEvent(RawKeyEvent event) {
    if (_focusOnSidebar) {
      // When focus is on sidebar, handle all navigation
      if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
        _moveFocus(1);
      } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
        _moveFocus(-1);
      } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
        onLeftPressed();
      } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
        onRightPressed();
      } else if (event.isKeyPressed(LogicalKeyboardKey.select) ||
          event.isKeyPressed(LogicalKeyboardKey.enter)) {
        onSelectPressed();
      }
    }
    // Content screens handle their own navigation via their RawKeyboardListener
  }

  void _moveFocus(int direction) {
    final newIndex = (_currentIndex + direction).clamp(0, maxFocusIndex);
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      onFocusChanged(newIndex);
    }
  }

  @override
  void onLeftPressed() {
    // Left arrow: Move focus from content to sidebar
    if (!_focusOnSidebar) {
      setState(() => _focusOnSidebar = true);
    }
  }

  @override
  void onRightPressed() {
    // Right arrow: Move focus from sidebar to content
    if (_focusOnSidebar) {
      setState(() => _focusOnSidebar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      onKey: handleKeyEvent,
      focusNode: focusNode,
      child: WillPopScope(
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
        backgroundColor: const Color(0xFF121212),
        body: Row(
          children: [
            // Sidebar Navigation
            _buildSidebar(context),
            // Main Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _screens[_currentIndex],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final sidebarWidth = TvUtils.responsiveWidth(140, context, maxWidth: 200);
    final padding = TvUtils.responsivePadding(12, context);

    return Container(
      width: sidebarWidth,
      color: const Color(0xFF1A1A1A),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: _focusOnSidebar
            ? Border(right: BorderSide(color: Colors.red, width: 3))
            : null,
      ),
      child: Column(
        children: [
          // Logo/Title
          Container(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_fill,
                  color: Colors.red,
                  size: TvUtils.responsiveFontSize(40, context, maxSize: 60),
                ),
                SizedBox(height: TvUtils.responsivePadding(8, context)),
                Text(
                  'MaxStream',
                  style: TextStyle(
                    fontSize: TvUtils.responsiveFontSize(
                      16,
                      context,
                      maxSize: 24,
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey[800], thickness: 1),
          // Navigation Items - Changed from ListView.builder (vertical) to Column (vertical navigation via up/down)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(
                  _icons.length,
                  (index) => _buildNavItem(context, index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final isSelected = _currentIndex == index;
    final fontSize = TvUtils.responsiveFontSize(13, context, maxSize: 18);
    final iconSize = TvUtils.responsiveFontSize(24, context, maxSize: 36);
    final padding = TvUtils.responsivePadding(10, context);

    return TvFocusButton(
      isFocused: isSelected,
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: TvUtils.responsivePadding(6, context),
          vertical: TvUtils.responsivePadding(6, context),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.red.withOpacity(0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: Colors.red, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _icons[index],
                  color: isSelected ? Colors.red : Colors.grey,
                  size: iconSize,
                ),
                SizedBox(height: TvUtils.responsivePadding(6, context)),
                Text(
                  _titles[index],
                  style: TextStyle(
                    color: isSelected ? Colors.red : Colors.grey,
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              ),
              ),
              ),
              ),
              );
              }
              }
