import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../database/db_helper.dart';
import '../../models/movie.dart';
import '../../services/logger_service.dart';
import '../../widgets/custom_loading_widget.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/tv_focus_manager.dart';
import '../widgets/tv_content_card.dart';
import '../widgets/tv_dark_mode_polish.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';

class TvWatchlistScreen extends StatefulWidget {
  const TvWatchlistScreen({super.key, this.onReturnToSidebar});

  final VoidCallback? onReturnToSidebar;

  @override
  State<TvWatchlistScreen> createState() => _TvWatchlistScreenState();
}

class _TvWatchlistScreenState extends State<TvWatchlistScreen> {
  static const _navigationTab = 4;
  static const _rowId = 'watchlist-grid';
  final _scrollController = ScrollController();
  final _tabNodes = List.generate(
    3,
    (index) => FocusNode(debugLabel: 'watchlist-tab-$index'),
  );
  final Map<String, FocusNode> _cardNodes = {};

  List<Movie> _all = const [];
  int _selectedTab = 0;
  String? _rememberedIdentity;
  int _rememberedIndex = 0;
  bool _loading = true;
  String? _error;

  List<Movie> get _items => switch (_selectedTab) {
    1 => _all.where((item) => item.mediaType != 'tv').toList(),
    2 => _all.where((item) => item.mediaType == 'tv').toList(),
    _ => _all,
  };

