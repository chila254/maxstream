import 'package:flutter/material.dart';
import '../../widgets/tv_keyboard.dart';
import '../../utils/tv_utils.dart';
import '../../services/tmdb_api_service.dart';

class TvSearchScreen extends StatefulWidget {
  const TvSearchScreen({super.key});

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _showNoResults = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(TvUtils.responsivePadding(32, context)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Keyboard
              Expanded(
                flex: 1,
                child: TvKeyboard(
                  initialText: _searchQuery,
                  onInput: _performSearch,
                  onSubmit: _submitSearch,
                ),
              ),

              SizedBox(width: TvUtils.responsivePadding(48, context)),

              // Right: Search Results
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'Results',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TvUtils.responsiveFontSize(
                          24,
                          context,
                          maxSize: 36,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: TvUtils.responsivePadding(24, context)),
                    if (_isLoading)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(
                            TvUtils.responsivePadding(32, context),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFE50914),
                                ),
                              ),
                              SizedBox(
                                height: TvUtils.responsivePadding(16, context),
                              ),
                              Text(
                                'Searching...',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: TvUtils.responsiveFontSize(
                                    16,
                                    context,
                                    maxSize: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_showNoResults || _searchResults.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(
                            TvUtils.responsivePadding(32, context),
                          ),
                          child: Text(
                            'No results found for "$_searchQuery"',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: TvUtils.responsiveFontSize(
                                16,
                                context,
                                maxSize: 24,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: TvUtils.responsivePadding(16, context),
                        runSpacing: TvUtils.responsivePadding(16, context),
                        children: [
                          for (final result in _searchResults)
                            _buildResultCard(result),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final posterPath = result['poster_path'];
    final title = result['media_type'] == 'tv'
        ? (result['name'] ?? 'Unknown')
        : (result['title'] ?? 'Unknown');
    final year = result['media_type'] == 'tv'
        ? (result['first_air_date']?.toString().split('-')[0] ?? '')
        : (result['release_date']?.toString().split('-')[0] ?? '');

    final cardWidth = TvUtils.responsiveButtonHeight(context) * 2;
    final cardHeight = cardWidth * 1.5;

    return GestureDetector(
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
