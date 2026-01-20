import 'package:flutter/material.dart';
import '../../widgets/tv_keyboard.dart';
import '../../utils/tv_utils.dart';

class TvSearchScreen extends StatefulWidget {
  const TvSearchScreen({super.key});

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  String _searchQuery = '';
  List<String> _searchResults = [];

  // Mock data for demonstration
  final List<String> _allContent = [
    'Inception',
    'Interstellar',
    'The Dark Knight',
    'Breaking Bad',
    'Game of Thrones',
    'The Crown',
    'Stranger Things',
    'The Mandalorian',
    'Squid Game',
    'Money Heist',
    'Chernobyl',
    'Westworld',
    'The Witcher',
    'Ozark',
    'The Office',
    'Friends',
    'The Boys',
    'Euphoria',
  ];

  @override
  void initState() {
    super.initState();
    _searchResults = _allContent;
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;

      if (query.isEmpty) {
        _searchResults = _allContent;
      } else {
        _searchResults = _allContent
            .where(
              (item) => item.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _submitSearch() {
    if (_searchQuery.isEmpty) return;

    // Navigate to search results or filter content
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
                    if (_searchResults.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(
                            TvUtils.responsivePadding(32, context),
                          ),
                          child: Text(
                            'No results found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: TvUtils.responsiveFontSize(
                                16,
                                context,
                                maxSize: 24,
                              ),
                            ),
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

  Widget _buildResultCard(String title) {
    final cardSize = TvUtils.responsiveButtonHeight(context) * 3;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context, title);
      },
      child: Container(
        width: cardSize,
        height: cardSize * 0.6,
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
              Navigator.pop(context, title);
            },
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(TvUtils.responsivePadding(12, context)),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: TvUtils.responsiveFontSize(
                      16,
                      context,
                      maxSize: 28,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
