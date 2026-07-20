import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/movie.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/index.dart';
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

class _TvHomeScreenState extends State<TvHomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> trendingMovies = [];
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularMovies = [];
  List<Map<String, dynamic>> topRatedMovies = [];
  List<Map<String, dynamic>> continueWatching = [];

  late ScrollController _contentScrollController;

  @override
  void initState() {
    super.initState();
    _contentScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navProvider = context.read<TvNavigationProvider>();
      navProvider.registerScrollController(0, _contentScrollController);
      _contentScrollController.addListener(() {
        navProvider.saveScrollOffset(0, _contentScrollController.offset);
      });
    });

    _loadContent();
  }

  @override
  void dispose() {
    _contentScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    try {
      setState(() => _isLoading = true);

      final results = await Future.wait([
        TmdbApiService.fetchTrendingMovies(),
        TmdbApiService.fetchTrendingSeries(),
        TmdbApiService.fetchPopularMovies(),
        TmdbApiService.fetchTopRatedMovies(),
        WatchHistoryService.getWatchHistory(),
      ]);

      setState(() {
        trendingMovies = results[0];
        trendingSeries = results[1];
        popularMovies = results[2];
        topRatedMovies = results[3];
        continueWatching = results[4].take(10).toList();
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load content: $e');
    } finally {
      setState(() => _isLoading = false);
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
                ? _buildLoadingWidget()
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
              _contentScrollController.offset - 400,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
          return KeyEventResult.handled;
        } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
          if (_contentScrollController.offset <
              _contentScrollController.position.maxScrollExtent) {
            _contentScrollController.animateTo(
              _contentScrollController.offset + 400,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
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
            // Featured section - first trending movie as big hero card
            if (trendingMovies.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildFeaturedSection(),
              ),
            // Continue Watching
            if (continueWatching.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildContentRow(
                  'Continue Watching',
                  continueWatching,
                  showProgress: true,
                ),
              ),
            // Trending Movies
            SliverToBoxAdapter(
              child: _buildContentRow(
                'Trending Movies',
                trendingMovies.take(15).toList(),
              ),
            ),
            // Trending Series
            SliverToBoxAdapter(
              child: _buildContentRow(
                'Trending Series',
                trendingSeries.take(15).toList(),
                contentType: 'series',
              ),
            ),
            // Popular Movies
            SliverToBoxAdapter(
              child: _buildContentRow(
                'Popular Movies',
                popularMovies.take(15).toList(),
              ),
            ),
            // Top Rated
            SliverToBoxAdapter(
              child: _buildContentRow(
                'Top Rated',
                topRatedMovies.take(15).toList(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedSection() {
    final movie = trendingMovies.first;
    final backdropUrl = TmdbApiService.getBackdropUrl(
      movie['backdrop_path'] ?? '',
    );
    final title = movie['title'] ?? movie['name'] ?? 'Unknown';
    final rating = (movie['vote_average'] as num?)?.toDouble() ?? 0.0;
    final overview = movie['overview'] ?? '';
    final year = (movie['release_date'] as String?)?.substring(0, 4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GestureDetector(
        onTap: () => _navigateToDetails(movie, 'movie'),
        child: Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.select)) {
              _playMovie(movie);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1A1A1A),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Backdrop image
                Image.network(
                  backdropUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.movie, color: Colors.grey, size: 60),
                  ),
                ),
                // Gradient overlays
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                      stops: [0.0, 0.5],
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (rating > 0) ...[
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (year != null)
                            Text(
                              year,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          const SizedBox(width: 12),
                          // Genre chips
                          if (movie['genre_ids'] != null)
                            ...((movie['genre_ids'] as List).take(2).map((id) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getGenreName(id),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              );
                            })),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        overview,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ActionChip(
                            icon: Icons.play_arrow,
                            label: 'Play',
                            primary: true,
                            onTap: () => _playMovie(movie),
                          ),
                          const SizedBox(width: 8),
                          _ActionChip(
                            icon: Icons.info_outline,
                            label: 'Details',
                            onTap: () => _navigateToDetails(movie, 'movie'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentRow(
    String title,
    List<Map<String, dynamic>> items, {
    String contentType = 'movie',
    bool showProgress = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isMovie = contentType == 'movie';
                final dateKey = isMovie ? 'release_date' : 'first_air_date';
                final titleKey = isMovie ? 'title' : 'name';
                final posterUrl = TmdbApiService.getPosterUrl(
                  item['poster_path'] ?? '',
                );
                final itemTitle = item[titleKey] ?? 'Unknown';
                final rating = (item['vote_average'] as num?)?.toDouble();
                final dateStr = item[dateKey] as String?;
                final year = dateStr != null
                    ? int.tryParse(dateStr.split('-')[0])
                    : null;

                return _ContentRowItem(
                  posterUrl: posterUrl,
                  title: itemTitle,
                  year: year,
                  rating: rating,
                  onTap: () => _navigateToDetails(item, contentType),
                  onPlay: () {
                    if (contentType == 'series') {
                      _playSeries(item);
                    } else {
                      _playMovie(item);
                    }
                  },
                );
              },
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

  String _getGenreName(int id) {
    const genres = {
      28: 'Action', 12: 'Adventure', 16: 'Animation', 35: 'Comedy',
      80: 'Crime', 99: 'Documentary', 18: 'Drama', 10751: 'Family',
      14: 'Fantasy', 36: 'History', 27: 'Horror', 10402: 'Music',
      9648: 'Mystery', 10749: 'Romance', 878: 'Sci-Fi', 10770: 'TV Movie',
      53: 'Thriller', 10752: 'War', 37: 'Western',
    };
    return genres[id] ?? 'Movie';
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.red),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadContent,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ContentRowItem extends StatefulWidget {
  final String posterUrl;
  final String title;
  final int? year;
  final double? rating;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _ContentRowItem({
    required this.posterUrl,
    required this.title,
    this.year,
    this.rating,
    required this.onTap,
    required this.onPlay,
  });

  @override
  State<_ContentRowItem> createState() => _ContentRowItemState();
}

class _ContentRowItemState extends State<_ContentRowItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Focus(
        onKey: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isFocused ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: _isFocused
                    ? Border.all(color: Colors.red, width: 2)
                    : null,
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            widget.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.movie,
                                  color: Colors.grey, size: 40),
                            ),
                          ),
                          if (_isFocused)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    onTap: widget.onPlay,
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow,
                                          color: Colors.white, size: 28),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Info
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: _isFocused ? Colors.white : Colors.grey[300],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.year != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.year.toString(),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.primary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? Colors.red : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
