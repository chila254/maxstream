import 'package:flutter/material.dart';
import '../../models/movie.dart';
import '../widgets/tv_keyboard.dart';
import '../../widgets/custom_loading_widget.dart';
import '../utils/tv_typography.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_dpad_navigation_mixin.dart';
import '../../services/tmdb_api_service.dart';
import '../widgets/tv_dark_mode_polish.dart';
import '../widgets/tv_content_card.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';

class TvSearchScreen extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;

  const TvSearchScreen({super.key, this.onReturnToSidebar});

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen>
    with TvDpadNavigationMixin {
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _trendingResults = [];
  List<Map<String, dynamic>> _popularResults = [];
  List<Map<String, dynamic>> _topRatedResults = [];
  bool _isLoading = false;
  bool _showNoResults = false;
  int? _focusedResultIndex;
  bool _keyboardFocused = true;
  static const int _columnsPerRow = 5;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex {
    final items = _searchQuery.isNotEmpty
        ? _searchResults
        : [..._trendingResults, ..._popularResults, ..._topRatedResults];
    return items.isEmpty ? 0 : items.length - 1;
  }

  @override
  void onFocusChanged(int index) {
    setState(() => _focusedResultIndex = index);
  }

  @override
  void onSelectPressed() {
    if (_focusedResultIndex != null) {
      final items = _searchQuery.isNotEmpty
          ? _searchResults
          : [..._trendingResults, ..._popularResults, ..._topRatedResults];
      if (_focusedResultIndex! < items.length) {
        _navigateToContent(items[_focusedResultIndex!]);
      }
    }
  }

  @override
  void onLeftPressed() {
    if (_keyboardFocused) {
      // If keyboard is focused and at leftmost position, return to sidebar
      if (widget.onReturnToSidebar != null) {
        widget.onReturnToSidebar!();
      }
    } else if (_focusedResultIndex != null) {
      if (_focusedResultIndex! > 0 &&
          _focusedResultIndex! % _columnsPerRow != 0) {
        setFocusIndex(_focusedResultIndex! - 1);
      } else if (_focusedResultIndex! % _columnsPerRow == 0 &&
          widget.onReturnToSidebar != null) {
        widget.onReturnToSidebar!();
      }
    }
  }

  @override
  void onRightPressed() {
    if (_focusedResultIndex != null) {
      final items = _searchQuery.isNotEmpty
          ? _searchResults
          : [..._trendingResults, ..._popularResults, ..._topRatedResults];
      if (_focusedResultIndex! + 1 < items.length &&
          (_focusedResultIndex! + 1) % _columnsPerRow != 0) {
        setFocusIndex(_focusedResultIndex! + 1);
      }
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final results = await Future.wait([
        TmdbApiService.fetchTrendingMovies(),
        TmdbApiService.fetchPopularMovies(),
        TmdbApiService.fetchTopRatedMovies(),
      ]);

      if (mounted) {
        setState(() {
          // Split 25 total items across 3 categories: 9 + 8 + 8
          _trendingResults = results[0].take(9).toList();
          _popularResults = results[1].take(8).toList();
          _topRatedResults = results[2].take(8).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _searchQuery = query;
      _showNoResults = false;
    });

    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await TmdbApiService.searchAll(query);
      if (mounted) {
        // Filter to only movies and series, exclude people
        final filtered = results
            .where(
              (item) =>
                  item['media_type'] == 'movie' || item['media_type'] == 'tv',
            )
            .toList();

        setState(() {
          _searchResults = filtered;
          _showNoResults = filtered.isEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showNoResults = true;
        });
      }
    }
  }

  void _submitSearch() {
    if (_searchQuery.isEmpty) return;
    Navigator.pop(context, _searchQuery);
  }

  void _navigateToContent(Map<String, dynamic> item) {
    final isMovie = item['media_type'] == 'movie';

    if (isMovie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TvDetailsScreen(item: Movie.fromJson(item), mediaType: 'movie'),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TvSeriesScreen(seriesItem: Movie.fromJson(item)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DarkModeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: DarkModeAppBar(
            title: '',
            onBackPressed: null,
          ),
        ),
        body: Column(
          children: [
            // Search Content
            Expanded(
              child: Row(
                children: [
                  // Left side: Keyboard - narrow and tall
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: TvUtils.responsivePadding(12, context),
                        vertical: TvUtils.responsivePadding(12, context),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            TvUtils.responsivePadding(12, context),
                          ),
                          border: Border.all(
                            color: _keyboardFocused
                                ? Colors.white
                                : Colors.grey.withValues(alpha: 0.3),
                            width: _keyboardFocused ? 2 : 1.5,
                          ),
                        ),
                        padding: EdgeInsets.all(
                          TvUtils.responsivePadding(12, context),
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() => _keyboardFocused = true),
                          child: SingleChildScrollView(
                            child: TvKeyboard(
                              initialText: _searchQuery,
                              onInput: _performSearch,
                              onSubmit: _submitSearch,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Right side: Results section (6 columns)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: TvUtils.responsivePadding(24, context),
                        vertical: TvUtils.responsivePadding(24, context),
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _keyboardFocused = false),
                        child: _buildResultsView(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CustomLoadingWidget(
              size: 50,
              color: Color(0xFFE50914),
              style: LoadingStyle.dots,
            ),
            SizedBox(height: TvUtils.responsivePadding(16, context)),
            Text('Searching...', style: TvTypography.bodyMedium),
          ],
        ),
      );
    }

    // Show search results if query is not empty
    if (_searchQuery.isNotEmpty) {
      if (_showNoResults || _searchResults.isEmpty) {
        return Center(
          child: Text(
            'No results found for "$_searchQuery"',
            style: TvTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        );
      }

      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnsPerRow,
          childAspectRatio: 0.6,
          crossAxisSpacing: TvUtils.responsivePadding(12, context),
          mainAxisSpacing: TvUtils.responsivePadding(12, context),
        ),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) => _buildResultCard(
          _searchResults[index],
          isFocused: _focusedResultIndex == index,
        ),
      );
    }

    // Show recommendations when search is empty (5x5 grid = 25 items)
    final allRecommendations = [
      ..._trendingResults,
      ..._popularResults,
      ..._topRatedResults,
    ];

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columnsPerRow,
        childAspectRatio: 0.6,
        crossAxisSpacing: TvUtils.responsivePadding(12, context),
        mainAxisSpacing: TvUtils.responsivePadding(12, context),
      ),
      itemCount: allRecommendations.length,
      itemBuilder: (context, index) => _buildResultCard(
        allRecommendations[index],
        isFocused: _focusedResultIndex == index,
      ),
    );
  }

  Widget _buildResultCard(
    Map<String, dynamic> result, {
    bool isFocused = false,
  }) {
    final title = result['media_type'] == 'tv'
        ? (result['name'] ?? 'Unknown')
        : (result['title'] ?? 'Unknown');

    final isMovie = result['media_type'] == 'movie';
    final posterUrl = TmdbApiService.getPosterUrl(result['poster_path'] ?? '');
    final rating = (result['vote_average'] as num?)?.toDouble();
    final dateStr = isMovie
        ? (result['release_date'] as String?)
        : (result['first_air_date'] as String?);
    final year = dateStr != null ? int.tryParse(dateStr.split('-')[0]) : null;

    return TvContentCard(
      posterUrl: posterUrl,
      title: title,
      contentType: isMovie ? ContentType.movie : ContentType.series,
      rating: rating,
      year: year,
      isFocused: isFocused,
      onTap: () => _navigateToContent(result),
      width: 180,
      height: 270,
    );
  }
}
