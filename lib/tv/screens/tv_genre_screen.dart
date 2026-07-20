import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/logger_service.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/index.dart';
import '../../widgets/custom_loading_widget.dart';
import '../widgets/tv_visual_enhancements.dart';
import '../widgets/tv_content_card.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';
import '../../models/movie.dart';

class TvGenreScreen extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;

  const TvGenreScreen({super.key, this.onReturnToSidebar});

  @override
  State<TvGenreScreen> createState() => _TvGenreScreenState();
}

class _TvGenreScreenState extends State<TvGenreScreen> {
  Map<int, String> _movieGenres = {};
  Map<int, String> _tvGenres = {};
  bool _isLoadingGenres = false;
  int? _selectedGenreId;
  String? _selectedGenreName;
  List<Map<String, dynamic>> _contentByGenre = [];
  bool _isLoadingContent = false;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;
  int _moviePage = 1;
  int _tvPage = 1;
  bool _showAllGenres = false;
  bool _hasMoreContent = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Register scroll controller with provider for scroll restoration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navProvider = context.read<TvNavigationProvider>();
      navProvider.registerScrollController(2, _scrollController);

      // Add scroll listener to save scroll offset
      _scrollController.addListener(() {
        navProvider.saveScrollOffset(2, _scrollController.offset);
      });
    });

    _loadGenres();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _selectedGenreId != null &&
        _hasMoreContent) {
      _loadMoreContent();
    }
  }

  Future<void> _loadGenres() async {
    setState(() => _isLoadingGenres = true);
    try {
      final movies = await TmdbApiService.fetchGenres('movie');
      final tv = await TmdbApiService.fetchGenres('tv');

      if (mounted) {
        setState(() {
          _movieGenres = movies;
          _tvGenres = tv;
          _isLoadingGenres = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading genres: $e', e);
      if (mounted) {
        setState(() => _isLoadingGenres = false);
      }
    }
  }

  Future<void> _loadContentByGenre(int genreId, String name) async {
    setState(() {
      _selectedGenreId = genreId;
      _selectedGenreName = name;
      _moviePage = 1;
      _tvPage = 1;
      _contentByGenre = [];
      _isLoadingContent = true;
      _hasMoreContent = true;
    });

    await _fetchGenreContent();
  }

  Future<void> _fetchGenreContent() async {
    if (_selectedGenreId == null) return;

    try {
      // Fetch both movies and series for the genre
      final results = await Future.wait([
        TmdbApiService.getMoviesByGenre(_selectedGenreId!, page: _moviePage),
        TmdbApiService.getSeriesByGenre(_selectedGenreId!, page: _tvPage),
      ]);

      final movieResults = results[0];
      final seriesResults = results[1];

      // Combine movies and series
      final combinedResults = [...movieResults, ...seriesResults];

      if (mounted) {
        setState(() {
          if (_moviePage == 1 && _tvPage == 1) {
            _contentByGenre = combinedResults;
          } else {
            _contentByGenre.addAll(combinedResults);
          }
          _hasMoreContent = movieResults.isNotEmpty || seriesResults.isNotEmpty;
          _isLoadingContent = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error fetching genre content: $e', e);
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreContent() async {
    if (_isLoadingMore || !_hasMoreContent) return;
    setState(() => _isLoadingMore = true);
    _moviePage++;
    _tvPage++;
    await _fetchGenreContent();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingGenres) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CustomLoadingWidget(
              size: 40,
              color: Color(0xFFE50914),
              style: LoadingStyle.dots,
            ),
            SizedBox(height: TvUtils.responsivePadding(16, context)),
            Text('Loading genres...', style: TvTypography.bodyLarge),
          ],
        ),
      );
    }

    return Focus(
      onKey: (node, event) {
        if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
          if (_scrollController.offset > 0) {
            _scrollController.animateTo(
              _scrollController.offset - 300,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          return KeyEventResult.handled;
        } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
          if (_scrollController.offset <
              _scrollController.position.maxScrollExtent) {
            _scrollController.animateTo(
              _scrollController.offset + 300,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          return KeyEventResult.handled;
        } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
          if (widget.onReturnToSidebar != null) {
            widget.onReturnToSidebar!();
          } else {
            TvFocusManager.focusSidebar();
            context.read<TvNavigationProvider>().setFocusOnSidebar(true);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      autofocus: true,
      child: CustomScrollView(
        controller: _selectedGenreId == null ? null : _scrollController,
        slivers: [
          // Genre Selection Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Movies Genres Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GradientText(
                        'Movie Genres',
                        baseStyle: TextStyle(
                          fontSize: TvUtils.responsiveFontSize(
                            24,
                            context,
                            maxSize: 36,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_movieGenres.length > 6)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showAllGenres = !_showAllGenres;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _showAllGenres ? 'Less' : 'See All',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: TvUtils.responsivePadding(16, context)),

                  // Movie Genres Grid/List
                  if (_showAllGenres)
                    _buildGenresGrid(_movieGenres)
                  else
                    _buildGenresHorizontalList(_movieGenres),

                  SizedBox(height: TvUtils.responsivePadding(48, context)),

                  // TV Series Genres Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GradientText(
                        'TV Series Genres',
                        baseStyle: TextStyle(
                          fontSize: TvUtils.responsiveFontSize(
                            24,
                            context,
                            maxSize: 36,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_tvGenres.length > 6)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showAllGenres = !_showAllGenres;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _showAllGenres ? 'Less' : 'See All',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: TvUtils.responsivePadding(16, context)),

                  // TV Genres Grid/List
                  if (_showAllGenres)
                    _buildGenresGrid(_tvGenres)
                  else
                    _buildGenresHorizontalList(_tvGenres),
                ],
              ),
            ),
          ),

          // Content Display Section
          if (_selectedGenreId != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: TvUtils.responsivePadding(24, context),
                  vertical: TvUtils.responsivePadding(24, context),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GradientText(
                      _selectedGenreName ?? 'Content',
                      baseStyle: TextStyle(
                        fontSize: TvUtils.responsiveFontSize(
                          24,
                          context,
                          maxSize: 36,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedGenreId = null;
                          _selectedGenreName = null;
                          _contentByGenre = [];
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.close, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Clear',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoadingContent)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(
                    TvUtils.responsivePadding(64, context),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CustomLoadingWidget(
                        size: 50,
                        color: Color(0xFFE50914),
                        style: LoadingStyle.dots,
                      ),
                      SizedBox(height: TvUtils.responsivePadding(16, context)),
                      Text(
                        'Loading content...',
                        style: TvTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else if (_contentByGenre.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(
                    TvUtils.responsivePadding(64, context),
                  ),
                  child: Center(
                    child: Text(
                      'No content found for this genre',
                      style: TvTypography.bodyMedium,
                    ),
                  ),
                ),
              )
            else
              SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.6,
                  crossAxisSpacing: TvUtils.responsivePadding(16, context),
                  mainAxisSpacing: TvUtils.responsivePadding(16, context),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _contentByGenre.length) {
                      return Center(
                        child: const CustomLoadingWidget(
                          size: 40,
                          color: Color(0xFFE50914),
                          style: LoadingStyle.dots,
                        ),
                      );
                    }

                    final item = _contentByGenre[index];
                    final isMovie =
                        item['title'] != null && item['media_type'] != 'tv';
                    final title = item['title'] ?? item['name'] ?? 'Unknown';
                    final posterUrl = TmdbApiService.getPosterUrl(
                      item['poster_path'] ?? '',
                    );
                    final rating = (item['vote_average'] as num?)?.toDouble();
                    final dateStr =
                        item['release_date'] ?? item['first_air_date'];
                    final year = dateStr != null
                        ? int.tryParse((dateStr as String).split('-')[0])
                        : null;

                    return Focus(
                      onKey: (node, event) {
                        if (event.isKeyPressed(LogicalKeyboardKey.select)) {
                          if (isMovie) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TvDetailsScreen(
                                  item: Movie.fromJson(item),
                                  mediaType: 'movie',
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TvSeriesScreen(
                                  seriesItem: Movie.fromJson(item),
                                ),
                              ),
                            );
                          }
                          return KeyEventResult.handled;
                        } else if (event.isKeyPressed(
                          LogicalKeyboardKey.arrowLeft,
                        )) {
                          if (index % 4 == 0) {
                            // At leftmost - return to sidebar
                            if (widget.onReturnToSidebar != null) {
                              widget.onReturnToSidebar!();
                            } else {
                              TvFocusManager.focusSidebar();
                              context
                                  .read<TvNavigationProvider>()
                                  .setFocusOnSidebar(true);
                            }
                          } else {
                            node.previousFocus();
                          }
                          return KeyEventResult.handled;
                        } else if (event.isKeyPressed(
                          LogicalKeyboardKey.arrowRight,
                        )) {
                          if (index % 4 < 3 &&
                              index < _contentByGenre.length - 1) {
                            node.nextFocus();
                          }
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TvContentCard(
                        posterUrl: posterUrl,
                        title: title,
                        contentType: isMovie
                            ? ContentType.movie
                            : ContentType.series,
                        rating: rating,
                        year: year,
                        onTap: () {
                          if (isMovie) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TvDetailsScreen(
                                  item: Movie.fromJson(item),
                                  mediaType: 'movie',
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TvSeriesScreen(
                                  seriesItem: Movie.fromJson(item),
                                ),
                              ),
                            );
                          }
                        },
                        width: 180,
                        height: 270,
                      ),
                    );
                  },
                  childCount: _contentByGenre.length + (_isLoadingMore ? 1 : 0),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: TvUtils.responsivePadding(32, context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenresHorizontalList(Map<int, String> genres) {
    final displayGenres = genres.entries.take(6).toList();

    return SizedBox(
      height: TvUtils.responsiveButtonHeight(context) * 1.2,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayGenres.length,
        itemBuilder: (context, index) {
          final genreId = displayGenres[index].key;
          final genreName = displayGenres[index].value;
          final isSelected = _selectedGenreId == genreId;

          return Padding(
            padding: EdgeInsets.only(
              right: TvUtils.responsivePadding(12, context),
            ),
            child: _buildGenreButton(
              genreId,
              genreName,
              isSelected: isSelected,
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenresGrid(Map<int, String> genres) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: TvUtils.responsivePadding(12, context),
        mainAxisSpacing: TvUtils.responsivePadding(12, context),
      ),
      itemCount: genres.length,
      itemBuilder: (context, index) {
        final genreId = genres.keys.toList()[index];
        final genreName = genres[genreId]!;
        final isSelected = _selectedGenreId == genreId;

        return _buildGenreButton(genreId, genreName, isSelected: isSelected);
      },
    );
  }

  Widget _buildGenreButton(
    int genreId,
    String genreName, {
    bool isSelected = false,
  }) {
    return Focus(
      onKey: (node, event) {
        if (event.isKeyPressed(LogicalKeyboardKey.select)) {
          _loadContentByGenre(genreId, genreName);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _loadContentByGenre(genreId, genreName);
        }
      },
      child: GestureDetector(
        onTap: () => _loadContentByGenre(genreId, genreName),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: TvUtils.responsivePadding(16, context),
            vertical: TvUtils.responsivePadding(10, context),
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE50914)
                : const Color(0xFF2A2A2A),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.grey[700]!,
              width: isSelected ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(
              TvUtils.responsivePadding(8, context),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              genreName,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[300],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: TvUtils.responsiveFontSize(14, context),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
