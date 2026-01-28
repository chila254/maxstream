import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../database/db_helper.dart';
import '../../models/movie.dart';
import '../../services/logger_service.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';
import '../utils/tv_focus_manager.dart';
import '../utils/tv_navigation_handler.dart';
import '../widgets/tv_dark_mode_polish.dart';
import '../widgets/tv_content_card.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';

class TvWatchlistScreen extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;

  const TvWatchlistScreen({super.key, this.onReturnToSidebar});

  @override
  State<TvWatchlistScreen> createState() => _TvWatchlistScreenState();
}

class _TvWatchlistScreenState extends State<TvWatchlistScreen>
    with SingleTickerProviderStateMixin {
  List<Movie> watchlistItems = [];
  List<Movie> movies = [];
  List<Movie> series = [];
  bool isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Integrate with navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TvNavigationProvider>();
    });
    
    _loadWatchlist();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWatchlist() async {
    setState(() => isLoading = true);
    try {
      final items = await DBHelper.getWatchlistItems();
      setState(() {
        watchlistItems = items;
        movies = items.where((item) => item.mediaType != 'tv').toList();
        series = items.where((item) => item.mediaType == 'tv').toList();
        // Set initial focus to first item in watchlist
        if (watchlistItems.isNotEmpty) {}
      });
    } catch (e) {
      LoggerService.error('Error loading watchlist: $e', e);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeFromWatchlist(Movie item) async {
    try {
      await DBHelper.removeFromWatchlist(item.id);
      await _loadWatchlist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('${item.title} removed from watchlist'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Error removing from watchlist: $e', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DarkModeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
              context.read<TvNavigationProvider>().setFocusOnSidebar(true);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          autofocus: true,
          child: Column(
            children: [
              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFE50914),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(
                    text: 'All (${watchlistItems.length})',
                    child: Text(
                      'All (${watchlistItems.length})',
                      style: TvTypography.labelSmall,
                    ),
                  ),
                  Tab(
                    text: 'Movies (${movies.length})',
                    child: Text(
                      'Movies (${movies.length})',
                      style: TvTypography.labelSmall,
                    ),
                  ),
                  Tab(
                    text: 'Series (${series.length})',
                    child: Text(
                      'Series (${series.length})',
                      style: TvTypography.labelSmall,
                    ),
                  ),
                ],
              ),
              // Tab Content
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          watchlistItems.isEmpty
                              ? _buildEmptyState()
                              : _buildWatchlistGrid(watchlistItems),
                          movies.isEmpty
                              ? _buildEmptyState()
                              : _buildWatchlistGrid(movies),
                          series.isEmpty
                              ? _buildEmptyState()
                              : _buildWatchlistGrid(series),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: TvUtils.responsiveFontSize(64, context, maxSize: 100),
            color: Colors.grey,
          ),
          SizedBox(height: TvUtils.responsivePadding(24, context)),
          Text(
            'Your watchlist is empty',
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(24, context, maxSize: 32),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(12, context)),
          Text(
            'Add movies and TV shows to keep track of what you want to watch',
            style: TextStyle(
              color: Colors.grey,
              fontSize: TvUtils.responsiveFontSize(16, context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistGrid(List<Movie> items) {
    return _WatchlistGridFocus(
      items: items,
      itemsPerRow: 6,
      onItemSelected: (index) {
        if (!mounted) return;
        final item = items[index];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => item.mediaType == 'tv'
                ? TvSeriesScreen(seriesItem: item)
                : TvDetailsScreen(item: item, mediaType: item.mediaType),
          ),
        );
      },
      onReturnToSidebar: () {
        context.read<TvNavigationProvider>().setFocusOnSidebar(true);
      },
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildWatchlistItem(item);
      },
      onRemoveItem: (index) => _removeFromWatchlist(items[index]),
    );
  }

  Widget _buildWatchlistItem(Movie item) {
    final contentType = item.mediaType == 'tv'
        ? ContentType.series
        : ContentType.movie;

    return Stack(
      children: [
        TvContentCard(
          posterUrl: item.thumbnail,
          title: item.title,
          contentType: contentType,
          rating: item.rating > 0 ? item.rating : null,
          year: item.year.isNotEmpty ? int.tryParse(item.year) : null,
          onTap: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => item.mediaType == 'tv'
                    ? TvSeriesScreen(seriesItem: item)
                    : TvDetailsScreen(item: item, mediaType: item.mediaType),
              ),
            );
          },
          width: 180,
          height: 270,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _removeFromWatchlist(item),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 24),
            ),
          ),
        ),
      ],
    );
  }
}

/// Grid focus handler for watchlist with D-pad navigation
class _WatchlistGridFocus extends StatefulWidget {
  final List<Movie> items;
  final int itemsPerRow;
  final Function(int) onItemSelected;
  final VoidCallback onReturnToSidebar;
  final Widget Function(BuildContext, int) itemBuilder;
  final Function(int) onRemoveItem;

  const _WatchlistGridFocus({
    required this.items,
    required this.itemsPerRow,
    required this.onItemSelected,
    required this.onReturnToSidebar,
    required this.itemBuilder,
    required this.onRemoveItem,
  });

  @override
  State<_WatchlistGridFocus> createState() => _WatchlistGridFocusState();
}

class _WatchlistGridFocusState extends State<_WatchlistGridFocus> {
  late int _focusedIndex;
  late List<FocusNode> _focusNodes;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusedIndex = 0;
    _scrollController = ScrollController();
    
    _focusNodes = List.generate(
      widget.items.length,
      (index) => FocusNode(
        onKey: (node, event) => _handleItemKeyEvent(event, index),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleItemKeyEvent(RawKeyEvent event, int index) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

    final currentCol = index % widget.itemsPerRow;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (TvNavigation.isAtLeftBoundary(index, itemsPerRow: widget.itemsPerRow)) {
        TvFocusManager.focusSidebar();
        widget.onReturnToSidebar();
        return KeyEventResult.handled;
      } else {
        final prevIndex = index - 1;
        _focusNodes[prevIndex].requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (index < widget.items.length - 1 && currentCol < widget.itemsPerRow - 1) {
        final nextIndex = index + 1;
        _focusNodes[nextIndex].requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final nextIndex = index + widget.itemsPerRow;
      if (nextIndex < widget.items.length) {
        _focusNodes[nextIndex].requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final prevIndex = index - widget.itemsPerRow;
      if (prevIndex >= 0) {
        _focusNodes[prevIndex].requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.select) {
      widget.onItemSelected(index);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.itemsPerRow,
        childAspectRatio: 0.6,
        crossAxisSpacing: TvUtils.responsivePadding(16, context),
        mainAxisSpacing: TvUtils.responsivePadding(16, context),
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final isFocused = _focusedIndex == index;
        
        return Focus(
          focusNode: _focusNodes[index],
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              setState(() => _focusedIndex = index);
            }
          },
          child: AnimatedScale(
            scale: isFocused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isFocused ? const Color(0xFFE50914) : Colors.transparent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  widget.itemBuilder(context, index),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => widget.onRemoveItem(index),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
