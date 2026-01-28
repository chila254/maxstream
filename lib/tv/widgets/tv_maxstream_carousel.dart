import 'package:flutter/material.dart';
import '../../services/tmdb_api_service.dart';

/// MaxStream Netflix-style horizontal carousel
/// Smooth scrolling with focus management
class TvMaxStreamCarousel extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Function(int)? onItemSelected;
  final Function(int)? onFocusChanged;
  final int? focusedIndex;

  const TvMaxStreamCarousel({
    super.key,
    required this.title,
    required this.items,
    this.onItemSelected,
    this.onFocusChanged,
    this.focusedIndex,
  });

  @override
  State<TvMaxStreamCarousel> createState() => _TvMaxStreamCarouselState();
}

class _TvMaxStreamCarouselState extends State<TvMaxStreamCarousel> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(TvMaxStreamCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedIndex != oldWidget.focusedIndex &&
        widget.focusedIndex != null) {
      _scrollToFocused();
    }
  }

  void _scrollToFocused() {
    if (widget.focusedIndex == null) return;

    final itemWidth = 142.0; // 130 + 12 spacing
    final offset = (widget.focusedIndex! * itemWidth) - 100;

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isFocused = widget.focusedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildCarouselItem(item, isFocused),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(Map<String, dynamic> item, bool isFocused) {
    final posterUrl = TmdbApiService.getPosterUrl(item['poster_path'] ?? '');
    final titleKey = item['title'] != null ? 'title' : 'name';
    final title = item[titleKey] ?? 'Unknown';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onItemSelected?.call(widget.items.indexOf(item)),
        child: AnimatedScale(
          scale: isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: isFocused
                  ? Border.all(color: const Color(0xFFE50914), width: 3)
                  : Border.all(color: Colors.transparent, width: 3),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE50914).withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  Image.network(
                    posterUrl,
                    width: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 130,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                  // Overlay on hover/focus
                  if (isFocused)
                    Container(
                      width: 130,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
