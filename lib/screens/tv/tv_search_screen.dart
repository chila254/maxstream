import 'package:flutter/material.dart';
import '../../widgets/tv_keyboard.dart';
import '../../widgets/custom_loading_widget.dart';
import '../../widgets/tv_focus_widget.dart';
import '../../utils/tv_utils.dart';
import '../../utils/tv_dpad_navigation_mixin.dart';
import '../../services/tmdb_api_service.dart';

class TvSearchScreen extends StatefulWidget {
  const TvSearchScreen({super.key});

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen>
    with TvDpadNavigationMixin {
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _showNoResults = false;
  int? _focusedResultIndex;
  bool _keyboardFocused = true;
  static const int _columnsPerRow = 6;

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
  int get maxFocusIndex => _keyboardFocused ? 0 : (_searchResults.length - 1);

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
    } else if (_focusedResultIndex != null &&
        _focusedResultIndex! < _searchResults.length) {
      final item = _searchResults[_focusedResultIndex!];
      Navigator.pop(context, item);
    }
  }

  @override
  void onLeftPressed() {
    if (!_keyboardFocused &&
        _focusedResultIndex != null &&
        _focusedResultIndex! > 0) {
      setState(() => _focusedResultIndex = _focusedResultIndex! - 1);
    }
  }

  @override
  void onRightPressed() {
    if (!_keyboardFocused &&
        _focusedResultIndex != null &&
        _focusedResultIndex! < _searchResults.length - 1) {
      setState(() => _focusedResultIndex = _focusedResultIndex! + 1);
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
              width: MediaQuery.of(context).size.width * 0.15,
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

    if (_showNoResults || _searchResults.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? 'Start typing to search'
              : 'No results found for "$_searchQuery"',
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

  Widget _buildResultCard(
    Map<String, dynamic> result, {
    bool isFocused = false,
  }) {
    final posterPath = result['poster_path'];
    final title = result['media_type'] == 'tv'
        ? (result['name'] ?? 'Unknown')
        : (result['title'] ?? 'Unknown');
    final year = result['media_type'] == 'tv'
        ? (result['first_air_date']?.toString().split('-')[0] ?? '')
        : (result['release_date']?.toString().split('-')[0] ?? '');

    final cardWidth = TvUtils.responsiveButtonHeight(context) * 2;
    final cardHeight = cardWidth * 1.5;

    return TvContentFocusCard(
      isFocused: isFocused,
      scale: 1.12,
      onTap: () {
        Navigator.pop(context, result);
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
              Navigator.pop(context, result);
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
