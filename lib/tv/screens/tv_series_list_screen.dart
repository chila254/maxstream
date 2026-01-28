import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:maxstream/tv/screens/tv_video_player_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../../models/movie.dart';
import '../../models/series.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/logger_service.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/index.dart';
import '../../widgets/custom_loading_widget.dart';
import '../widgets/tv_enhanced_hero_banner.dart';
import '../widgets/tv_content_card.dart';
import 'tv_series_screen.dart';

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

class _TvSeriesListScreenState extends State<TvSeriesListScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularSeries = [];
  List<Map<String, dynamic>> topRatedSeries = [];

  // For series-specific details view
  List<Season> seasons = [];
  int selectedSeasonIndex = 0;
  List<Episode> currentEpisodes = [];
  bool isLoadingEpisodes = false;

  // Auto-scroll banner
  late PageController _heroBannerController;
  Timer? _heroBannerTimer;
  int _heroBannerPage = 0;
  late ScrollController _scrollController;

  // Focus tracking
  final Map<String, int> _sectionItemIndices = {
    'trending_series': 0,
    'popular_series': 0,
    'top_rated_series': 0,
  };

  @override
  void initState() {
    super.initState();
    _heroBannerController = PageController();
    _scrollController = ScrollController();

    // Register scroll controller with navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navProvider = context.read<TvNavigationProvider>();
      navProvider.registerScrollController(3, _scrollController);

      // Restore scroll position if available
      final savedOffset = navProvider.getScrollOffset(3);
      if (savedOffset > 0 && _scrollController.hasClients) {
        _scrollController.jumpTo(savedOffset);
      }

      // Add scroll listener to save scroll offset
      _scrollController.addListener(() {
        navProvider.saveScrollOffset(3, _scrollController.offset);
      });
    });

    if (widget.seriesItem != null) {
      _loadSeriesDetails();
    } else {
      _loadContent();
    }
  }

  @override
  void dispose() {
    _heroBannerController.dispose();
    _heroBannerTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startHeroBannerTimer() {
    _heroBannerTimer?.cancel();
    _heroBannerTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (trendingSeries.isNotEmpty) {
        _heroBannerPage = (_heroBannerPage + 1) % trendingSeries.length;
        if (_heroBannerController.hasClients) {
          _heroBannerController.animateToPage(
            _heroBannerPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Future<void> _loadSeriesDetails() async {
    setState(() => isLoading = true);

    try {
      final details = await TmdbApiService.getSeriesDetails(
        int.parse(widget.seriesItem!.id),
      );
      if (details != null && mounted) {
        setState(() {
          seasons = (details['seasons'] as List)
              .map((season) => Season.fromJson(season))
              .where((season) => season.seasonNumber > 0)
              .toList();
          selectedSeasonIndex = widget.initialSeasonIndex;
        });

        if (seasons.isNotEmpty) {
          _loadSeasonEpisodes(seasons[selectedSeasonIndex].seasonNumber);
        }
      }
    } catch (e) {
      LoggerService.error('Error loading series details: $e', e);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSeasonEpisodes(int seasonNumber) async {
    setState(() {
      isLoadingEpisodes = true;
    });

    try {
      final episodesData = await TmdbApiService.getSeasonEpisodes(
        int.parse(widget.seriesItem!.id),
        seasonNumber,
      );

      final episodes = episodesData.map((ep) => Episode.fromJson(ep)).toList();

      if (mounted) {
        setState(() {
          currentEpisodes = episodes;
          isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading episodes: $e', e);
      if (mounted) {
        setState(() {
          isLoadingEpisodes = false;
        });
      }
    }
  }

  Future<void> _loadContent() async {
    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        TmdbApiService.fetchTrendingSeries(),
        TmdbApiService.fetchPopularSeries(),
        TmdbApiService.fetchTopRatedSeries(),
      ]);

      setState(() {
        trendingSeries = results[0];
        popularSeries = results[1];
        topRatedSeries = results[2];
        // Set initial focus to first section (trending series)
        _sectionItemIndices['trending_series'] = 0;
      });

      // Start auto-scrolling hero banner
      if (trendingSeries.isNotEmpty) {
        _startHeroBannerTimer();
      }
    } catch (e) {
      LoggerService.error('Error loading series content: $e', e);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If seriesItem is provided, show series details with seasons
    if (widget.seriesItem != null) {
      return _buildSeriesDetailsView();
    }

    // Otherwise, show the browse view
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        onRefresh: _loadContent,
        child: Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
              context.read<TvNavigationProvider>().setFocusOnSidebar(true);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          autofocus: true,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(),
              if (isLoading)
                SliverToBoxAdapter(child: _buildLoadingIndicator())
              else ...[
                if (trendingSeries.isNotEmpty) _buildHeroBannerSection(),
                _buildSection('Trending TV Shows', trendingSeries),
                _buildSection('Popular TV Shows', popularSeries),
                _buildSection('Top Rated TV Shows', topRatedSeries),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: TvUtils.responsivePadding(48, context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesDetailsView() {
    final padding = TvUtils.responsivePadding(24, context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          widget.seriesItem!.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: TvUtils.responsiveFontSize(24, context),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seasons',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: TvUtils.responsiveFontSize(
                              22,
                              context,
                              maxSize: 28,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(seasons.length, (index) {
                            final season = seasons[index];
                            final isSelected = index == selectedSeasonIndex;
                            return FilterChip(
                              label: Text(
                                season.name,
                                style: TextStyle(
                                  fontSize: TvUtils.responsiveFontSize(
                                    16,
                                    context,
                                  ),
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    selectedSeasonIndex = index;
                                  });
                                  _loadSeasonEpisodes(season.seasonNumber);
                                }
                              },
                              selectedColor: Colors.red,
                              backgroundColor: const Color(0xFF2A2A2A),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey,
                                fontSize: TvUtils.responsiveFontSize(
                                  16,
                                  context,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isLoadingEpisodes)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: const CircularProgressIndicator(color: Colors.red),
                    ),
                  )
                else if (currentEpisodes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Episodes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: TvUtils.responsiveFontSize(
                                22,
                                context,
                                maxSize: 28,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...currentEpisodes.map((episode) {
                            return _buildEpisodeCard(episode);
                          }),
                        ],
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: const Text(
                        'No episodes available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEpisodeCard(Episode episode) {
    final padding = TvUtils.responsivePadding(16, context);

    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                color: const Color(0xFF2A2A2A),
              ),
              child: episode.stillPath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      child: Image.network(
                        'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white54,
                      size: 60,
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${episode.episodeNumber}. ',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: TvUtils.responsiveFontSize(18, context),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            episode.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: TvUtils.responsiveFontSize(18, context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (episode.overview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        episode.overview,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: TvUtils.responsiveFontSize(14, context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.play_arrow,
                color: Colors.red,
                size: TvUtils.responsiveFontSize(32, context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: const Color(0xFF1A1A1A),
      title: Row(
        children: [
          // Empty - removed TV Series title to make room for hero banner
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: ListView(
        padding: EdgeInsets.all(TvUtils.responsivePadding(32, context)),
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(32, context)),
          ...List.generate(
            3,
            (index) => Column(
              children: [
                Container(
                  height: 24,
                  width: 200,
                  color: Colors.grey[800],
                  margin: EdgeInsets.only(
                    bottom: TvUtils.responsivePadding(16, context),
                  ),
                ),
                Container(
                  height: 250,
                  color: Colors.grey[800],
                  margin: EdgeInsets.only(
                    bottom: TvUtils.responsivePadding(32, context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBannerSection() {
    if (trendingSeries.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        children: [
          SizedBox(
            height: 606,
            child: PageView.builder(
              controller: _heroBannerController,
              onPageChanged: (page) {
                setState(() => _heroBannerPage = page);
              },
              itemCount: trendingSeries.length,
              itemBuilder: (context, index) {
                final series = trendingSeries[index];
                final backdropUrl = TmdbApiService.getBackdropUrl(
                  series['backdrop_path'] ?? '',
                );
                final title = series['name'] ?? 'Unknown';
                final rating =
                    (series['vote_average'] as num?)?.toDouble() ?? 0.0;
                final overview = series['overview'] ?? '';

                return TvEnhancedHeroBanner(
                  backdropUrl: backdropUrl,
                  title: title,
                  description: overview,
                  rating: rating > 0 ? rating : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TvSeriesScreen(seriesItem: Movie.fromJson(series)),
                      ),
                    );
                  },
                  onWatchNow: () => _playSeries(series),
                  onDetails: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TvSeriesScreen(seriesItem: Movie.fromJson(series)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Enhanced Page indicators
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: TvUtils.responsivePadding(16, context),
            ),
            child: TvEnhancedPageIndicator(
              itemCount: trendingSeries.length,
              currentIndex: _heroBannerPage,
              animationDuration: const Duration(milliseconds: 300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(child: const SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: TvSpacing.largeGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TvSpacing.sectionPaddingH,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TvTypography.sectionTitle),
                  Focus(
                    onKey: (node, event) {
                      if (event.isKeyPressed(LogicalKeyboardKey.select)) {
                        _showFullList(title);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: GestureDetector(
                      onTap: () => _showFullList(title),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TvSpacing.lg,
                          vertical: TvSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('See More', style: TvTypography.buttonText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TvSpacing.sectionGap),
            SizedBox(
              height: 320,
              child: Focus(
                onKey: (node, event) {
                  if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
                    // Return to sidebar at leftmost
                    context.read<TvNavigationProvider>().setFocusOnSidebar(
                      true,
                    );
                    return KeyEventResult.handled;
                  } else if (event.isKeyPressed(
                    LogicalKeyboardKey.arrowRight,
                  )) {
                    node.nextFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                autofocus: false,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TvSpacing.sectionPaddingH,
                  ),
                  itemCount: items.take(10).length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _SeriesCarouselItemFocus(
                      index: index,
                      totalItems: items.take(10).length,
                      item: item,
                      onSelect: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TvSeriesScreen(
                              seriesItem: Movie.fromJson(item),
                            ),
                          ),
                        );
                      },
                      child: _buildSeriesCard(item),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullList(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TvSeriesFullListScreen(
          title: title,
          onReturnToSidebar: widget.onReturnToSidebar,
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Map<String, dynamic> item) {
    final posterUrl = TmdbApiService.getPosterUrl(item['poster_path'] ?? '');
    final title = item['name'] ?? 'Unknown';
    final rating = (item['vote_average'] as num?)?.toDouble();
    final firstAirDate = item['first_air_date'] as String?;
    final year = firstAirDate != null
        ? int.tryParse(firstAirDate.split('-')[0])
        : null;
    final numberOfSeasons = item['number_of_seasons'] as int?;
    final duration = numberOfSeasons != null
        ? '$numberOfSeasons Seasons'
        : null;

    return Container(
      margin: const EdgeInsets.only(right: TvSpacing.cardSpacing),
      child: TvContentCard(
        posterUrl: posterUrl,
        title: title,
        contentType: ContentType.series,
        rating: rating,
        year: year,
        duration: duration,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TvSeriesScreen(seriesItem: Movie.fromJson(item)),
            ),
          );
        },
        width: 180,
        height: 270,
      ),
    );
  }

  void _playSeries(Map<String, dynamic> series) {
    final seriesItem = Movie.fromJson(series);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvVideoPlayerScreen(
          title: seriesItem.title,
          tmdbId: seriesItem.id,
          isMovie: false,
          season: 1,
          episode: 1,
        ),
      ),
    );
  }

  // Genre mapping
}

/// Wrapper widget for series carousel items with focus handling
class _SeriesCarouselItemFocus extends StatefulWidget {
  final int index;
  final int totalItems;
  final Map<String, dynamic> item;
  final VoidCallback onSelect;
  final Widget child;

  const _SeriesCarouselItemFocus({
    required this.index,
    required this.totalItems,
    required this.item,
    required this.onSelect,
    required this.child,
  });

  @override
  State<_SeriesCarouselItemFocus> createState() =>
      _SeriesCarouselItemFocusState();
}

class _SeriesCarouselItemFocusState extends State<_SeriesCarouselItemFocus> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKey: (node, event) => _handleKeyEvent(event));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.select) {
      widget.onSelect();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (widget.index == 0) {
        // At leftmost - return to sidebar
        TvFocusManager.focusSidebar();
        context.read<TvNavigationProvider>().setFocusOnSidebar(true);
      } else {
        _focusNode.previousFocus();
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (widget.index < widget.totalItems - 1) {
        _focusNode.nextFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            border: Border.all(
              color: _isFocused ? const Color(0xFFE50914) : Colors.transparent,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _TvSeriesFullListScreen extends StatefulWidget {
  final String title;
  final VoidCallback? onReturnToSidebar;

  const _TvSeriesFullListScreen({required this.title, this.onReturnToSidebar});

  @override
  State<_TvSeriesFullListScreen> createState() =>
      _TvSeriesFullListScreenState();
}

class _TvSeriesFullListScreenState extends State<_TvSeriesFullListScreen> {
  List<Map<String, dynamic>> _allItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _loadInitialItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialItems() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> items = [];

      if (widget.title.contains('Trending')) {
        items = await TmdbApiService.fetchTrendingSeries(page: 1);
      } else if (widget.title.contains('Popular')) {
        items = await TmdbApiService.fetchPopularSeries(page: 1);
      } else if (widget.title.contains('Top Rated')) {
        items = await TmdbApiService.fetchTopRatedSeries(page: 1);
      }

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading items: $e', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        !_isLoading) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || _isLoading) return;

    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      List<Map<String, dynamic>> newItems = [];

      if (widget.title.contains('Trending')) {
        newItems = await TmdbApiService.fetchTrendingSeries(page: _currentPage);
      } else if (widget.title.contains('Popular')) {
        newItems = await TmdbApiService.fetchPopularSeries(page: _currentPage);
      } else if (widget.title.contains('Top Rated')) {
        newItems = await TmdbApiService.fetchTopRatedSeries(page: _currentPage);
      }

      if (newItems.isNotEmpty) {
        setState(() {
          _allItems.addAll(newItems);
        });
      }
    } catch (e) {
      LoggerService.error('Error loading more items: $e', e);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: TvUtils.responsiveFontSize(28, context, maxSize: 40),
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            size: TvUtils.responsiveFontSize(24, context, maxSize: 36),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CustomLoadingWidget(
                    size: 60,
                    color: Color(0xFFE50914),
                    style: LoadingStyle.dots,
                  ),
                  SizedBox(height: TvUtils.responsivePadding(24, context)),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: TvUtils.responsiveFontSize(16, context),
                    ),
                  ),
                ],
              ),
            )
          : _allItems.isEmpty
          ? Center(
              child: Text(
                'No content available',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: TvUtils.responsiveFontSize(16, context),
                ),
              ),
            )
          : GridView.builder(
              controller: _scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _allItems.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _allItems.length) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CustomLoadingWidget(
                      size: 40,
                      color: Color(0xFFE50914),
                    ),
                  );
                }
                return _buildFullListItem(_allItems[index]);
              },
            ),
    );
  }

  Widget _buildFullListItem(Map<String, dynamic> item) {
    final posterUrl = TmdbApiService.getPosterUrl(item['poster_path'] ?? '');
    final title = item['name'] ?? 'Unknown';
    final year = item['first_air_date']?.toString().split('-')[0] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TvSeriesScreen(seriesItem: Movie.fromJson(item)),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.network(
                    posterUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.tv, color: Colors.grey, size: 40),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white.withOpacity(0.8),
                      size: 50,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(12, context)),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(14, context),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (year.isNotEmpty)
            Text(
              year,
              style: TextStyle(
                color: Colors.grey,
                fontSize: TvUtils.responsiveFontSize(12, context),
              ),
            ),
        ],
      ),
    );
  }
}
