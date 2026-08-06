import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/movie.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/tv_image_cache_util.dart';
import '../widgets/tv_content_card.dart';
import '../widgets/tv_dark_mode_polish.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';
import 'tv_video_player_screen.dart';

class TvHomeScreen extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;
  final GlobalKey<NavigatorState>? navigatorKey;

  const TvHomeScreen({super.key, this.onReturnToSidebar, this.navigatorKey});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _playFocusNode = FocusNode(debugLabel: 'Home hero play');
  final FocusNode _detailsFocusNode = FocusNode(
    debugLabel: 'Home hero details',
  );
  final Map<String, FocusNode> _cardFocusNodes = {};
  final Map<String, ScrollController> _rowControllers = {};
  final Map<String, GlobalKey> _rowKeys = {};
  late final AnimationController _entryController;
  Timer? _heroDebounce;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _heroItem;
  String _heroType = 'movie';
  bool _heroResume = false;

  List<Map<String, dynamic>> trendingMovies = [];
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularMovies = [];
  List<Map<String, dynamic>> topRatedMovies = [];
  List<Map<String, dynamic>> continueWatching = [];

  @override
  void initState() {
    super.initState();
    CloudSyncService.historyRevision.addListener(_onSyncedHistory);
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 330),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigation = context.read<TvNavigationProvider>();
      navigation.registerScrollController(0, _scrollController);
      _scrollController.addListener(_saveScrollOffset);
    });
    _loadContent();
  }

  void _onSyncedHistory() {
    if (mounted) _refreshContinueWatching();
  }

  void _saveScrollOffset() {
    if (mounted) {
      context.read<TvNavigationProvider>().saveScrollOffset(
        0,
        _scrollController.offset,
      );
    }
  }

  @override
  void dispose() {
    CloudSyncService.historyRevision.removeListener(_onSyncedHistory);
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
      final syncFuture = CloudSyncService.pullToDevice();
      final results = await Future.wait([
        TmdbApiService.fetchTrendingMovies(),
        TmdbApiService.fetchTrendingSeries(),
        TmdbApiService.fetchPopularMovies(),
        TmdbApiService.fetchTopRatedMovies(),
        syncFuture.then((_) => WatchHistoryService.getContinueWatching()),
      ]);
      if (!mounted) return;
      setState(() {
        trendingMovies = results[0];
        trendingSeries = results[1];
        popularMovies = results[2];
        topRatedMovies = results[3];
        continueWatching = results[4].take(10).toList();
        _heroItem ??= trendingMovies.isNotEmpty ? trendingMovies.first : null;
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

  void _restoreInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigation = context.read<TvNavigationProvider>();
        final offset = navigation.getScrollOffset(0);
        if (_scrollController.hasClients && offset > 0) {
          _scrollController.jumpTo(
            offset.clamp(0, _scrollController.position.maxScrollExtent),
          );
        }
        final savedRowId = navigation.getActiveRowId(0);
        final rowId = savedRowId != null && _visibleRows.contains(savedRowId)
            ? savedRowId
            : null;
        final savedIndex = rowId == null
            ? null
            : navigation.getRowFocusedIndex(rowId);
        final index = rowId == null || savedIndex == null
            ? null
            : savedIndex.clamp(0, _rowLength(rowId) - 1);
        if (rowId != null && index != null) {
          _revealCard(rowId, index);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final cardNode = index == null
              ? null
              : _cardFocusNodes['$rowId:$index'];
          (cardNode ?? _playFocusNode).requestFocus();
        });
      });
    });
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
                  position:
                      Tween<Offset>(
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
                      if (continueWatching.isNotEmpty)
                        _buildContentRow(
                          'Continue Watching',
                          continueWatching,
                          showProgress: true,
                          resumeOnSelect: true,
                        ),
                      _buildContentRow(
                        'Trending Movies',
                        trendingMovies.take(15).toList(),
                      ),
                      _buildContentRow(
                        'Trending Series',
                        trendingSeries.take(15).toList(),
                        contentType: 'series',
                      ),
                      _buildContentRow(
                        'Popular Movies',
                        popularMovies.take(15).toList(),
                      ),
                      _buildContentRow(
                        'Top Rated',
                        topRatedMovies.take(15).toList(),
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
    final item = _heroItem;
    if (item == null) return const SizedBox.shrink();
    final id = '${item['id']}:$_heroType';
    final isResume = _heroResume;
    final isSeriesHero = _heroType == 'series';
    final title = isResume
        ? (item['seriesTitle']?.toString() ??
              item['title']?.toString() ??
              item['name']?.toString() ??
              'Unknown')
        : (item['title'] ?? item['name'] ?? 'Unknown');
    final date =
        item[_heroType == 'series' ? 'first_air_date' : 'release_date'];
    final rating = (item['vote_average'] as num?)?.toDouble() ?? 0;
    final genres = (item['genre_ids'] as List?)
        ?.take(3)
        .map((genre) {
          return _getGenreName((genre as num).toInt());
        })
        .join('  •  ');
    final heroBackdropUrl = isResume
        ? (item['posterUrl']?.toString().isNotEmpty == true
              ? item['posterUrl'].toString()
              : '')
        : TmdbApiService.getBackdropUrl(item['backdrop_path'] ?? '');
    final episodeLabel = isResume && isSeriesHero
        ? 'S${item['season'] ?? 1}E${item['episode'] ?? 1}'
        : null;
    final episodeName = isResume ? item['episodeName']?.toString() ?? '' : '';
    final overview = isResume
        ? (isSeriesHero
              ? [
                  if (episodeLabel != null) 'Episode $episodeLabel',
                  if (episodeName.isNotEmpty) episodeName,
                ].join(' • ')
              : item['title']?.toString() ?? '')
        : (item['overview'] ?? '');
    final heroMetadata = <String>[
      if (isResume) 'Resume',
      if (rating > 0) '★ ${rating.toStringAsFixed(1)}',
      if (date is String && date.length >= 4) date.substring(0, 4),
      if (genres?.isNotEmpty == true) genres!,
    ].join('   ');
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
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (_visibleRows.isNotEmpty) {
              final rowId = _visibleRows.first;
              _focusCard(
                rowId,
                context.read<TvNavigationProvider>().getRowFocusedIndex(rowId),
              );
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          key: ValueKey(id),
          fit: StackFit.expand,
          children: [
            Image.network(
              heroBackdropUrl,
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
                        heroMetadata,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        overview,
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
                            label: isResume ? 'Resume' : 'Play',
                            primary: true,
                            onPressed: () => isResume
                                ? _resumePlayback(item, _heroType)
                                : _play(item, _heroType),
                            onKeyEvent: (_, event) => _onHeroKey(0, event),
                          ),
                          const SizedBox(width: 12),
                          _HeroButton(
                            focusNode: _detailsFocusNode,
                            icon: Icons.info_outline_rounded,
                            label: 'Details',
                            onPressed: () => _openDetails(item, _heroType),
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
      ),
    );
  }

  String _getPosterUrl(Map<String, dynamic> item) {
    final posterPath = item['poster_path']?.toString();
    if (posterPath != null && posterPath.isNotEmpty) {
      return TmdbApiService.getPosterUrl(posterPath);
    }
    return item['posterUrl']?.toString() ?? '';
  }

  Map<String, dynamic> _normalizeItem(Map<String, dynamic> item) {
    final normalized = Map<String, dynamic>.from(item);
    if (normalized['tmdbId'] != null && normalized['id'] == null) {
      normalized['id'] = normalized['tmdbId'];
    }
    if (normalized['posterUrl'] != null && normalized['poster_path'] == null) {
      final posterUrl = normalized['posterUrl'].toString();
      final baseUrl = 'https://image.tmdb.org/t/p/w500';
      if (posterUrl.startsWith(baseUrl)) {
        normalized['poster_path'] = posterUrl.substring(baseUrl.length);
      } else {
        normalized['poster_path'] = posterUrl;
      }
    }
    normalized['backdrop_path'] ??= '';
    normalized['overview'] ??= 'No description available.';
    normalized['vote_average'] ??= 0.0;
    normalized['release_date'] ??= '';
    normalized['first_air_date'] ??= '';
    normalized['genre_ids'] ??= [];
    normalized['trailerUrl'] ??= '';
    return normalized;
  }

  SliverToBoxAdapter _buildContentRow(
    String title,
    List<Map<String, dynamic>> items, {
    String contentType = 'movie',
    bool showProgress = false,
    bool resumeOnSelect = false,
  }) {
    final rowId = 'home:$title';
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
              height: showProgress ? 260 : 220,
              child: ListView.builder(
                controller: rowController,
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 4,
                ),
                itemCount: items.length,
                itemBuilder: (itemContext, index) {
                  final item = items[index];
                  final type = _itemType(item, contentType);
                  final isSeries = type == 'series';
                  final date =
                      item[isSeries ? 'first_air_date' : 'release_date'];
                  final node = _cardFocusNodes.putIfAbsent(
                    '$rowId:$index',
                    () => FocusNode(debugLabel: '$rowId card $index'),
                  );
                  final posterUrl = resumeOnSelect
                      ? _resumePosterUrl(item, isSeries)
                      : _getPosterUrl(item);
                  final overview = item['overview']?.toString() ?? '';
                  final episodeName = isSeries
                      ? item['episodeName']?.toString() ?? ''
                      : '';
                  final season = item['season'] ?? 1;
                  final episode = item['episode'] ?? 1;
                  final cardTitle = isSeries
                      ? (item['seriesTitle']?.toString() ??
                            item['title']?.toString() ??
                            item['name']?.toString() ??
                            'Unknown')
                      : (item['title']?.toString() ??
                            item['name']?.toString() ??
                            'Unknown');

                  if (showProgress) {
                    return Focus(
                      focusNode: node,
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter)) {
                          _resumePlayback(item, type);
                          return KeyEventResult.handled;
                        }
                        return _onCardKey(rowId, index, items.length, event);
                      },
                      onFocusChange: (focused) {
                        if (!focused || !mounted) return;
                        setState(() {});
                        final navigation = context.read<TvNavigationProvider>();
                        navigation.saveRowFocusedIndex(rowId, index);
                        navigation.saveActiveRowId(0, rowId);
                        _revealCard(rowId, index);
                        _queueHero(item, type, resume: true);
                      },
                      child: GestureDetector(
                        onTap: () => _resumePlayback(item, type),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: AnimatedScale(
                            scale: node.hasFocus ? 1.02 : 1,
                            duration: const Duration(milliseconds: 180),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: node.hasFocus
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: SizedBox(
                                width: 220,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: posterUrl.isNotEmpty
                                              ? Image(
                                                  image:
                                                      TvImageCacheUtil.getCachedImage(
                                                        posterUrl,
                                                        cacheType:
                                                            ImageCacheType
                                                                .poster,
                                                      ),
                                                  width: 220,
                                                  height: 160,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      Container(
                                                        width: 220,
                                                        height: 160,
                                                        color: Colors.grey[900],
                                                        child: const Icon(
                                                          Icons.movie,
                                                          color: Colors.grey,
                                                          size: 48,
                                                        ),
                                                      ),
                                                )
                                              : Container(
                                                  width: 220,
                                                  height: 160,
                                                  color: Colors.grey[900],
                                                  child: const Icon(
                                                    Icons.movie,
                                                    color: Colors.grey,
                                                    size: 48,
                                                  ),
                                                ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[700],
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    bottomLeft: Radius.circular(
                                                      8,
                                                    ),
                                                    bottomRight:
                                                        Radius.circular(8),
                                                  ),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor:
                                                  _historyProgress(
                                                    item,
                                                  )?.clamp(0.0, 1.0) ??
                                                  0.0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFE50914,
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        bottomLeft:
                                                            Radius.circular(8),
                                                        bottomRight:
                                                            Radius.circular(8),
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isSeries)
                                          Positioned(
                                            top: 6,
                                            left: 6,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.7,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'S${season}E$episode',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      cardTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isSeries && episodeName.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        episodeName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    if (overview.isNotEmpty &&
                                        overview != 'No description available.')
                                      Text(
                                        overview,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 10,
                                          height: 1.3,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: TvContentCard(
                      focusNode: node,
                      posterUrl: posterUrl,
                      title: cardTitle,
                      year: date is String && date.length >= 4
                          ? int.tryParse(date.substring(0, 4))
                          : null,
                      rating: (item['vote_average'] as num?)?.toDouble(),
                      progress: showProgress ? _historyProgress(item) : null,
                      width: 130,
                      height: 190,
                      contentType: isSeries
                          ? ContentType.series
                          : ContentType.movie,
                      onTap: () => resumeOnSelect
                          ? _resumePlayback(item, type)
                          : _openDetails(item, type),
                      onSelect: () => resumeOnSelect
                          ? _resumePlayback(item, type)
                          : _openDetails(item, type),
                      onFocusChanged: (focused) {
                        if (!focused || !mounted) return;
                        final navigation = context.read<TvNavigationProvider>();
                        navigation.saveRowFocusedIndex(rowId, index);
                        navigation.saveActiveRowId(0, rowId);
                        _revealCard(rowId, index);
                        _queueHero(item, type, resume: resumeOnSelect);
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
    if (continueWatching.isNotEmpty) 'home:Continue Watching',
    if (trendingMovies.isNotEmpty) 'home:Trending Movies',
    if (trendingSeries.isNotEmpty) 'home:Trending Series',
    if (popularMovies.isNotEmpty) 'home:Popular Movies',
    if (topRatedMovies.isNotEmpty) 'home:Top Rated',
  ];

  int _rowLength(String rowId) {
    switch (rowId) {
      case 'home:Continue Watching':
        return continueWatching.length;
      case 'home:Trending Movies':
        return trendingMovies.take(15).length;
      case 'home:Trending Series':
        return trendingSeries.take(15).length;
      case 'home:Popular Movies':
        return popularMovies.take(15).length;
      case 'home:Top Rated':
        return topRatedMovies.take(15).length;
    }
    return 0;
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
      ..saveActiveRowId(0, rowId)
      ..saveRowFocusedIndex(rowId, index);
    _revealCard(rowId, index);
    _cardFocusNodes['$rowId:$index']?.requestFocus();
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

  String _itemType(Map<String, dynamic> item, String fallback) {
    final stored = item['mediaType'] ?? item['media_type'];
    if (stored == 'tv' || stored == 'series') return 'series';
    if (stored == 'movie') return 'movie';
    if (item['isMovie'] == false) return 'series';
    return fallback;
  }

  double? _historyProgress(Map<String, dynamic> item) {
    final rawProgress = item['progress'] ?? item['percentage'];
    if (rawProgress is num) {
      final value = rawProgress.toDouble();
      return (value > 1 ? value / 100 : value).clamp(0, 1);
    }
    final position = item['position'] ?? item['watchPosition'];
    final duration = item['duration'] ?? item['totalDuration'];
    if (position is num && duration is num && duration > 0) {
      return (position / duration).clamp(0, 1).toDouble();
    }
    return null;
  }

  String _resumePosterUrl(Map<String, dynamic> item, bool isSeries) {
    if (isSeries) {
      final still = item['posterUrl']?.toString() ?? '';
      if (still.isNotEmpty && still.startsWith('https://image.tmdb.org')) {
        return still;
      }
    }
    return _getPosterUrl(item);
  }

  Future<void> _resumePlayback(Map<String, dynamic> item, String type) async {
    final normalized = _normalizeItem(item);
    final resolvedType = _itemType(normalized, type);
    final isMovie = resolvedType != 'series';
    final season = (item['season'] as num?)?.toInt() ?? 1;
    final episode = (item['episode'] as num?)?.toInt() ?? 1;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TvVideoPlayerScreen(
          title: isMovie
              ? (item['title']?.toString() ??
                    item['seriesTitle']?.toString() ??
                    item['name']?.toString() ??
                    '')
              : (item['seriesTitle']?.toString() ??
                    item['title']?.toString() ??
                    ''),
          tmdbId: isMovie
              ? (item['tmdbId']?.toString() ?? item['id']?.toString() ?? '0')
              : (item['tmdbId']?.toString() ?? item['id']?.toString() ?? '0'),
          isMovie: isMovie,
          season: isMovie ? 0 : season,
          episode: isMovie ? 0 : episode,
        ),
      ),
    );
    await _refreshContinueWatching();
    if (mounted) _restoreInitialFocus();
  }

  void _queueHero(
    Map<String, dynamic> item,
    String type, {
    bool resume = false,
  }) {
    _heroDebounce?.cancel();
    _heroDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _heroItem = item;
        _heroType = type;
        _heroResume = resume;
      });
    });
  }

  Future<void> _openDetails(Map<String, dynamic> item, String type) async {
    final normalized = _normalizeItem(item);
    final resolvedType = _itemType(normalized, type);
    if (resolvedType == 'series') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TvSeriesScreen(seriesItem: Movie.fromJson(normalized)),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TvDetailsScreen(
            item: Movie.fromJson(normalized),
            mediaType: 'movie',
          ),
        ),
      );
    }
    await _refreshContinueWatching();
    if (mounted) _restoreInitialFocus();
  }

  Future<void> _play(Map<String, dynamic> item, String type) async {
    final normalized = _normalizeItem(item);
    final resolvedType = _itemType(normalized, type);
    final media = Movie.fromJson(normalized);
    final isMovie = resolvedType != 'series';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TvVideoPlayerScreen(
          title: media.title,
          tmdbId: media.id,
          isMovie: isMovie,
          season: isMovie ? 0 : 1,
          episode: isMovie ? 0 : 1,
        ),
      ),
    );
    await _refreshContinueWatching();
    if (mounted) _restoreInitialFocus();
  }

  Future<void> _refreshContinueWatching() async {
    final history = await WatchHistoryService.getContinueWatching();
    if (!mounted) return;
    final next = history.take(10).toList();
    setState(() {
      continueWatching = next;
      final heroId =
          _heroItem?['tmdbId']?.toString() ?? _heroItem?['id']?.toString();
      final heroStillResumable = next.any(
        (item) => item['tmdbId']?.toString() == heroId,
      );
      if (_heroResume && !heroStillResumable) {
        _heroItem = trendingMovies.firstOrNull;
        _heroType = 'movie';
        _heroResume = false;
      }
    });
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
