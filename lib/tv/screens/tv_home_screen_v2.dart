import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/movie.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';
import '../utils/tv_dpad_navigation_mixin.dart';
import '../utils/tv_content_screen_mixin.dart';
import '../utils/tv_focus_manager.dart';
import '../widgets/tv_enhanced_hero_banner.dart';
import '../widgets/tv_content_card.dart';
import '../widgets/tv_carousel_enhanced.dart';
import '../widgets/tv_visual_enhancements.dart';
import '../widgets/tv_dark_mode_polish.dart';
import '../widgets/tv_streaming_providers_widget.dart';
import '../widgets/tv_content_grid.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';
import 'tv_video_player_screen.dart';

/// Netflix-style TV Home Screen (non-freezing version)
/// Data loads asynchronously without blocking navigation
/// Persists scroll position across navigation
class TvHomeScreenV2 extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;
  final GlobalKey<NavigatorState>? navigatorKey;

  const TvHomeScreenV2({super.key, this.onReturnToSidebar, this.navigatorKey});

  @override
  State<TvHomeScreenV2> createState() => _TvHomeScreenV2State();
}

class _TvHomeScreenV2State extends State<TvHomeScreenV2>
    with TvContentScreenMixin, TvDPadNavigationMixin {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> trendingMovies = [];
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularMovies = [];
  List<Map<String, dynamic>> topRatedMovies = [];
  List<Map<String, dynamic>> continueWatching = [];

  late PageController _heroBannerController;
  late ScrollController _contentScrollController;
  late FocusNode _heroBannerFocusNode; // Hero banner gets initial focus
  Timer? _heroBannerTimer;
  int _heroBannerPage = 0;

  @override
  void initState() {
    super.initState();
    _heroBannerController = PageController();
    _contentScrollController = ScrollController();
    _heroBannerFocusNode = FocusNode();

    // Register scroll controller with provider for scroll restoration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navProvider = context.read<TvNavigationProvider>();
      navProvider.registerScrollController(0, _contentScrollController);

      // Add scroll listener to save scroll offset
      _contentScrollController.addListener(() {
        navProvider.saveScrollOffset(0, _contentScrollController.offset);
      });

      // Netflix-style: Focus hero banner when Home screen loads
      // This is the primary entry point for content
      if (trendingMovies.isNotEmpty) {
        _heroBannerFocusNode.requestFocus();
      }
    });

    // Load content asynchronously (non-blocking)
    Future.microtask(() => _loadContent());
  }

  @override
  void dispose() {
    _heroBannerController.dispose();
    _contentScrollController.dispose();
    _heroBannerFocusNode.dispose();
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
    _heroBannerTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
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

  @override
  Widget build(BuildContext context) {
    return DarkModeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _errorMessage != null
            ? buildErrorWidget(_errorMessage!, _loadContent)
            : _isLoading
            ? buildLoadingWidget()
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Focus(
      onKey: (node, event) {
        if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
          if (_contentScrollController.offset > 0) {
            _contentScrollController.animateTo(
              _contentScrollController.offset - 300,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          return KeyEventResult.handled;
        } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
          if (_contentScrollController.offset <
              _contentScrollController.position.maxScrollExtent) {
            _contentScrollController.animateTo(
              _contentScrollController.offset + 300,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      autofocus: true,
      child: RefreshIndicator(
        onRefresh: _loadContent,
        child: CustomScrollView(
          controller: _contentScrollController,
          slivers: [
            if (trendingMovies.isNotEmpty) ...[
              SliverToBoxAdapter(child: _buildHeroBanner()),
              SliverToBoxAdapter(child: _buildHeroBannerIndicators()),
            ],
            // Streaming Providers Section
            SliverToBoxAdapter(child: _buildStreamingProvidersSection()),
            if (continueWatching.isNotEmpty)
              SliverToBoxAdapter(child: _buildContinueWatchingCarousel()),
            SliverToBoxAdapter(
              child: _buildSection(
                'Trending Movies',
                trendingMovies.take(10).toList(),
                'movie',
                sectionName: 'trending_movies',
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                'Trending Series',
                trendingSeries.take(10).toList(),
                'series',
                sectionName: 'trending_series',
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                'Popular Movies',
                popularMovies.take(10).toList(),
                'movie',
                sectionName: 'popular_movies',
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSection(
                'Top Rated',
                topRatedMovies.take(10).toList(),
                'movie',
                sectionName: 'top_rated_movies',
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    final height = 606.0;

    return Focus(
      focusNode: _heroBannerFocusNode,
      onKey: (node, event) {
        if (event.isKeyPressed(LogicalKeyboardKey.select)) {
          // Play the hero movie on SELECT
          if (trendingMovies.isNotEmpty) {
            _playMovie(trendingMovies[_heroBannerPage]);
          }
          return KeyEventResult.handled;
        } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
          // LEFT from hero banner → Sidebar (Netflix-style restoration)
          TvFocusManager.focusSidebar();
          context.read<TvNavigationProvider>().setFocusOnSidebar(true);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
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
            final backdropUrl = TmdbApiService.getBackdropUrl(
              movie['backdrop_path'] ?? '',
            );
            final title = movie['title'] ?? movie['name'] ?? 'Unknown';
            final rating = (movie['vote_average'] as num?)?.toDouble() ?? 0.0;
            final overview = movie['overview'] ?? '';

            return TvEnhancedHeroBanner(
              backdropUrl: backdropUrl,
              title: title,
              description: overview,
              rating: rating > 0 ? rating : null,
              onTap: () => _navigateToDetails(movie, 'movie'),
              onWatchNow: () => _playMovie(movie),
              onDetails: () => _navigateToDetails(movie, 'movie'),
              isFocused: _heroBannerFocusNode.hasFocus,
            );
          },
        ),
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
    // Streaming providers matching MaxStream mobile app
    final providerIds = [
      8, // Netflix
      9, // Prime Video
      337, // Disney+
      15, // Hulu
      350, // Apple TV
      1899, // HBO Max
      386, // Peacock
      582, // Paramount+
      526, // AMC+
    ];

    return Focus(
      onKey: (node, event) {
        if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
          node.previousFocus();
          return KeyEventResult.handled;
        } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
          node.nextFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: TvUtils.responsivePadding(24, context),
          horizontal: TvUtils.responsivePadding(24, context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientText(
              'Watch On',
              baseStyle: TextStyle(
                fontSize: TvUtils.responsiveFontSize(22, context),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: TvUtils.responsivePadding(16, context)),
            TvStreamingProvidersHorizontalList(
              providerIds: providerIds,
              onProviderSelected: _handleProviderSelected,
            ),
          ],
        ),
      ),
    );
  }

  void _handleProviderSelected(dynamic provider) {
    // Show visual feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.play_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Open ${provider.name}')),
          ],
        ),
        backgroundColor: Colors.grey[900],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(milliseconds: 1500),
      ),
    );

    // In a real app, you would navigate to provider content
    // For now, this provides visual feedback that the button is clickable
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
    String contentType, {
    String sectionName = '',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: TvSpacing.sectionPaddingV,
        horizontal: TvSpacing.sectionPaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GradientText(title, baseStyle: TvTypography.sectionTitle),
              Focus(
                onKey: (node, event) {
                  if (event.isKeyPressed(LogicalKeyboardKey.select)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('View all $title'),
                        duration: const Duration(milliseconds: 800),
                      ),
                    );
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('View all $title'),
                        duration: const Duration(milliseconds: 800),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TvSpacing.titleGap),
          SizedBox(
            height: 300,
            child: TvContentGrid(
              items: items.map((item) {
                final contentTypeEnum = contentType == 'series'
                    ? ContentType.series
                    : ContentType.movie;
                final isMovie = contentType == 'movie';
                final dateKey = isMovie ? 'release_date' : 'first_air_date';
                final titleKey = isMovie ? 'title' : 'name';
                final posterUrl = TmdbApiService.getPosterUrl(
                  item['poster_path'] ?? '',
                );
                final title = item[titleKey] ?? 'Unknown';
                final rating = (item['vote_average'] as num?)?.toDouble();
                final dateStr = item[dateKey] as String?;
                final year = dateStr != null
                    ? int.tryParse(dateStr.split('-')[0])
                    : null;

                return TvContentCard(
                  posterUrl: posterUrl,
                  title: title,
                  contentType: contentTypeEnum,
                  rating: rating,
                  year: year,
                  onTap: () => _navigateToDetails(item, contentType),
                  width: 180,
                  height: 270,
                );
              }).toList(),
              itemsPerRow: 1,
              itemHeight: 300,
              itemWidth: 180,
              spacing: 16,
              padding: EdgeInsets.zero,
              onItemSelected: (index) {
                _navigateToDetails(
                  items[index],
                  contentType == 'series' ? 'series' : 'movie',
                );
              },
              onReturnToSidebar: widget.onReturnToSidebar ?? () {},
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetails(Map<String, dynamic> item, String type) {
    if (type == 'series') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TvSeriesScreen(seriesItem: Movie.fromJson(item)),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TvDetailsScreen(item: Movie.fromJson(item), mediaType: 'movie'),
        ),
      );
    }
  }

  void _playMovie(Map<String, dynamic> movie) {
    final movieItem = Movie.fromJson(movie);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvVideoPlayerScreen(
          title: movieItem.title,
          tmdbId: movieItem.id,
          isMovie: true,
          season: 0,
          episode: 0,
        ),
      ),
    );
  }
}
