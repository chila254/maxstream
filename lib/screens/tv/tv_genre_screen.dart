import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/tmdb_api_service.dart';
import '../../utils/tv_utils.dart';
import '../../utils/tv_dpad_navigation_mixin.dart';
import '../../widgets/custom_loading_widget.dart';

class TvGenreScreen extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;

  const TvGenreScreen({super.key, this.onReturnToSidebar});

  @override
  State<TvGenreScreen> createState() => _TvGenreScreenState();
}

class _TvGenreScreenState extends State<TvGenreScreen>
    with TvDpadNavigationMixin {
  Map<int, String> _movieGenres = {};
  Map<int, String> _tvGenres = {};
  bool _isLoadingGenres = false;
  int? _selectedGenreId;
  String? _selectedGenreType; // 'movie' or 'tv'
  String? _selectedGenreName;
  List<Map<String, dynamic>> _contentByGenre = [];
  bool _isLoadingContent = false;
  bool _showDetailView = false;
  int _contentPage = 1;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;
  static const int _columnsPerRow = 3;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadGenres();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex => _showDetailView
      ? (_contentByGenre.isNotEmpty ? _contentByGenre.length - 1 : 0)
      : (_movieGenres.length + _tvGenres.length - 1).clamp(0, 100);

  @override
  void onFocusChanged(int index) {
    setState(() {
      if (!_showDetailView) {
        // Genre selection
      } else {
        // Content selection
      }
    });
  }

  @override
  void onSelectPressed() {
    // Selection handled by genre/content cards
  }

  @override
  void onLeftPressed() {
    if (_showDetailView) {
      final currentFocus = getFocusIndex();
      if (currentFocus > 0 && currentFocus % _columnsPerRow != 0) {
        // Navigate left within grid
        setFocusIndex(currentFocus - 1);
      } else if (currentFocus % _columnsPerRow == 0 && widget.onReturnToSidebar != null) {
        // At leftmost column: return to sidebar
        widget.onReturnToSidebar!();
      }
    }
  }

  @override
  void onRightPressed() {
    if (_showDetailView) {
      final currentFocus = getFocusIndex();
      if (currentFocus + 1 < _contentByGenre.length &&
          (currentFocus + 1) % _columnsPerRow != 0) {
        setFocusIndex(currentFocus + 1);
      }
    }
  }

  @override
  void handleKeyEvent(RawKeyEvent event) {
    if (_showDetailView) {
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
    } else {
      super.handleKeyEvent(event);
    }
  }

  void _moveDown() {
    final currentFocus = getFocusIndex();
    int newIndex = currentFocus + _columnsPerRow;
    if (newIndex < _contentByGenre.length) {
      setFocusIndex(newIndex);
    }
  }

  void _moveUp() {
    final currentFocus = getFocusIndex();
    int newIndex = currentFocus - _columnsPerRow;
    if (newIndex >= 0) {
      setFocusIndex(newIndex);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _showDetailView &&
        _selectedGenreId != null &&
        _selectedGenreType != null) {
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
      print('Error loading genres: $e');
      if (mounted) {
        setState(() => _isLoadingGenres = false);
      }
    }
  }

  Future<void> _loadContentByGenre(
    int genreId,
    String type,
    String name,
  ) async {
    setState(() {
      _selectedGenreId = genreId;
      _selectedGenreType = type;
      _selectedGenreName = name;
      _showDetailView = true;
      _contentPage = 1;
      _contentByGenre = [];
      _isLoadingContent = true;
    });

    await _fetchGenreContent();
  }

  Future<void> _fetchGenreContent() async {
    if (_selectedGenreId == null || _selectedGenreType == null) return;

    try {
      late List<Map<String, dynamic>> results;

      if (_selectedGenreType == 'movie') {
        results = await TmdbApiService.getMoviesByGenre(
          _selectedGenreId!,
          page: _contentPage,
        );
      } else {
        results = await TmdbApiService.getSeriesByGenre(
          _selectedGenreId!,
          page: _contentPage,
        );
      }

      if (mounted) {
        setState(() {
          if (_contentPage == 1) {
            _contentByGenre = results;
          } else {
            _contentByGenre.addAll(results);
          }
          _isLoadingContent = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error fetching genre content: $e');
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreContent() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _contentPage++;
    await _fetchGenreContent();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      onKey: handleKeyEvent,
      focusNode: focusNode,
      child: _showDetailView ? _buildDetailView() : _buildGenreListView(),
    );
  }

  Widget _buildGenreListView() {
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
            Text(
              'Loading genres...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: TvUtils.responsiveFontSize(16, context),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movies Genres
            _buildGenreSection('Movies', _movieGenres, 'movie'),
            SizedBox(height: TvUtils.responsivePadding(48, context)),

            // TV Series Genres
            _buildGenreSection('TV Series', _tvGenres, 'tv'),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreSection(
    String title,
    Map<int, String> genres,
    String type,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: TvUtils.responsiveFontSize(24, context, maxSize: 36),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: TvUtils.responsivePadding(16, context)),
        SizedBox(
          height: TvUtils.responsiveButtonHeight(context) * 1.2,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: genres.length,
            itemBuilder: (context, index) {
              final genreId = genres.keys.toList()[index];
              final genreName = genres[genreId]!;

              return Padding(
                padding: EdgeInsets.only(
                  right: TvUtils.responsivePadding(16, context),
                ),
                child: _buildGenreButton(genreId, genreName, type),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenreButton(int genreId, String genreName, String type) {
    return GestureDetector(
      onTap: () => _loadContentByGenre(genreId, type, genreName),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: TvUtils.responsivePadding(20, context),
          vertical: TvUtils.responsivePadding(12, context),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          border: Border.all(color: Colors.grey[700]!, width: 2),
          borderRadius: BorderRadius.circular(
            TvUtils.responsivePadding(8, context),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _loadContentByGenre(genreId, type, genreName),
            child: Center(
              child: Text(
                genreName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: TvUtils.responsiveFontSize(
                    16,
                    context,
                    maxSize: 24,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    return WillPopScope(
      onWillPop: () async {
        setState(() => _showDetailView = false);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            _selectedGenreName ?? 'Genre',
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(24, context, maxSize: 36),
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              size: TvUtils.responsiveFontSize(24, context, maxSize: 36),
            ),
            onPressed: () => setState(() => _showDetailView = false),
          ),
          elevation: 0,
        ),
        body: _isLoadingContent
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CustomLoadingWidget(
                      size: 40,
                      color: Color(0xFFE50914),
                      style: LoadingStyle.dots,
                    ),
                    SizedBox(height: TvUtils.responsivePadding(16, context)),
                    Text(
                      'Loading content...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: TvUtils.responsiveFontSize(16, context),
                      ),
                    ),
                  ],
                ),
              )
            : _contentByGenre.isEmpty
            ? Center(
                child: Text(
                  'No content found for this genre',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: TvUtils.responsiveFontSize(16, context),
                  ),
                ),
              )
            : GridView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(TvUtils.responsivePadding(16, context)),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.6,
                  crossAxisSpacing: TvUtils.responsivePadding(16, context),
                  mainAxisSpacing: TvUtils.responsivePadding(16, context),
                ),
                itemCount: _contentByGenre.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
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
                  final posterPath = item['poster_path'];
                  final title = _selectedGenreType == 'tv'
                      ? (item['name'] ?? 'Unknown')
                      : (item['title'] ?? 'Unknown');
                  final year = _selectedGenreType == 'tv'
                      ? (item['first_air_date']?.toString().split('-')[0] ?? '')
                      : (item['release_date']?.toString().split('-')[0] ?? '');

                  return GestureDetector(
                    onTap: () {
                      // Navigate to detail screen if needed
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              TvUtils.responsivePadding(8, context),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  TvUtils.responsivePadding(8, context),
                                ),
                              ),
                              child: posterPath != null
                                  ? Image.network(
                                      TmdbApiService.getPosterUrl(posterPath),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[800],
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                    )
                                  : Container(
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(height: TvUtils.responsivePadding(8, context)),
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: TvUtils.responsiveFontSize(
                              12,
                              context,
                              maxSize: 16,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (year.isNotEmpty)
                          Text(
                            year,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: TvUtils.responsiveFontSize(
                                10,
                                context,
                                maxSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
