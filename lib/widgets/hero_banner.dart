import 'dart:async';
import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../screens/onstream_details_screen.dart';
import '../screens/onstream_series_screen.dart';
import '../services/tmdb_api_service.dart';
import '../services/haptic_service.dart';
import '../database/db_helper.dart';
import '../utils/responsive_utils.dart';
import '../screens/modern_video_player_screen.dart';

class HeroBanner extends StatefulWidget {
  const HeroBanner({super.key});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  List<Movie> featuredItems = [];
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;
  final Set<int> _watchlistIds = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadFeaturedItems();
    _loadWatchlistIds();
  }

  Future<void> _loadFeaturedItems() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final movies = await TmdbApiService.fetchTrendingMovies();
      final series = await TmdbApiService.fetchTrendingSeries();
      final combined = [...movies, ...series];

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (combined.isNotEmpty) {
            featuredItems = combined
                .map((item) => Movie.fromJson(item))
                .take(5)
                .toList();
            _startTimer();
          } else {
            _hasError = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _loadWatchlistIds() async {
    final watchlist = await DBHelper.getWatchlist();
    setState(() {
      _watchlistIds.addAll(watchlist.map((item) => int.parse(item.id)));
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_currentPage < featuredItems.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _toggleWatchlist(Movie item) async {
    try {
      final wasInWatchlist = _watchlistIds.contains(int.parse(item.id));

      // Add haptic feedback
      if (!wasInWatchlist) {
        await HapticService.success();
      } else {
        await HapticService.lightImpact();
      }

      if (wasInWatchlist) {
        await DBHelper.removeMovie(int.parse(item.id));
        setState(() => _watchlistIds.remove(int.parse(item.id)));
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
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await DBHelper.addToWatchlist(item);
        setState(() => _watchlistIds.add(int.parse(item.id)));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('${item.title} added to watchlist'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      await HapticService.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Error updating watchlist: $e'),
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
    }
  }

  Future<void> _playVideo(Movie item) async {
    try {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ModernVideoPlayerScreen(
            title: item.title,
            tmdbId: item.id,
            isMovie: item.mediaType == 'movie',
            season: 1,
            episode: 1,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load video: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade900, Colors.black],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }

    if (_hasError || featuredItems.isEmpty) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade900, Colors.black],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Unable to load featured content',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFeaturedItems,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bannerHeight = ResponsiveUtils.getHeroBannerHeight(context);

    return SizedBox(
      height: bannerHeight,
      child: PageView.builder(
        controller: _pageController,
        itemCount: featuredItems.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) {
          final item = featuredItems[index];
          final isInWatchlist = _watchlistIds.contains(int.parse(item.id));

          return Stack(
            children: [
              // Background Image
              Container(
                height: bannerHeight,
                decoration: BoxDecoration(
                  image: item.backdrop.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(
                            TmdbApiService.getBackdropUrl(item.backdrop),
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: item.backdrop.isEmpty ? Colors.grey.shade800 : null,
                ),
                child: item.backdrop.isEmpty
                    ? Center(
                        child: Icon(
                          item.mediaType == 'tv' ? Icons.tv : Icons.movie,
                          size: 100,
                          color: Colors.white54,
                        ),
                      )
                    : null,
              ),

              // Gradient Overlay
              Container(
                height: bannerHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

              // Content
              Positioned(
                bottom: ResponsiveUtils.getSpacing(context, mobile: 60),
                left: ResponsiveUtils.getHorizontalPadding(context),
                right: ResponsiveUtils.getHorizontalPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(
                          context,
                          mobile: 28,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      maxLines:
                          ResponsiveUtils.isTablet(context) ||
                              ResponsiveUtils.isDesktop(context)
                          ? 3
                          : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Rating and Year
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (item.releaseDate.isNotEmpty)
                          Text(
                            item.releaseDate.split('-')[0],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.mediaType == 'tv'
                                ? const Color(0xFFE50914)
                                : Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.mediaType == 'tv' ? 'TV SERIES' : 'MOVIE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        // Play Button
                        Expanded(
                          flex: 2,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await HapticService.mediumImpact();
                                _playVideo(item);
                              },
                              icon: const Icon(
                                Icons.play_arrow,
                                color: Colors.black,
                              ),
                              label: Text(
                                item.mediaType == 'tv' ? 'Play S1:E1' : 'Play',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style:
                                  ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    elevation: 4,
                                    shadowColor: Colors.black.withValues(
                                      alpha: 0.3,
                                    ),
                                  ).copyWith(
                                    overlayColor: WidgetStateProperty.all(
                                      Colors.grey.shade200,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Watchlist Button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isInWatchlist
                                ? Colors.red.shade600.withValues(alpha: 0.8)
                                : Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isInWatchlist
                                  ? Colors.red.shade400
                                  : Colors.white,
                              width: 1,
                            ),
                            boxShadow: isInWatchlist
                                ? [
                                    BoxShadow(
                                      color: Colors.red.shade600.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: IconButton(
                            onPressed: () async {
                              await HapticService.selectionClick();
                              _toggleWatchlist(item);
                            },
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: child,
                                );
                              },
                              child: Icon(
                                isInWatchlist
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey(isInWatchlist),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // More Info Button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              await HapticService.selectionClick();
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => item.mediaType == 'tv'
                                      ? OnStreamSeriesScreen(seriesItem: item)
                                      : OnStreamDetailsScreen(
                                          item: item,
                                          mediaType: item.mediaType,
                                        ),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(1.0, 0.0),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeInOut,
                                                ),
                                              ),
                                          child: child,
                                        );
                                      },
                                  transitionDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Page Indicators
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    featuredItems.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentPage
                            ? const Color(0xFFE50914)
                            : Colors.white.withAlpha((255 * 0.4).round()),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
