import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/movie.dart';
import '../providers/tv_navigation_provider.dart';
import '../widgets/tv_keyboard.dart';
import '../../widgets/custom_loading_widget.dart';
import '../utils/tv_typography.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_keyboard_focus_manager.dart';
import '../utils/tv_focus_manager.dart';
import '../utils/tv_navigation_handler.dart';
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

class _TvSearchScreenState extends State<TvSearchScreen> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _movieResults = [];
  List<Map<String, dynamic>> _seriesResults = [];
  List<Map<String, dynamic>> _trendingResults = [];
  List<Map<String, dynamic>> _popularResults = [];
  List<Map<String, dynamic>> _topRatedResults = [];
  bool _isLoading = false;
  bool _showNoResults = false;
  late TvKeyboardFocusManager _focusManager;
  late ScrollController _contentScrollController;
  static const int _columnsPerRow = 4;
  
  // Three-zone focus management (Netflix-style)
  late FocusNode _keyboardZoneFocusNode;
  late FocusNode _resultsZoneFocusNode;
  late List<FocusNode> _resultCardFocusNodes; // For individual cards

  @override
  void initState() {
    super.initState();
    _focusManager = TvKeyboardFocusManager();
    _contentScrollController = ScrollController();
    _focusManager.activateKeyboard();
    
    // Initialize focus zones
    _keyboardZoneFocusNode = FocusNode();
    _resultsZoneFocusNode = FocusNode();
    _resultCardFocusNodes = [];

    // Set search focus in navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TvNavigationProvider>().setSearchFocused(true);
      // Default focus to keyboard zone (Netflix pattern)
      _keyboardZoneFocusNode.requestFocus();
      
      _contentScrollController.addListener(() {
        context.read<TvNavigationProvider>().saveScrollOffset(
          1,
          _contentScrollController.offset,
        );
      });
    });

    _loadRecommendations();
  }

  @override
  void dispose() {
    _focusManager.dispose();
    _contentScrollController.dispose();
    _keyboardZoneFocusNode.dispose();
    _resultsZoneFocusNode.dispose();
    for (var node in _resultCardFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
  
  /// Ensure result focus nodes exist for dynamic content
  void _ensureResultFocusNodes(int count) {
    while (_resultCardFocusNodes.length < count) {
      final index = _resultCardFocusNodes.length;
      _resultCardFocusNodes.add(
        FocusNode(
          onKey: (node, event) => _handleResultCardKey(event, index),
        ),
      );
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
          _trendingResults = results[0].take(12).toList();
          _popularResults = results[1].take(12).toList();
          _topRatedResults = results[2].take(12).toList();
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
      setState(() {
        _searchResults = [];
        _movieResults = [];
        _seriesResults = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await TmdbApiService.searchAll(query);
      if (mounted) {
        // Separate movies and series
        final movies = results
            .where((item) => item['media_type'] == 'movie')
            .toList();
        final series = results
            .where((item) => item['media_type'] == 'tv')
            .toList();

        setState(() {
          _searchResults = [...movies, ...series];
          _movieResults = movies;
          _seriesResults = series;
          _showNoResults = _searchResults.isEmpty;
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

  /// Handle D-pad navigation within result cards
  KeyEventResult _handleResultCardKey(RawKeyEvent event, int index) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

    final currentResults = _searchQuery.isNotEmpty ? _movieResults : _trendingResults;
    final currentCol = index % _columnsPerRow;

    // LEFT: Move left or return to sidebar/keyboard
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (TvNavigation.isAtLeftBoundary(index, itemsPerRow: _columnsPerRow)) {
        // At leftmost - return to sidebar
        TvFocusManager.focusSidebar();
        return KeyEventResult.handled;
      }
      // Move to previous card in row
      if (index > 0) {
        _resultCardFocusNodes[index - 1].requestFocus();
        return KeyEventResult.handled;
      }
    }

    // RIGHT: Move right
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (index < currentResults.length - 1 && 
          currentCol < _columnsPerRow - 1) {
        _resultCardFocusNodes[index + 1].requestFocus();
        return KeyEventResult.handled;
      }
    }

    // UP: Move to previous row
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final upIndex = index - _columnsPerRow;
      if (upIndex >= 0) {
        _resultCardFocusNodes[upIndex].requestFocus();
        return KeyEventResult.handled;
      }
    }

    // DOWN: Move to next row
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final downIndex = index + _columnsPerRow;
      if (downIndex < currentResults.length) {
        _resultCardFocusNodes[downIndex].requestFocus();
        return KeyEventResult.handled;
      }
    }

    // SELECT: Navigate to content
    if (event.logicalKey == LogicalKeyboardKey.select) {
      _navigateToContent(currentResults[index]);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
        body: Consumer<TvNavigationProvider>(
          builder: (context, navProvider, _) {
            return Row(
              children: [
                // ZONE 1: Sidebar (handled by main screen)
                // Only shown when returning to sidebar - managed by parent
                
                // ZONE 2: Keyboard Panel (25% width)
                Focus(
                  focusNode: _keyboardZoneFocusNode,
                  onKey: (node, event) {
                    if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
                      // Jump to results
                      if (_resultCardFocusNodes.isNotEmpty) {
                        _resultCardFocusNodes[0].requestFocus();
                        return KeyEventResult.handled;
                      }
                    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
                      // Return to sidebar
                      navProvider.setFocusOnSidebar(true);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.25,
                    child: Padding(
                      padding: EdgeInsets.all(
                        TvUtils.responsivePadding(16, context),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            TvUtils.responsivePadding(12, context),
                          ),
                          border: Border.all(
                            color: _keyboardZoneFocusNode.hasFocus
                                ? Colors.white
                                : Colors.grey.withValues(alpha: 0.3),
                            width: _keyboardZoneFocusNode.hasFocus ? 3 : 1.5,
                          ),
                          boxShadow: _keyboardZoneFocusNode.hasFocus
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                  ),
                                ]
                              : [],
                        ),
                        padding: EdgeInsets.all(
                          TvUtils.responsivePadding(16, context),
                        ),
                        child: MouseRegion(
                          onEnter: (_) {
                            _keyboardZoneFocusNode.requestFocus();
                          },
                          child: SingleChildScrollView(
                            child: TvKeyboard(
                              initialText: _searchQuery,
                              onInput: _performSearch,
                              onSubmit: _submitSearch,
                              focusManager: _focusManager,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ZONE 3: Results Panel (expanded)
                Expanded(
                  child: Focus(
                    focusNode: _resultsZoneFocusNode,
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
                      } else if (event.isKeyPressed(
                        LogicalKeyboardKey.arrowDown,
                      )) {
                        if (_contentScrollController.offset <
                            _contentScrollController
                                .position
                                .maxScrollExtent) {
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
                    child: Padding(
                      padding: EdgeInsets.all(
                        TvUtils.responsivePadding(16, context),
                      ),
                      child: MouseRegion(
                        onEnter: (_) {
                          if (_resultCardFocusNodes.isNotEmpty) {
                            _resultCardFocusNodes[0].requestFocus();
                          }
                        },
                        child: _buildResultsView(navProvider),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultsView(TvNavigationProvider navProvider) {
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

      return CustomScrollView(
        controller: _contentScrollController,
        slivers: [
          // Movies Section
          if (_movieResults.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: TvUtils.responsivePadding(16, context),
                ),
                child: Text(
                  'Movies (${_movieResults.length})',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: TvUtils.responsiveFontSize(
                      18,
                      context,
                      maxSize: 24,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverGrid(
               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                 crossAxisCount: _columnsPerRow,
                 childAspectRatio: 0.6,
                 crossAxisSpacing: TvUtils.responsivePadding(12, context),
                 mainAxisSpacing: TvUtils.responsivePadding(12, context),
               ),
               delegate: SliverChildBuilderDelegate((context, index) {
                 final item = _movieResults[index];
                 // Ensure focus nodes exist
                 _ensureResultFocusNodes(_movieResults.length);
                 
                 return Focus(
                   focusNode: _resultCardFocusNodes[index],
                   child: _buildResultCard(item),
                 );
                 }, childCount: _movieResults.length),
                 ),
                 SliverToBoxAdapter(
                 child: SizedBox(height: TvUtils.responsivePadding(32, context)),
                 ),
                 ],

                 // Series Section
                 if (_seriesResults.isNotEmpty) ...[
                 SliverToBoxAdapter(
                 child: Padding(
                 padding: EdgeInsets.only(
                   bottom: TvUtils.responsivePadding(16, context),
                 ),
                 child: Text(
                   'TV Series (${_seriesResults.length})',
                   style: TextStyle(
                     color: Colors.white,
                     fontSize: TvUtils.responsiveFontSize(
                       18,
                       context,
                       maxSize: 24,
                     ),
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 ),
                 ),
                 SliverGrid(
                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                 crossAxisCount: _columnsPerRow,
                 childAspectRatio: 0.6,
                 crossAxisSpacing: TvUtils.responsivePadding(12, context),
                 mainAxisSpacing: TvUtils.responsivePadding(12, context),
                 ),
                 delegate: SliverChildBuilderDelegate((context, index) {
                 final item = _seriesResults[index];
                 // Ensure focus nodes exist (series uses same nodes as movies)
                 _ensureResultFocusNodes(_seriesResults.length);
                 
                 return Focus(
                   focusNode: _resultCardFocusNodes[index],
                   child: _buildResultCard(item),
                 );
               }, childCount: _seriesResults.length),
             ),
            SliverToBoxAdapter(
              child: SizedBox(height: TvUtils.responsivePadding(32, context)),
            ),
          ],
        ],
      );
    }

    // Show recommendations when search is empty
    return CustomScrollView(
      controller: _contentScrollController,
      slivers: [
        // Trending Section
        if (_trendingResults.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: TvUtils.responsivePadding(16, context),
              ),
              child: Text(
                'Trending Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: TvUtils.responsiveFontSize(
                    18,
                    context,
                    maxSize: 24,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columnsPerRow,
              childAspectRatio: 0.6,
              crossAxisSpacing: TvUtils.responsivePadding(12, context),
              mainAxisSpacing: TvUtils.responsivePadding(12, context),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildResultCard(_trendingResults[index]),
              childCount: _trendingResults.length,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: TvUtils.responsivePadding(32, context)),
          ),
        ],

        // Popular Section
        if (_popularResults.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: TvUtils.responsivePadding(16, context),
              ),
              child: Text(
                'Popular',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: TvUtils.responsiveFontSize(
                    18,
                    context,
                    maxSize: 24,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columnsPerRow,
              childAspectRatio: 0.6,
              crossAxisSpacing: TvUtils.responsivePadding(12, context),
              mainAxisSpacing: TvUtils.responsivePadding(12, context),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildResultCard(_popularResults[index]),
              childCount: _popularResults.length,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: TvUtils.responsivePadding(32, context)),
          ),
        ],

        // Top Rated Section
        if (_topRatedResults.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: TvUtils.responsivePadding(16, context),
              ),
              child: Text(
                'Top Rated',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: TvUtils.responsiveFontSize(
                    18,
                    context,
                    maxSize: 24,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columnsPerRow,
              childAspectRatio: 0.6,
              crossAxisSpacing: TvUtils.responsivePadding(12, context),
              mainAxisSpacing: TvUtils.responsivePadding(12, context),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildResultCard(_topRatedResults[index]),
              childCount: _topRatedResults.length,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: TvUtils.responsivePadding(32, context)),
          ),
        ],
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
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
      onTap: () => _navigateToContent(result),
      width: 160,
      height: 240,
    );
  }
}
