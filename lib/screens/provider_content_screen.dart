import 'package:flutter/material.dart';
import '../widgets/app_shimmer.dart';
import '../models/movie.dart';
import '../services/tmdb_api_service.dart';
import '../utils/tmdb_list_utils.dart';
import '../widgets/custom_loading_widget.dart';
import 'maxstream_details_screen.dart';
import 'maxstream_series_screen.dart';
import '../widgets/app_network_image.dart';

class ProviderContentScreen extends StatefulWidget {
  final int providerId;
  final String providerName;
  final Color providerColor;

  const ProviderContentScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.providerColor,
  });

  @override
  State<ProviderContentScreen> createState() => _ProviderContentScreenState();
}

class _ProviderContentScreenState extends State<ProviderContentScreen> {
  late PageController _pageController;
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> _moviesPage1 = [];
  List<Map<String, dynamic>> _seriesPage1 = [];
  bool _isLoadingMovies = false;
  bool _isLoadingShows = false;
  int _moviePage = 1;
  int _showPage = 1;
  late ScrollController _movieScrollController;
  late ScrollController _showScrollController;
  bool _isLoadingMoreMovies = false;
  bool _isLoadingMoreShows = false;
  bool _hasMoreMovies = true;
  bool _hasMoreShows = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _movieScrollController = ScrollController();
    _showScrollController = ScrollController();
    _movieScrollController.addListener(_movieScrollListener);
    _showScrollController.addListener(_showScrollListener);
    _loadInitialContent();
  }

  Future<void> _loadInitialContent() async {
    await Future.wait([_loadMovies(), _loadShows()]);
  }

  Future<void> _loadMovies() async {
    if (_isLoadingMovies) return;
    setState(() => _isLoadingMovies = true);
    try {
      final movies = await TmdbApiService.getMoviesByProvider(
        widget.providerId,
        page: 1,
      );
      if (mounted) {
        setState(() {
          _moviesPage1 = movies;
          _moviePage = 1;
          _hasMoreMovies = true;
          _isLoadingMovies = false;
        });
      }
    } catch (e) {
      // Error loading movies
      if (mounted) {
        setState(() => _isLoadingMovies = false);
      }
    }
  }

  Future<void> _loadShows() async {
    if (_isLoadingShows) return;
    setState(() => _isLoadingShows = true);
    try {
      final shows = await TmdbApiService.getSeriesByProvider(
        widget.providerId,
        page: 1,
      );
      if (mounted) {
        setState(() {
          _seriesPage1 = shows;
          _showPage = 1;
          _hasMoreShows = true;
          _isLoadingShows = false;
        });
      }
    } catch (e) {
      // Error loading shows
      if (mounted) {
        setState(() => _isLoadingShows = false);
      }
    }
  }

  void _movieScrollListener() {
    if (_movieScrollController.position.pixels ==
            _movieScrollController.position.maxScrollExtent &&
        !_isLoadingMoreMovies &&
        _hasMoreMovies &&
        _moviesPage1.isNotEmpty) {
      _loadMoreMovies();
    }
  }

  void _showScrollListener() {
    if (_showScrollController.position.pixels ==
            _showScrollController.position.maxScrollExtent &&
        !_isLoadingMoreShows &&
        _hasMoreShows &&
        _seriesPage1.isNotEmpty) {
      _loadMoreShows();
    }
  }

  Future<void> _loadMoreMovies() async {
    if (_isLoadingMoreMovies || !_hasMoreMovies) return;
    setState(() => _isLoadingMoreMovies = true);
    try {
      final nextPage = _moviePage + 1;
      final newMovies = await TmdbApiService.getMoviesByProvider(
        widget.providerId,
        page: nextPage,
      );
      if (mounted) {
        final merged = uniqueTmdbItems(_moviesPage1, newMovies, 'movie');
        setState(() {
          _hasMoreMovies = merged.length > _moviesPage1.length;
          _moviesPage1 = merged;
          if (_hasMoreMovies) _moviePage = nextPage;
          _isLoadingMoreMovies = false;
        });
      }
    } catch (e) {
      // Error loading more movies
      if (mounted) {
        setState(() => _isLoadingMoreMovies = false);
      }
    }
  }

  Future<void> _loadMoreShows() async {
    if (_isLoadingMoreShows || !_hasMoreShows) return;
    setState(() => _isLoadingMoreShows = true);
    try {
      final nextPage = _showPage + 1;
      final newShows = await TmdbApiService.getSeriesByProvider(
        widget.providerId,
        page: nextPage,
      );
      if (mounted) {
        final merged = uniqueTmdbItems(_seriesPage1, newShows, 'tv');
        setState(() {
          _hasMoreShows = merged.length > _seriesPage1.length;
          _seriesPage1 = merged;
          if (_hasMoreShows) _showPage = nextPage;
          _isLoadingMoreShows = false;
        });
      }
    } catch (e) {
      // Error loading more shows
      if (mounted) {
        setState(() => _isLoadingMoreShows = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _movieScrollController.dispose();
    _showScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          widget.providerName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _currentTabIndex = 0);
                      _pageController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _currentTabIndex == 0
                                ? widget.providerColor
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Movies',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _currentTabIndex == 0
                              ? Colors.white
                              : Colors.grey[400],
                          fontWeight: _currentTabIndex == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _currentTabIndex = 1);
                      _pageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _currentTabIndex == 1
                                ? widget.providerColor
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'TV Shows',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _currentTabIndex == 1
                              ? Colors.white
                              : Colors.grey[400],
                          fontWeight: _currentTabIndex == 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentTabIndex = index);
              },
              children: [_buildMoviesGrid(), _buildShowsGrid()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoviesGrid() {
    if (_isLoadingMovies) {
      return _buildLoadingShimmer();
    }

    if (_moviesPage1.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No movies available',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _movieScrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.0,
      ),
      itemCount: _moviesPage1.length + (_isLoadingMoreMovies ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _moviesPage1.length) {
          return const Center(
            child: CustomLoadingWidget(
              size: 30,
              color: Color(0xFFE50914),
              style: LoadingStyle.dots,
            ),
          );
        }

        final movie = _moviesPage1[index];
        return GestureDetector(
          key: ValueKey(tmdbItemKey(movie, 'movie')),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    MaxStreamDetailsScreen(
                      item: Movie.fromJson(movie),
                      mediaType: 'movie',
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.fastOutSlowIn,
                              ),
                            ),
                        child: child,
                      );
                    },
                transitionDuration: const Duration(milliseconds: 250),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: movie['poster_path'] != null
                    ? AppNetworkImage(
                        url: TmdbApiService.getPosterUrl(movie['poster_path']),
                        width: 80,
                        height: 120,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          width: 80,
                          height: 120,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.movie,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 120,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.movie,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie['title'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getYear(movie),
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movie['overview'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShowsGrid() {
    if (_isLoadingShows) {
      return _buildLoadingShimmer();
    }

    if (_seriesPage1.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No TV shows available',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _showScrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.0,
      ),
      itemCount: _seriesPage1.length + (_isLoadingMoreShows ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _seriesPage1.length) {
          return const Center(
            child: CustomLoadingWidget(
              size: 30,
              color: Color(0xFFE50914),
              style: LoadingStyle.dots,
            ),
          );
        }

        final show = _seriesPage1[index];
        return GestureDetector(
          key: ValueKey(tmdbItemKey(show, 'tv')),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    MaxStreamSeriesScreen(seriesItem: Movie.fromJson(show)),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.fastOutSlowIn,
                              ),
                            ),
                        child: child,
                      );
                    },
                transitionDuration: const Duration(milliseconds: 250),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: show['poster_path'] != null
                    ? AppNetworkImage(
                        url: TmdbApiService.getPosterUrl(show['poster_path']),
                        width: 80,
                        height: 120,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          width: 80,
                          height: 120,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.tv,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 120,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.tv,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show['name'] ?? show['title'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getYear(show),
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      show['overview'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return AppShimmer(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.0,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, color: Colors.grey[800]),
                    const SizedBox(height: 4),
                    Container(height: 14, width: 50, color: Colors.grey[800]),
                    const SizedBox(height: 8),
                    Container(height: 12, color: Colors.grey[800]),
                    const SizedBox(height: 4),
                    Container(height: 12, color: Colors.grey[800]),
                    const SizedBox(height: 4),
                    Container(height: 12, width: 100, color: Colors.grey[800]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getYear(Map<String, dynamic> item) {
    final date = item['release_date'] ?? item['first_air_date'];
    if (date != null && date.toString().length >= 4) {
      return date.toString().substring(0, 4);
    }
    return '';
  }
}
