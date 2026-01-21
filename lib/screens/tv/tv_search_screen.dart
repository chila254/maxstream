import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/movie.dart';
import '../../widgets/tv_keyboard.dart';
import '../../widgets/custom_loading_widget.dart';
import '../../widgets/tv_focus_widget.dart';
import '../../utils/tv_utils.dart';
import '../../utils/tv_dpad_navigation_mixin.dart';
import '../../services/tmdb_api_service.dart';
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
      print('Error loading recommendations: $e');
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
      print('Search error: $e');
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

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex {
    if (_keyboardFocused) return 0;

    // Get the current items being displayed
    final items = _searchQuery.isNotEmpty
        ? _searchResults
        : _getTotalRecommendations();
    return items.length - 1;
  }

  List<Map<String, dynamic>> _getTotalRecommendations() {
    return [..._trendingResults, ..._popularResults, ..._topRatedResults];
  }

  @override
  void onFocusChanged(int index) {
    if (!_keyboardFocused) {
      setState(() => _focusedResultIndex = index);
    }
  }

  @override
  void onSelectPressed() {
    if (_keyboardFocused) {
      // Keyboard is focused, submit search
      _submitSearch();
    } else if (_focusedResultIndex != null) {
      final items = _searchQuery.isNotEmpty
          ? _searchResults
          : _getTotalRecommendations();
      if (_focusedResultIndex! < items.length) {
        final item = items[_focusedResultIndex!];
        _navigateToContent(item);
      }
    }
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
  void onLeftPressed() {
    if (!_keyboardFocused && _focusedResultIndex != null) {
      // Always switch to keyboard focus when pressing left on results
      setState(() {
        _keyboardFocused = true;
        _focusedResultIndex = null;
      });
    } else if (_keyboardFocused && widget.onReturnToSidebar != null) {
      // On keyboard, left arrow returns to sidebar
      widget.onReturnToSidebar!();
    }
  }

  @override
  void handleKeyEvent(RawKeyEvent event) {
    if (_keyboardFocused) {
      // Allow right arrow to switch from keyboard to results
      if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
        onRightPressed();
      }
    } else {
      if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
        _moveDown();
      } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
        _moveUp();
      } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
        onLeftPressed();
      } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
        onRightPressed();
      } else if (event.isKeyPressed(LogicalKeyboardKey.select) ||
          event.isKeyPressed(LogicalKeyboardKey.enter)) {
        onSelectPressed();
      }
    }
  }

  void _moveDown() {
    if (_focusedResultIndex == null) return;
    final items = _searchQuery.isNotEmpty
        ? _searchResults
        : _getTotalRecommendations();
    int newIndex = _focusedResultIndex! + _columnsPerRow;
    if (newIndex < items.length) {
      setState(() => _focusedResultIndex = newIndex);
      onFocusChanged(newIndex);
    }
  }

  void _moveUp() {
    if (_focusedResultIndex == null) return;
    int newIndex = _focusedResultIndex! - _columnsPerRow;
    if (newIndex >= 0) {
      setState(() => _focusedResultIndex = newIndex);
      onFocusChanged(newIndex);
    }
  }

  @override
  void onRightPressed() {
    if (_keyboardFocused) {
      // Switch from keyboard to recommendations/search results
      setState(() {
        _keyboardFocused = false;
        _focusedResultIndex = 0;
      });
      onFocusChanged(0);
    } else if (_focusedResultIndex != null) {
      // Navigate right within grid (next item)
      final items = _searchQuery.isNotEmpty
          ? _searchResults
          : _getTotalRecommendations();
      if (_focusedResultIndex! < items.length - 1) {
        setState(() => _focusedResultIndex = _focusedResultIndex! + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      onKey: handleKeyEvent,
      focusNode: focusNode,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(
            'Search',
            style: TextStyle(
              fontSize: TvUtils.responsiveFontSize(32, context, maxSize: 48),
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              size: TvUtils.responsiveFontSize(28, context, maxSize: 40),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Row(
          children: [
            // Left side: Keyboard - narrow and tall
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.3,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: TvUtils.responsivePadding(12, context),
                  vertical: TvUtils.responsivePadding(24, context),
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
            Text(
              'Searching...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: TvUtils.responsiveFontSize(16, context),
              ),
            ),
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
            style: TextStyle(
              color: Colors.grey,
              fontSize: TvUtils.responsiveFontSize(16, context),
            ),
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
    final posterPath = result['poster_path'];
    final title = result['media_type'] == 'tv'
        ? (result['name'] ?? 'Unknown')
        : (result['title'] ?? 'Unknown');

    final cardWidth = TvUtils.responsiveButtonHeight(context) * 2;
    final cardHeight = cardWidth * 1.5;

    return TvContentFocusCard(
      isFocused: isFocused,
      scale: 1.12,
      onTap: () {
        _navigateToContent(result);
      },
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(
            TvUtils.responsivePadding(12, context),
          ),
          border: Border.all(color: Colors.grey[700]!, width: 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _navigateToContent(result);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Poster image
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(
                        TvUtils.responsivePadding(10, context),
                      ),
                      topRight: Radius.circular(
                        TvUtils.responsivePadding(10, context),
                      ),
                    ),
                    child: posterPath != null
                        ? Image.network(
                            TmdbApiService.getPosterUrl(posterPath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                  ),
                ),
                // Title and year
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.all(
                      TvUtils.responsivePadding(8, context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: TvUtils.responsiveFontSize(
                                12,
                                context,
                                maxSize: 16,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
