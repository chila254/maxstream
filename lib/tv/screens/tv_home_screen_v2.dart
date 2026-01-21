import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/movie.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';
import '../utils/tv_content_screen_mixin.dart';
import '../utils/tv_dpad_navigation_mixin.dart';
import '../widgets/tv_enhanced_hero_banner.dart';
import '../widgets/tv_content_card.dart';
import '../widgets/tv_carousel_enhanced.dart';
import '../widgets/tv_visual_enhancements.dart';
import '../widgets/tv_dark_mode_polish.dart';
import '../widgets/tv_streaming_providers_widget.dart';
import 'tv_search_screen.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';

/// Netflix-style TV Home Screen (non-freezing version)
/// Data loads asynchronously without blocking navigation
class TvHomeScreenV2 extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;

  const TvHomeScreenV2({super.key, this.onReturnToSidebar});

  @override
  State<TvHomeScreenV2> createState() => _TvHomeScreenV2State();
}

class _TvHomeScreenV2State extends State<TvHomeScreenV2>
    with TvContentScreenMixin, TvDpadNavigationMixin {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> trendingMovies = [];
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularMovies = [];
  List<Map<String, dynamic>> topRatedMovies = [];
  List<Map<String, dynamic>> continueWatching = [];

  late PageController _heroBannerController;
  Timer? _heroBannerTimer;
  int _heroBannerPage = 0;
  int? _focusedItemIndex;

  @override
  void initState() {
    super.initState();
    _heroBannerController = PageController();
    
    // Load content asynchronously (non-blocking)
    Future.microtask(() => _loadContent());
  }

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex {
    final allItems = [...trendingMovies, ...trendingSeries, ...popularMovies, ...topRatedMovies];
    return allItems.isEmpty ? 0 : allItems.length - 1;
  }

  @override
  void onFocusChanged(int index) {
    setState(() => _focusedItemIndex = index);
  }

  @override
  void onSelectPressed() {
    // Selection handled by content cards
  }

  @override
  void onLeftPressed() {
    if (_focusedItemIndex != null && widget.onReturnToSidebar != null) {
      widget.onReturnToSidebar!();
    }
  }

  @override
  void onRightPressed() {
    // No right navigation needed for home screen
  }

  @override
  void dispose() {
    _heroBannerController.dispose();
    _heroBannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContent() async {
    try {
      safeSetState(() => _isLoading = true);

      final results = await Future.wait([
        TmdbApiService.fetchTrendingMovies(),
        TmdbApiService.fetchTrendingSeries(),
        TmdbApiService.fetchPopularMovies(),
        TmdbApiService.fetchTopRatedMovies(),
        WatchHistoryService.getWatchHistory(),
      ]);

      safeSetState(() {
        trendingMovies = results[0];
        trendingSeries = results[1];
        popularMovies = results[2];
        topRatedMovies = results[3];
        continueWatching = results[4].take(10).toList();
        _errorMessage = null;
      });

      // Start auto-scrolling hero banner
      if (trendingMovies.isNotEmpty) {
        _startHeroBannerTimer();
      }
    } catch (e) {
      safeSetState(() {
        _errorMessage = 'Failed to load content: $e';
      });
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  void _startHeroBannerTimer() {
    _heroBannerTimer?.cancel();
    _heroBannerTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (trendingMovies.isNotEmpty && _heroBannerController.hasClients) {
        _heroBannerPage = (_heroBannerPage + 1) % trendingMovies.length;
        _heroBannerController.animateToPage(
          _heroBannerPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TvSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      onKey: handleKeyEvent,
      focusNode: focusNode,
      child: DarkModeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: DarkModeAppBar(
              title: 'MaxStream TV',
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.search,
                    color: Color(0xFFE50914),
                  ),
                  onPressed: _openSearch,
                ),
              ],
            ),
          ),
          body: _errorMessage != null
              ? buildErrorWidget(_errorMessage!, _loadContent)
              : _isLoading
                  ? buildLoadingWidget()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadContent,
      child: CustomScrollView(
        slivers: [
          if (trendingMovies.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildHeroBanner()),
            SliverToBoxAdapter(child: _buildHeroBannerIndicators()),
          ],
          // Streaming Providers Section
          SliverToBoxAdapter(
            child: _buildStreamingProvidersSection(),
          ),
          if (continueWatching.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildContinueWatchingCarousel(),
            ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Trending Movies',
              trendingMovies.take(10).toList(),
              'movie',
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Trending Series',
              trendingSeries.take(10).toList(),
              'series',
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Popular Movies',
              popularMovies.take(10).toList(),
              'movie',
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Top Rated',
              topRatedMovies.take(10).toList(),
              'movie',
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    final height = 550.0;

    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: _heroBannerController,
        itemCount: trendingMovies.length,
        onPageChanged: (index) {
          setState(() {
            _heroBannerPage = index;
          });
        },
        itemBuilder: (context, index) {
          final movie = trendingMovies[index];
          final backdropUrl =
              TmdbApiService.getBackdropUrl(movie['backdrop_path'] ?? '');
          final title = movie['title'] ?? movie['name'] ?? 'Unknown';
          final rating = (movie['vote_average'] as num?)?.toDouble() ?? 0.0;
          final overview = movie['overview'] ?? '';

          return TvEnhancedHeroBanner(
            backdropUrl: backdropUrl,
            title: title,
            description: overview,
            rating: rating > 0 ? rating : null,
            onTap: () => _navigateToDetails(movie, 'movie'),
            isFocused: true,
          );
        },
      ),
    );
  }

  Widget _buildHeroBannerIndicators() {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: TvUtils.responsivePadding(16, context),
      ),
      child: TvEnhancedPageIndicator(
        itemCount: trendingMovies.length,
        currentIndex: _heroBannerPage,
        animationDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildStreamingProvidersSection() {
    // Major streaming providers available
    final providerIds = [8, 9, 337, 15, 2, 3]; // Netflix, Prime, Disney+, Hulu, Apple TV+, Google Play

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: TvUtils.responsivePadding(16, context),
        horizontal: TvUtils.responsivePadding(24, context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'Watch On',
            baseStyle: TextStyle(
              fontSize: TvUtils.responsiveFontSize(20, context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(12, context)),
          TvStreamingProvidersHorizontalList(
            providerIds: providerIds,
            onProviderSelected: (provider) {
              // Navigate to provider content or show provider details
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${provider.name} selected'),
                  duration: const Duration(milliseconds: 800),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContinueWatchingCarousel() {
    final items = continueWatching.take(10).map((item) {
      final titleKey = item['title'] != null ? 'title' : 'name';
      final dateKey = item['title'] != null ? 'release_date' : 'first_air_date';
      final dateStr = item[dateKey] as String?;
      final year = dateStr != null ? int.tryParse(dateStr.split('-')[0]) : null;
      final rating = (item['vote_average'] as num?)?.toDouble();
      
      return ContinueWatchingItem(
        id: item['id'].toString(),
        title: item[titleKey] ?? 'Unknown',
        posterUrl: TmdbApiService.getPosterUrl(item['poster_path'] ?? ''),
        progress: 0.65, // Default progress, can be fetched from watch history
        duration: '45 min',
        nextEpisode: 'Season 2 • Episode 3',
        rating: rating != null ? '${rating.toStringAsFixed(1)}/10' : null,
        releaseYear: year,
      );
    }).toList();

    return TvContinueWatchingCarousel(
      items: items,
      scrollDuration: const Duration(milliseconds: 500),
      animationDuration: const Duration(milliseconds: 300),
      enableParallax: true,
      onItemSelected: (index) {
        if (index < continueWatching.length) {
          _navigateToDetails(continueWatching[index], 'movie');
        }
      },
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> items,
    String contentType,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: TvSpacing.sectionPaddingV,
        horizontal: TvSpacing.sectionPaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            title,
            baseStyle: TvTypography.sectionTitle,
          ),
          const SizedBox(height: TvSpacing.titleGap),
          SizedBox(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildContentCard(
                  item,
                  contentType == 'series' ? 'series' : 'movie',
                  isFocused: _focusedItemIndex == index,
                  // Add status badge for trending
                  showStatusBadge: contentType == 'movie' && index < 3,
                  badgeType: index == 0
                      ? BadgeType.trending
                      : index == 1
                          ? BadgeType.new_
                          : BadgeType.topRated,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(
    Map<String, dynamic> item,
    String type, {
    bool isFocused = false,
    bool showStatusBadge = false,
    BadgeType? badgeType,
  }) {
    final isMovie = type == 'movie';
    final contentTypeEnum = isMovie ? ContentType.movie : ContentType.series;
    final dateKey = isMovie ? 'release_date' : 'first_air_date';
    final titleKey = isMovie ? 'title' : 'name';
    final posterUrl = TmdbApiService.getPosterUrl(item['poster_path'] ?? '');
    final title = item[titleKey] ?? 'Unknown';
    final rating = (item['vote_average'] as num?)?.toDouble();
    final dateStr = item[dateKey] as String?;
    final year = dateStr != null ? int.tryParse(dateStr.split('-')[0]) : null;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: TvSpacing.cardSpacing),
          child: TvContentCard(
            posterUrl: posterUrl,
            title: title,
            contentType: contentTypeEnum,
            rating: rating,
            year: year,
            isFocused: isFocused,
            onTap: () => _navigateToDetails(item, type),
            width: 180,
            height: 270,
          ),
        ),
        if (showStatusBadge && badgeType != null)
          Positioned(
            top: 16,
            right: 16,
            child: StatusBadge(
              label: _getBadgeLabel(badgeType),
              type: badgeType,
            ),
          ),
      ],
    );
  }

  String _getBadgeLabel(BadgeType type) {
    switch (type) {
      case BadgeType.new_:
        return 'New';
      case BadgeType.trending:
        return 'Trending';
      case BadgeType.topRated:
        return 'Top Rated';
      case BadgeType.exclusive:
        return 'Exclusive';
      case BadgeType.comingSoon:
        return 'Coming Soon';
    }
  }

  void _navigateToDetails(Map<String, dynamic> item, String type) {
    if (type == 'series') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TvSeriesScreen(
            seriesItem: Movie.fromJson(item),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TvDetailsScreen(
            item: Movie.fromJson(item),
            mediaType: 'movie',
          ),
        ),
      );
    }
  }
}
