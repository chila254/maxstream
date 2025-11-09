import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../screens/onstream_details_screen.dart';
import '../screens/onstream_series_screen.dart';
import '../utils/responsive_utils.dart';

class MovieSlider extends StatefulWidget {
  final String title;
  final Future<List<Movie>> Function({int page}) apiCall;

  const MovieSlider({
    super.key,
    required this.title,
    required this.apiCall,
  });

  @override
  State<MovieSlider> createState() => _MovieSliderState();
}

class _MovieSliderState extends State<MovieSlider> {
  List<Movie> items = [];
  int page = 1;
  bool isLoading = false;
  bool hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _fetchItems() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    try {
      final newItems = await widget.apiCall(page: page);
      setState(() {
        if (newItems.isEmpty) {
          hasMore = false;
        } else {
          items.addAll(newItems);
          page++;
        }
      });
    } catch (e) {
      print('Error fetching ${widget.title}: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchItems();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToDetails(Movie item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => item.mediaType == 'tv'
            ? OnStreamSeriesScreen(seriesItem: item)
            : OnStreamDetailsScreen(item: item, mediaType: item.mediaType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getHorizontalPadding(context),
            vertical: ResponsiveUtils.getSpacing(context, mobile: 10),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveUtils.getFontSize(context, mobile: 18),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: ResponsiveUtils.getCardHeight(context) + 40,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: items.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return const Center(
                  child: SizedBox(
                    width: 60,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final item = items[index];
              final imageUrl = item.thumbnail;
              final title = item.title;
              final cardWidth = ResponsiveUtils.getCardWidth(context);
              final cardHeight = ResponsiveUtils.getCardHeight(context);

              return GestureDetector(
                onTap: () => _navigateToDetails(item),
                child: Container(
                  width: cardWidth,
                  margin: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getGridSpacing(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.isTablet(context) || ResponsiveUtils.isDesktop(context) ? 12 : 8,
                            ),
                            child: Image.network(
                              imageUrl,
                              height: cardHeight,
                              width: cardWidth,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: cardHeight,
                                width: cardWidth,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                          // All content is streamable
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 4)),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.getFontSize(context, mobile: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
