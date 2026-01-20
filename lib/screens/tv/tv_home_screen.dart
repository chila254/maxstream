import 'package:flutter/material.dart';
import '../../utils/tv_utils.dart';
import 'tv_search_screen.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  final List<Map<String, dynamic>> _categories = [
    {
      'title': 'Trending',
      'items': [
        'Squid Game',
        'The Mandalorian',
        'Breaking Bad',
        'Stranger Things'
      ]
    },
    {
      'title': 'Movies',
      'items': ['Inception', 'Interstellar', 'The Dark Knight', 'Oppenheimer']
    },
    {
      'title': 'Series',
      'items': ['Game of Thrones', 'The Crown', 'Chernobyl', 'Westworld']
    },
    {
      'title': 'Watchlist',
      'items': ['Money Heist', 'The Witcher', 'Ozark', 'Euphoria']
    },
  ];

  void _openSearch() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const TvSearchScreen(),
      ),
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected: $result'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'MaxStream TV',
          style: TextStyle(
            fontSize: TvUtils.responsiveFontSize(32, context, maxSize: 48),
            color: const Color(0xFFE50914),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              size: TvUtils.responsiveFontSize(28, context, maxSize: 40),
            ),
            onPressed: _openSearch,
          ),
          SizedBox(width: TvUtils.responsivePadding(16, context)),
          IconButton(
            icon: Icon(
              Icons.account_circle,
              size: TvUtils.responsiveFontSize(28, context, maxSize: 40),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile')),
              );
            },
          ),
          SizedBox(width: TvUtils.responsivePadding(16, context)),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(TvUtils.responsivePadding(32, context)),
        children: [
          for (int index = 0; index < _categories.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: TvUtils.responsivePadding(48, context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categories[index]['title'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: TvUtils.responsiveFontSize(
                        28,
                        context,
                        maxSize: 40,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: TvUtils.responsivePadding(24, context)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in _categories[index]['items'] as List)
                          Padding(
                            padding: EdgeInsets.only(
                              right: TvUtils.responsivePadding(24, context),
                            ),
                            child: _buildContentCard(item),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContentCard(String title) {
    final cardWidth = TvUtils.responsiveButtonHeight(context) * 3;
    final cardHeight = cardWidth * 1.5;

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing: $title'),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      },
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(
            TvUtils.responsivePadding(12, context),
          ),
          border: Border.all(color: Colors.grey[700]!, width: 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playing: $title'),
                  backgroundColor: const Color(0xFFE50914),
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: TvUtils.responsiveFontSize(64, context, maxSize: 100),
                ),
                SizedBox(height: TvUtils.responsivePadding(16, context)),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: TvUtils.responsivePadding(12, context),
                  ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
