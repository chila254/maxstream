import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/movie.dart';
import '../../services/tmdb_api_service.dart';
import '../providers/tv_navigation_provider.dart';
import '../widgets/tv_content_card.dart';
import '../widgets/tv_dark_mode_polish.dart';
import 'tv_series_screen.dart';
import 'tv_video_player_screen.dart';

class TvSeriesListScreen extends StatefulWidget {
  final Movie? seriesItem;
  final int initialSeasonIndex;
  final VoidCallback? onReturnToSidebar;

  const TvSeriesListScreen({
    super.key,
    this.seriesItem,
    this.initialSeasonIndex = 0,
    this.onReturnToSidebar,
  });

  @override
  State<TvSeriesListScreen> createState() => _TvSeriesListScreenState();
}

class _TvSeriesListScreenState extends State<TvSeriesListScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _playFocusNode = FocusNode(debugLabel: 'Series hero play');
  final FocusNode _detailsFocusNode = FocusNode(debugLabel: 'Series hero details');
  final Map<String, FocusNode> _cardFocusNodes = {};
  final Map<String, ScrollController> _rowControllers = {};
  final Map<String, GlobalKey> _rowKeys = {};
  late final AnimationController _entryController;
  Timer? _heroDebounce;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _heroItem;
  String _heroType = 'series';

  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularSeries = [];
  List<Map<String, dynamic>> topRatedSeries = [];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 330),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigation = context.read<TvNavigationProvider>();
      navigation.registerScrollController(3, _scrollController);
      _scrollController.addListener(_saveScrollOffset);
    });
    _loadContent();
  }

  void _saveScrollOffset() {
    if (mounted) {
      context.read<TvNavigationProvider>().saveScrollOffset(
        3,
        _scrollController.offset,
      );
    }
  }

  @override
  void dispose() {
    _heroDebounce?.cancel();
    _scrollController.removeListener(_saveScrollOffset);
    _scrollController.dispose();
    _playFocusNode.dispose();
    _detailsFocusNode.dispose();
    for (final node in _cardFocusNodes.values) {
      node.dispose();
    }
    for (final controller in _rowControllers.values) {
      controller.dispose();
    }
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        TmdbApiService.fetchTrendingSeries(),
        TmdbApiService.fetchPopularSeries(),
        TmdbApiService.fetchTopRatedSeries(),
      ]);
      if (!mounted) return;
      setState(() {
        trendingSeries = results[0];
        popularSeries = results[1];
        topRatedSeries = results[2];
        _heroItem ??= trendingSeries.isNotEmpty ? trendingSeries.first : null;
        _errorMessage = null;
        _isLoading = false;
      });
      _entryController.forward(from: 0);
      _restoreInitialFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load content: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DarkModeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _errorMessage != null
            ? _buildErrorWidget()
            : _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entryController,
                  curve: Curves.easeOut,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .025),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _entryController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: _buildContent(),
                ),
              ),
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = constraints.maxHeight * .62;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: heroHeight,
              child: _buildHero(),
            ),
            Positioned(
              top: heroHeight - 4,
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: RefreshIndicator(
                  onRefresh: _loadContent,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (trendingSeries.isNotEmpty)
                        _buildContentRow(
                          'Trending TV Shows',
                          trendingSeries.take(15).toList(),
                          contentType: 'series',
                        ),
                      if (popularSeries.isNotEmpty)
                        _buildContentRow(
                          'Popular TV Shows',
                          popularSeries.take(15).toList(),
                          contentType: 'series',
                        ),
                      if (topRatedSeries.isNotEmpty)
                        _buildContentRow(
                          'Top Rated TV Shows',
                          topRatedSeries.take(15).toList(),
                          contentType: 'series',
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 56)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHero() {
    final item = _heroItem ?? trendingSeries.firstOrNull;
    if (item == null) return const SizedBox.shrink();
    final id = '${item['id']}:$_heroType';
    final title = item['name'] ?? 'Unknown';
    final date = item['first_air_date'];
    final rating = (item['vote_average'] as num?)?.toDouble() ?? 0;
    final genres = (item['genre_ids'] as List?)
        ?.take(3)
        .map((genre) {
          return _getGenreName((genre as num).toInt());
        })
        .join('  •  ');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(.015, 0),
            end: Offset.zero,
          ).animate(animation),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.025, end: 1).animate(animation),
            child: child,
          ),
        ),
      ),
      child: Stack(
        key: ValueKey(id),
        fit: StackFit.expand,
        children: [
          Image.network(
            TmdbApiService.getBackdropUrl(item['backdrop_path'] ?? ''),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => Container(color: Colors.grey[900]),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black, Color(0xD9000000), Colors.transparent],
                stops: [0, .35, .78],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFF080808), Colors.transparent],
                stops: [0, .58],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 32, 48, 56),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      [
                        if (rating > 0) '★ ${rating.toStringAsFixed(1)}',
                        if (date is String && date.length >= 4)
                          date.substring(0, 4),
                        if (genres?.isNotEmpty == true) genres!,
                      ].join('   '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['overview'] ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD8D8D8),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _HeroButton(
                          focusNode: _playFocusNode,
                          icon: Icons.play_arrow_rounded,
                          label: 'Play',
                          primary: true,
                          onPressed: () => _play(item, 'series'),
                          onKeyEvent: (_, event) => _onHeroKey(0, event),
                        ),
                        const SizedBox(width: 12),
                        _HeroButton(
                          focusNode: _detailsFocusNode,
                          icon: Icons.info_outline_rounded,
                          label: 'Details',
                          onPressed: () => _openDetails(item, 'series'),
                          onKeyEvent: (_, event) => _onHeroKey(1, event),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildContentRow(
    String title,
    List<Map<String, dynamic>> items, {
    String contentType = 'series',
  }) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final rowId = 'series:$title';
    final rowController = _rowControllers.putIfAbsent(
      rowId,
      () => ScrollController(),
    );
    final rowKey = _rowKeys.putIfAbsent(rowId, GlobalKey.new);
    return SliverToBoxAdapter(
      child: Padding(
        key: rowKey,
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.builder(
                controller: rowController,
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 4,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final posterUrl = TmdbApiService.getPosterUrl(
                    item['poster_path'] ?? '',
                  );
                  final itemTitle = item['name'] ?? 'Unknown';
                  final rating = (item['vote_average'] as num?)?.toDouble();
                  final year =
                      (item['first_air_date'] as String?)?.isNotEmpty == true &&
                          (item['first_air_date'] as String).length >= 4
                      ? int.tryParse(
                          (item['first_air_date'] as String).substring(0, 4),
                        )
                      : null;
                  final node = _cardFocusNodes.putIfAbsent(
                    '$rowId:$index',
                    () => FocusNode(debugLabel: '$rowId card $index'),
                  );

                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: TvContentCard(
                      focusNode: node,
                      posterUrl: posterUrl,
                      title: itemTitle,
                      year: year,
                      rating: rating,
                      progress: null,
                      width: 130,
                      height: 190,
                      contentType: ContentType.series,
                      onTap: () => _openSeries(item),
                      onSelect: () => _openSeries(item),
                      onFocusChanged: (focused) {
                        if (!focused || !mounted) return;
                        final navigation = context.read<TvNavigationProvider>();
                        navigation.saveRowFocusedIndex(rowId, index);
                        navigation.saveActiveRowId(3, rowId);
                        _revealCard(rowId, index);
                        _queueHero(item, 'series');
                      },
                      onKeyEvent: (_, event) =>
                          _onCardKey(rowId, index, items.length, event),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _visibleRows => [
    if (trendingSeries.isNotEmpty) 'series:Trending TV Shows',
    if (popularSeries.isNotEmpty) 'series:Popular TV Shows',
    if (topRatedSeries.isNotEmpty) 'series:Top Rated TV Shows',
  ];

  int _rowLength(String rowId) {
    switch (rowId) {
      case 'series:Trending TV Shows':
        return trendingSeries.take(15).length;
      case 'series:Popular TV Shows':
        return popularSeries.take(15).length;
      case 'series:Top Rated TV Shows':
        return topRatedSeries.take(15).length;
    }
    return 0;
  }

  void _restoreInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigation = context.read<TvNavigationProvider>();
        final offset = navigation.getScrollOffset(3);
        if (_scrollController.hasClients && offset > 0) {
          _scrollController.jumpTo(
            offset.clamp(0, _scrollController.position.maxScrollExtent),
          );
        }
        final rowId = navigation.getActiveRowId(3);
        final index = rowId == null
            ? null
            : navigation.getRowFocusedIndex(rowId);
        final cardNode = index == null
            ? null
            : _cardFocusNodes['$rowId:$index'];
        (cardNode ?? _playFocusNode).requestFocus();
      });
    });
  }

  KeyEventResult _onHeroKey(int action, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (action == 0) {
        widget.onReturnToSidebar?.call();
      } else {
        _playFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (action == 0) _detailsFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _visibleRows.isNotEmpty) {
      final rowId = _visibleRows.first;
      _focusCard(
        rowId,
        context.read<TvNavigationProvider>().getRowFocusedIndex(rowId),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  KeyEventResult _onCardKey(
    String rowId,
    int index,
    int itemCount,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) {
        _focusCard(rowId, index - 1);
      } else {
        widget.onReturnToSidebar?.call();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index + 1 < itemCount) _focusCard(rowId, index + 1);
      return KeyEventResult.handled;
    }
    final rows = _visibleRows;
    final rowIndex = rows.indexOf(rowId);
    if (key == LogicalKeyboardKey.arrowUp) {
      if (rowIndex <= 0) {
        _playFocusNode.requestFocus();
      } else {
        final target = rows[rowIndex - 1];
        _focusCard(target, index.clamp(0, _rowLength(target) - 1));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (rowIndex >= 0 && rowIndex + 1 < rows.length) {
        final target = rows[rowIndex + 1];
        _focusCard(target, index.clamp(0, _rowLength(target) - 1));
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusCard(String rowId, int requestedIndex) {
    final length = _rowLength(rowId);
    if (length == 0) return;
    final index = requestedIndex.clamp(0, length - 1);
    context.read<TvNavigationProvider>()
      ..saveActiveRowId(3, rowId)
      ..saveRowFocusedIndex(rowId, index);
    _revealCard(rowId, index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cardFocusNodes['$rowId:$index']?.requestFocus();
    });
  }

  void _revealCard(String rowId, int index) {
    final horizontal = _rowControllers[rowId];
    if (horizontal?.hasClients == true) {
      final target = (index * 160.0 - 48).clamp(
        0.0,
        horizontal!.position.maxScrollExtent,
      );
      horizontal.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
    final rowContext = _rowKeys[rowId]?.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        alignment: 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _queueHero(Map<String, dynamic> item, String type) {
    _heroDebounce?.cancel();
    _heroDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _heroItem = item;
        _heroType = type;
      });
    });
  }

  Future<void> _openSeries(Map<String, dynamic> series) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TvSeriesScreen(seriesItem: Movie.fromJson(series)),
      ),
    );
    if (mounted) _restoreInitialFocus();
  }

  String _getGenreName(int id) =>
      const {
        28: 'Action',
        12: 'Adventure',
        16: 'Animation',
        35: 'Comedy',
        80: 'Crime',
        99: 'Documentary',
        18: 'Drama',
        10751: 'Family',
        14: 'Fantasy',
        36: 'History',
        27: 'Horror',
        10402: 'Music',
        9648: 'Mystery',
        10749: 'Romance',
        878: 'Sci-Fi',
        10770: 'TV Movie',
        53: 'Thriller',
        10752: 'War',
        37: 'Western',
      }[id] ??
      'Entertainment';

  Future<void> _openDetails(Map<String, dynamic> item, String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TvSeriesScreen(seriesItem: Movie.fromJson(item)),
      ),
    );
    if (mounted) _restoreInitialFocus();
  }

  Future<void> _play(Map<String, dynamic> item, String type) async {
    final media = Movie.fromJson(item);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TvVideoPlayerScreen(
          title: media.title,
          tmdbId: media.id,
          isMovie: false,
          season: 1,
          episode: 1,
        ),
      ),
    );
    if (mounted) _restoreInitialFocus();
  }

  Widget _buildErrorWidget() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadContent, child: const Text('Retry')),
      ],
    ),
  );
}

class _HeroButton extends StatefulWidget {
  const _HeroButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.primary = false,
    this.onKeyEvent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool primary;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  State<_HeroButton> createState() => _HeroButtonState();
}

class _HeroButtonState extends State<_HeroButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final foreground = _focused || widget.primary ? Colors.black : Colors.white;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        final result = widget.onKeyEvent?.call(node, event);
        if (result != null && result != KeyEventResult.ignored) return result;
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _focused ? 1.02 : 1,
          duration: const Duration(milliseconds: 160),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: _focused || widget.primary
                  ? Colors.white
                  : Colors.black.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _focused ? Colors.white : Colors.white38,
                width: _focused ? 2 : 1,
              ),
              boxShadow: _focused
                  ? const [BoxShadow(color: Colors.white24, blurRadius: 14)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: foreground, size: 22),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
