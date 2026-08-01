import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tv_navigation_provider.dart';
import '../widgets/tv_sidebar_navigation.dart';
import '../utils/tv_focus_manager.dart';
import 'tv_home_screen.dart';
import 'tv_search_screen.dart';
import 'tv_genre_screen.dart';
import 'tv_series_list_screen.dart';
import 'tv_watchlist_screen.dart';
import 'tv_more_screen.dart';

/// Handles directional focus between the persistent navigation and content.
class TvDirectionalFocusAction extends Action<DirectionalFocusIntent> {
  final TvNavigationProvider navProvider;
  final FocusNode sidebarFocusNode;
  final FocusNode contentFocusNode;

  TvDirectionalFocusAction({
    required this.navProvider,
    required this.sidebarFocusNode,
    required this.contentFocusNode,
  });

  @override
  Object? invoke(DirectionalFocusIntent intent) {
    switch (intent.direction) {
      case TraversalDirection.right:
        // From sidebar to content
        if (navProvider.focusOnSidebar) {
          navProvider.setFocusOnSidebar(false);
          contentFocusNode.requestFocus();
        } else {
          // Within content, let default traversal handle it
          FocusManager.instance.primaryFocus?.focusInDirection(
            intent.direction,
          );
        }
        break;
      case TraversalDirection.left:
        // From content to sidebar - uses TvNavigation for consistent handling
        if (!navProvider.focusOnSidebar) {
          navProvider.setFocusOnSidebar(true);
          TvFocusManager.focusSidebar();
        } else {
          // Within sidebar, let default traversal handle it
          FocusManager.instance.primaryFocus?.focusInDirection(
            intent.direction,
          );
        }
        break;
      default:
        // Up/Down handled by default traversal
        FocusManager.instance.primaryFocus?.focusInDirection(intent.direction);
        break;
    }
    return null;
  }
}

/// NavigatorObserver to track deep navigation (details, player screens)
class TvNavigationObserver extends NavigatorObserver {
  final TvNavigationProvider provider;

  TvNavigationObserver(this.provider);
  int _depth = 0;

  @override
  void didPush(Route route, Route? previousRoute) {
    _depth++;
    provider.setDeepNavigating(_depth > 1);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _depth = (_depth - 1).clamp(0, 1 << 20);
    provider.setDeepNavigating(_depth > 1);
    if (_depth <= 1) provider.setFocusOnSidebar(false);
  }
}

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
  late FocusNode _sidebarFocusNode;
  late FocusNode _contentFocusNode;
  bool _sidebarFocused = false; // Content-first: start on content, not sidebar

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

    // Initialize focus nodes for sidebar and content
    _sidebarFocusNode = FocusNode();
    _contentFocusNode = FocusNode();

    // Initialize the global focus manager
    TvFocusManager.initialize(
      sidebarFocusNode: _sidebarFocusNode,
      contentFocusNode: _contentFocusNode,
    );

    // Sidebar is secondary navigation - only LEFT moves to it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navProvider.setFocusOnSidebar(false);
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _sidebarFocusNode.dispose();
    _contentFocusNode.dispose();
    TvFocusManager.dispose();
    _navProvider.dispose();
    super.dispose();
  }

  void _onNavItemSelected(int index) {
    _navProvider.selectTab(index);
    setState(() => _sidebarFocused = false);
  }

  void _focusContent() {
    _navProvider.setFocusOnSidebar(false);
    _contentFocusNode.requestFocus();
  }

  void _focusSidebar() {
    _navProvider.setFocusOnSidebar(true);
    TvFocusManager.focusSidebar();
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
          if (didPop) return;
          final navigator = _navigatorKey.currentState;
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
          } else if (!_navProvider.focusOnSidebar) {
            _navProvider.setFocusOnSidebar(true);
            TvFocusManager.focusSidebar();
          } else {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: Shortcuts(
            shortcuts: {
              LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                  const DirectionalFocusIntent(TraversalDirection.left),
              LogicalKeySet(LogicalKeyboardKey.arrowRight):
                  const DirectionalFocusIntent(TraversalDirection.right),
              LogicalKeySet(LogicalKeyboardKey.arrowUp):
                  const DirectionalFocusIntent(TraversalDirection.up),
              LogicalKeySet(LogicalKeyboardKey.arrowDown):
                  const DirectionalFocusIntent(TraversalDirection.down),
            },
            child: Actions(
              actions: {
                DirectionalFocusIntent: TvDirectionalFocusAction(
                  navProvider: _navProvider,
                  sidebarFocusNode: _sidebarFocusNode,
                  contentFocusNode: _contentFocusNode,
                ),
              },
              child: Consumer<TvNavigationProvider>(
                builder: (context, navProvider, _) {
                  // Sync _sidebarFocused with provider's focusOnSidebar
                  if (_sidebarFocused != navProvider.focusOnSidebar) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(
                          () => _sidebarFocused = navProvider.focusOnSidebar,
                        );
                      }
                    });
                  }

                  return Row(
                    children: [
                      // Left Sidebar Navigation
                      FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: Focus(
                          focusNode: _sidebarFocusNode,
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              setState(() => _sidebarFocused = true);
                              _navProvider.setFocusOnSidebar(true);
                            }
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
                      ),
                      // Content Screen - Expanded and Clean
                      Expanded(
                        child: FocusTraversalGroup(
                          policy: ReadingOrderTraversalPolicy(),
                          child: Focus(
                            focusNode: _contentFocusNode,
                            onFocusChange: (hasFocus) {
                              if (hasFocus) {
                                setState(() => _sidebarFocused = false);
                                _navProvider.setFocusOnSidebar(false);
                              }
                            },
                            child: Navigator(
                              key: _navigatorKey,
                              observers: [TvNavigationObserver(_navProvider)],
                              onGenerateRoute: (settings) {
                                return MaterialPageRoute(
                                  builder: (context) => _buildCurrentScreen(),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
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
