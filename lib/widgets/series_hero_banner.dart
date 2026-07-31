import 'dart:async';
import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../screens/maxstream_series_screen.dart';
import '../services/api_service.dart';
import '../database/db_helper.dart';
import '../utils/responsive_utils.dart';

import 'video_player_screen.dart';

class SeriesHeroBanner extends StatefulWidget {
  const SeriesHeroBanner({super.key});

  @override
  State<SeriesHeroBanner> createState() => _SeriesHeroBannerState();
}

class _SeriesHeroBannerState extends State<SeriesHeroBanner> {
  List<Movie> featuredSeries = [];
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;
  final Set<int> _watchlistIds = {};
  bool _isPlayingVideo = false;

  @override
  void initState() {
    super.initState();
    _loadFeaturedSeries();
    _loadWatchlistIds();
  }

  Future<void> _loadFeaturedSeries() async {
    try {
      final series = await ApiService.fetchTrendingSeries();
      if (series.isEmpty) return;

      final items = series;
      if (mounted) {
        setState(() {
          featuredSeries = items.take(5).toList();
        });
        _startTimer();
      }
    } catch (e) {
      // print("Failed to load featured series: $e");
    }
  }

  Future<void> _loadWatchlistIds() async {
    final watchlist = await DBHelper.getWatchlist();
    setState(() {
      _watchlistIds.addAll(
        watchlist
            .where((item) => item.mediaType == 'tv')
            .map((item) => int.parse(item.id)),
      );
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_currentPage < featuredSeries.length - 1) {
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

  Future<void> _toggleWatchlist(Movie series) async {
    final wasInWatchlist = _watchlistIds.contains(int.parse(series.id));

    if (wasInWatchlist) {
      await DBHelper.removeMovie(series.id, series.mediaType);
      setState(() => _watchlistIds.remove(int.parse(series.id)));
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
                Text('${series.title} removed from watchlist'),
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
      await DBHelper.addToWatchlist(series);
      setState(() => _watchlistIds.add(int.parse(series.id)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('${series.title} added to watchlist'),
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
  }

  Future<void> _playVideo(Movie series) async {
    try {
      if (!mounted) return;

      setState(() => _isPlayingVideo = true);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => buildVideoPlayerScreen(
            title: series.title,
            tmdbId: series.id,
            isMovie: false,
            season: 1,
            episode: 1,
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() => _isPlayingVideo = false);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isPlayingVideo = false);
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
    final bannerHeight = ResponsiveUtils.getHeroBannerHeight(context);

    if (featuredSeries.isEmpty) {
      return Container(
        height: bannerHeight,
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

    return SizedBox(
      height: bannerHeight,
      child: PageView.builder(
        controller: _pageController,
        itemCount: featuredSeries.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) {
          final series = featuredSeries[index];
          final isInWatchlist = _watchlistIds.contains(int.parse(series.id));

          return Stack(
            children: [
              // Background Image
              Container(
                height: bannerHeight,
                decoration: BoxDecoration(
                  image: series.backdrop.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(series.backdrop),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: series.backdrop.isEmpty ? Colors.grey.shade800 : null,
                ),
                child: series.backdrop.isEmpty
                    ? const Center(
                        child: Icon(Icons.tv, size: 100, color: Colors.white54),
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
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),

              // Content
              Positioned(
                bottom: 60,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      series.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Rating and Year
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          series.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (series.releaseDate.isNotEmpty)
                          Text(
                            series.releaseDate.split('-')[0],
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
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TV SERIES',
                            style: TextStyle(
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
                          child: ElevatedButton.icon(
                            onPressed: _isPlayingVideo
                                ? null
                                : () => _playVideo(series),
                            icon: _isPlayingVideo
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.play_arrow,
                                    color: Colors.black,
                                  ),
                            label: Text(
                              _isPlayingVideo ? 'Loading...' : 'Play S1:E1',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isPlayingVideo
                                  ? Colors.grey.shade300
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: _isPlayingVideo ? 0 : 4,
                              shadowColor: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Watchlist Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: IconButton(
                            onPressed: () => _toggleWatchlist(series),
                            icon: Icon(
                              isInWatchlist ? Icons.check : Icons.add,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // More Info Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MaxStreamSeriesScreen(seriesItem: series),
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
                    featuredSeries.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentPage
                            ? const Color(0xFFE50914)
                            : Colors.white.withValues(alpha: 0.4),
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