  String _identity(Movie item) => '${item.mediaType}:${item.id}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = context.read<TvNavigationProvider>();
      nav.registerScrollController(_navigationTab, _scrollController);
      _tabNodes[_selectedTab].requestFocus();
    });
    _loadWatchlist();
  }

  @override
  void dispose() {
    for (final node in [..._tabNodes, ..._cardNodes.values]) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWatchlist({bool showLoading = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });
    try {
      final items = await DBHelper.getWatchlistItems();
      if (!mounted) return;
      final identities = items.map(_identity).toSet();
      setState(() {
        _all = items;
        _loading = false;
        for (final key in _cardNodes.keys.toList()) {
          if (!identities.contains(key)) _cardNodes.remove(key)?.dispose();
        }
      });
    } catch (error) {
      LoggerService.error('Error loading watchlist: $error', error);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your watchlist could not be loaded.';
      });
    }
  }

  FocusNode _cardNode(Movie item) => _cardNodes.putIfAbsent(
    _identity(item),
    () => FocusNode(debugLabel: 'watchlist-${_identity(item)}'),
  );

  void _sidebar() {
    if (!mounted) return;
    context.read<TvNavigationProvider>().setFocusOnSidebar(true);
    (widget.onReturnToSidebar ?? TvFocusManager.focusSidebar).call();
  }

  void _selectTab(int index, {bool focusGrid = false}) {
    if (index != _selectedTab) {
      setState(() {
        _selectedTab = index;
        _rememberedIdentity = null;
        _rememberedIndex = 0;
      });
    }
    final nav = context.read<TvNavigationProvider>();
    nav
      ..setFocusOnSidebar(false)
      ..setSectionFocusIndex(_navigationTab, focusGrid ? 1 : 0);
    if (focusGrid && _items.isNotEmpty) {
      _focusItem(_nearestIndex());
    } else if (!focusGrid) {
      _tabNodes[index].requestFocus();
    }
  }

  int _nearestIndex() {
    final items = _items;
    if (items.isEmpty) return 0;
    final exact = items.indexWhere(
      (item) => _identity(item) == _rememberedIdentity,
    );
    return exact >= 0 ? exact : _rememberedIndex.clamp(0, items.length - 1);
  }

  void _focusItem(int index) {
    final items = _items;
    if (items.isEmpty) {
      _tabNodes[_selectedTab].requestFocus();
      return;
    }
    final target = index.clamp(0, items.length - 1);
    final item = items[target];
    _rememberedIndex = target;
    _rememberedIdentity = _identity(item);
    context.read<TvNavigationProvider>()
      ..setFocusOnSidebar(false)
      ..setSectionFocusIndex(_navigationTab, 1)
      ..saveFocusedIndex(_navigationTab, target)
      ..saveActiveRowId(_navigationTab, _rowId)
      ..saveRowFocusedIndex(_rowId, target);
    _cardNode(item).requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cardContext = _cardNode(item).context;
      if (cardContext != null) {
        Scrollable.ensureVisible(
          cardContext,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: .12,
        );
      }
    });
  }

  KeyEventResult _onTabKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) {
        _sidebar();
      } else {
        _selectTab(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _selectTab((index + 1).clamp(0, _tabNodes.length - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_items.isNotEmpty) _focusItem(_nearestIndex());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      _selectTab(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      _sidebar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onCardKey(int index, int columns, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    int? target;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index % columns == 0) {
        _tabNodes[_selectedTab].requestFocus();
        context.read<TvNavigationProvider>().setSectionFocusIndex(
          _navigationTab,
          0,
        );
      } else {
        target = index - 1;
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (index % columns < columns - 1 && index + 1 < _items.length) {
        target = index + 1;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (index < columns) {
        _tabNodes[_selectedTab].requestFocus();
        context.read<TvNavigationProvider>().setSectionFocusIndex(
          _navigationTab,
          0,
        );
      } else {
        target = index - columns;
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final nextRow = index + columns;
      if (nextRow < _items.length) {
        target = nextRow;
      } else {
        final rowStart = (index ~/ columns + 1) * columns;
        if (rowStart < _items.length) {
          target = _items.length - 1;
        }
      }
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.contextMenu) {
      _confirmRemove(_items[index]);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      _tabNodes[_selectedTab].requestFocus();
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    if (target != null) _focusItem(target);
    return KeyEventResult.handled;
  }

  Future<void> _open(int index) async {
    final item = _items[index];
    _rememberedIdentity = _identity(item);
    _rememberedIndex = index;
    context.read<TvNavigationProvider>().setDeepNavigating(true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => item.mediaType == 'tv'
            ? TvSeriesScreen(seriesItem: item)
            : TvDetailsScreen(item: item, mediaType: item.mediaType),
      ),
    );
    if (!mounted) return;
    context.read<TvNavigationProvider>().setDeepNavigating(false);
    await _loadWatchlist(showLoading: false);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _items.isEmpty) return;
        final target = _nearestIndex();
        _focusItem(target);
        final cardContext = _cardNode(_items[target]).context;
        if (cardContext != null) {
          Scrollable.ensureVisible(
            cardContext,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: .12,
          );
        }
      });
    });
  }

  Future<void> _confirmRemove(Movie item) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from watchlist?'),
        content: Text(item.title),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || remove != true) return;
    try {
      await DBHelper.removeFromWatchlist(item.id, item.mediaType);
      if (!mounted) return;
      await _loadWatchlist(showLoading: false);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_items.isEmpty) {
          _tabNodes[_selectedTab].requestFocus();
        } else {
          _focusItem(_nearestIndex());
        }
      });
    } catch (error) {
      LoggerService.error('Error removing watchlist item: $error', error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This title could not be removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DarkModeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(36, 28, 36, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Watchlist',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              _buildTabs(),
              const SizedBox(height: 22),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final counts = [
      _all.length,
      _all.where((item) => item.mediaType != 'tv').length,
      _all.where((item) => item.mediaType == 'tv').length,
    ];
    const labels = ['All', 'Movies', 'Series'];
    return Row(
      children: List.generate(3, (index) {
        final selected = index == _selectedTab;
        return Focus(
          focusNode: _tabNodes[index],
          onKeyEvent: (_, event) => _onTabKey(index, event),
          onFocusChange: (focused) {
            if (focused) _selectTab(index);
          },
          child: Builder(
            builder: (context) => GestureDetector(
              onTap: () => _selectTab(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE50914) : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Focus.of(context).hasFocus
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Text(
                  '${labels[index]} (${counts[index]})',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const _WatchlistMessage(
        icon: Icons.bookmarks,
        title: 'Loading your watchlist',
        child: CustomLoadingWidget(size: 44),
      );
    }
    if (_error != null) {
      return _WatchlistMessage(
        icon: Icons.error_outline,
        title: _error!,
        subtitle: 'Check your connection and try again.',
        child: FilledButton.icon(
          autofocus: true,
          onPressed: _loadWatchlist,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }
    if (_items.isEmpty) {
      return const _WatchlistMessage(
        icon: Icons.bookmark_border,
        title: 'Nothing saved here yet',
        subtitle: 'Add movies and series to build your watchlist.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1350 ? 8 : 7;
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: .68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return TvContentCard(
              key: ValueKey(_identity(item)),
              focusNode: _cardNode(item),
              posterUrl: item.thumbnail,
              title: item.title,
              contentType: item.mediaType == 'tv'
                  ? ContentType.series
                  : ContentType.movie,
              rating: item.rating > 0 ? item.rating : null,
              year: int.tryParse(item.year),
              width: 130,
              height: 190,
              onTap: () => _open(index),
              onSelect: () => _open(index),
              onKeyEvent: (_, event) => _onCardKey(index, columns, event),
              onFocusChanged: (focused) {
                if (focused) _focusItem(index);
              },
            );
          },
        );
      },
    );
  }
}

class _WatchlistMessage extends StatelessWidget {
  const _WatchlistMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 72, color: Colors.white54),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 9),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ],
        if (child != null) ...[const SizedBox(height: 20), child!],
      ],
    ),
  );
}
