import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tv_navigation_provider.dart';
import '../services/tv_update_service.dart';
import '../widgets/tv_sidebar_navigation.dart';
import '../utils/tv_focus_manager.dart';
import 'tv_home_screen.dart';
import 'tv_search_screen.dart';
import 'tv_genre_screen.dart';
import 'tv_series_list_screen.dart';
import 'tv_watchlist_screen.dart';
import 'tv_more_screen.dart';

/// MaxStream TV shell.
/// Features:
/// - Left sidebar navigation
/// - Clean screen switching without friction
/// - Each screen manages its own content and navigation
/// - Modern MaxStream branding
/// - D-Pad navigation support
/// - Proper state management via provider
class TvMaxStreamMain extends StatefulWidget {
  const TvMaxStreamMain({super.key});

  @override
  State<TvMaxStreamMain> createState() => _TvMaxStreamMainState();
}

class _TvMaxStreamMainState extends State<TvMaxStreamMain> {
  late TvNavigationProvider _navProvider;
  late GlobalKey<NavigatorState> _navigatorKey;
  late FocusScopeNode _sidebarFocusScope;
  late FocusScopeNode _contentFocusScope;
  Timer? _updateTimer;
  bool _checkingForUpdate = false;

  final List<String> _navTitles = [
    'Home',
    'Search',
    'Genre',
    'Series',
    'Watchlist',
    'More',
  ];

  final List<IconData> _navIcons = [
    Icons.home,
    Icons.search,
    Icons.theaters,
    Icons.tv,
    Icons.bookmark,
    Icons.settings,
  ];

  @override
  void initState() {
    super.initState();
    _navProvider = TvNavigationProvider();
    _navigatorKey = GlobalKey<NavigatorState>();

    _sidebarFocusScope = FocusScopeNode(debugLabel: 'TV sidebar');
    _contentFocusScope = FocusScopeNode(debugLabel: 'TV root content');

    TvFocusManager.initialize(
      sidebarFocusNode: _sidebarFocusScope,
      contentFocusNode: _contentFocusScope,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleUpdateCheck();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _sidebarFocusScope.dispose();
    _contentFocusScope.dispose();
    TvFocusManager.dispose();
    _navProvider.dispose();
    super.dispose();
  }

  void _scheduleUpdateCheck() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _checkForUpdate(),
    );
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (_checkingForUpdate) return;
    _checkingForUpdate = true;
    try {
      final info = await TvUpdateService.checkForUpdate();
      if (!mounted || info == null) return;
      if (!TvUpdateService.reserveUpdateDialog(info.version)) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TvUpdateDialog(
          info: info,
          onDownload: () {
            Navigator.of(context).pop();
            TvUpdateService.downloadAndInstallUpdate(context, info.downloadUrl);
          },
        ),
      );
    } finally {
      _checkingForUpdate = false;
    }
  }

  void _onNavItemSelected(int index) {
    _navProvider.selectTab(index);
  }

  void _focusContent() {
    _navProvider.setFocusOnSidebar(false);
    _requestFocusAfterFrames(_contentFocusScope, retries: 6);
  }

  void _focusSidebar() {
    _navProvider.setFocusOnSidebar(true);
    _requestFocusAfterFrames(_sidebarFocusScope, retries: 6);
  }

  /// Requests focus on [node], retrying across subsequent frames until it
  /// succeeds. After a tab switch the content screen rebuilds and only then
  /// attaches its focusable widgets, so a single post-frame callback is not
  /// enough and focus can silently fail.
  void _requestFocusAfterFrames(FocusNode node, {required int retries}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      node.requestFocus();
      if (retries > 1 && !node.hasFocus) {
        _requestFocusAfterFrames(node, retries: retries - 1);
      }
    });
  }

  /// Unified system-back handler:
  /// - Back on a pushed route pops that route.
  /// - Back on a non-Home tab moves focus to the sidebar first, then the next
  ///   back press switches to the Home tab.
  /// - Back on the Home tab shows the exit confirmation dialog.
  void _handleSystemBack() {
    final navigator = _navigatorKey.currentState;
    if (navigator?.canPop() == true) {
      navigator!.pop();
      return;
    }
    if (_navProvider.selectedTab != 0) {
      if (_sidebarFocusScope.hasFocus) {
        _navProvider.selectTab(0);
        _focusContent();
      } else {
        _focusSidebar();
      }
      return;
    }
    _confirmExit();
  }

  /// Shell-level key handler. It only sees back/escape keys that every focused
  /// widget deeper in the tree (content cards, keyboard, sidebar items) chose
  /// not to consume, so in-screen back navigation still runs first and the
  /// shell handles only the "leave this screen / exit the app" level.
  KeyEventResult _onShellBackKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.gameButtonB) {
      try {
        _handleSystemBack();
      } catch (e, st) {
        debugPrint('MAXSTREAM: back handler threw: $e\n$st');
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _exitDialogShowing = false;

  Future<void> _confirmExit() async {
    if (_exitDialogShowing) return;
    _exitDialogShowing = true;
    try {
      final shouldExit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Exit MaxStream?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Do you want to exit the app?',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Yes',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      );
      if (shouldExit == true && mounted) {
        SystemNavigator.pop();
      }
    } finally {
      _exitDialogShowing = false;
    }
  }

  List<Widget> _buildScreens() {
    return [
      TvHomeScreen(
        onReturnToSidebar: _focusSidebar,
        navigatorKey: _navigatorKey,
      ),
      TvSearchScreen(onReturnToSidebar: _focusSidebar),
      TvGenreScreen(onReturnToSidebar: _focusSidebar),
      TvSeriesListScreen(onReturnToSidebar: _focusSidebar),
      TvWatchlistScreen(onReturnToSidebar: _focusSidebar),
      TvMoreScreen(onReturnToSidebar: _focusSidebar),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TvNavigationProvider>.value(
      value: _navProvider,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            try {
              _handleSystemBack();
            } catch (e, st) {
              debugPrint('MAXSTREAM: back handler threw: $e\n$st');
            }
          }
        },
        child: Navigator(
          key: _navigatorKey,
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute(
              settings: const RouteSettings(name: 'tv-root'),
              builder: (_) => _buildRootShell(),
            ),
          ],
          onGenerateRoute: (_) => null,
        ),
      ),
    );
  }

  Widget _buildRootShell() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Consumer<TvNavigationProvider>(
        builder: (context, navProvider, _) {
          return Focus(
            onKeyEvent: _onShellBackKey,
            child: Row(
              children: [
                FocusScope(
                  node: _sidebarFocusScope,
                  onFocusChange: (hasFocus) {
                    if (hasFocus) navProvider.setFocusOnSidebar(true);
                  },
                  child: TvSidebarNavigation(
                    selectedIndex: navProvider.selectedTab,
                    titles: _navTitles,
                    icons: _navIcons,
                    onItemSelected: _onNavItemSelected,
                    onExitToContent: _focusContent,
                    active: navProvider.focusOnSidebar,
                  ),
                ),
                Expanded(
                  child: FocusScope(
                    node: _contentFocusScope,
                    onFocusChange: (hasFocus) {
                      if (hasFocus) navProvider.setFocusOnSidebar(false);
                    },
                    child: _buildCurrentScreen(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentScreen() {
    return Consumer<TvNavigationProvider>(
      builder: (context, navProvider, _) {
        final screens = _buildScreens();
        return screens[navProvider.selectedTab];
      },
    );
  }
}
