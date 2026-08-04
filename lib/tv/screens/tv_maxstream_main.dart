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
  }

  @override
  void dispose() {
    _sidebarFocusScope.dispose();
    _contentFocusScope.dispose();
    TvFocusManager.dispose();
    _navProvider.dispose();
    super.dispose();
  }

  void _onNavItemSelected(int index) {
    _navProvider.selectTab(index);
  }

  void _focusContent() {
    _navProvider.setFocusOnSidebar(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _contentFocusScope.requestFocus();
      });
    });
  }

  void _focusSidebar() {
    _navProvider.setFocusOnSidebar(true);
    TvFocusManager.focusSidebar();
  }

  void _handleSystemBack() {
    final navigator = _navigatorKey.currentState;
    if (navigator?.canPop() == true) {
      navigator!.pop();
      return;
    }
    if (!_navProvider.focusOnSidebar) {
      _focusSidebar();
    } else {
      SystemNavigator.pop();
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
          if (!didPop) _handleSystemBack();
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
          return Row(
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
