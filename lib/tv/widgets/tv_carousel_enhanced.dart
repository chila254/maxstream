import 'package:flutter/material.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';

/// Enhanced carousel widget for Continue Watching section
class TvContinueWatchingCarousel extends StatefulWidget {
  final List<ContinueWatchingItem> items;
  final ValueChanged<int> onItemSelected;

  const TvContinueWatchingCarousel({
    super.key,
    required this.items,
    required this.onItemSelected,
  });

  @override
  State<TvContinueWatchingCarousel> createState() =>
      _TvContinueWatchingCarouselState();
}

class ContinueWatchingItem {
  final String id;
  final String title;
  final String posterUrl;
  final double progress;
  final String duration;
  final String? nextEpisode;

  ContinueWatchingItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.progress,
    required this.duration,
    this.nextEpisode,
  });
}

class _TvContinueWatchingCarouselState extends State<TvContinueWatchingCarousel>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressAnimationController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _progressAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: TvUtils.responsivePadding(24, context),
            vertical: TvUtils.responsivePadding(16, context),
          ),
          child: Text(
            'Continue Watching',
            style: TvTypography.sectionTitle,
          ),
        ),
        // Carousel
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              widget.onItemSelected(page);
              _progressAnimationController.reset();
              _progressAnimationController.forward();
            },
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              return _buildCarouselCard(context, widget.items[index], index);
            },
          ),
        ),
        // Indicators
        SizedBox(
          height: TvUtils.responsivePadding(40, context),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: TvUtils.responsivePadding(24, context),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.items.length,
                    (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: EdgeInsets.symmetric(
                          horizontal: TvUtils.responsivePadding(4, context),
                        ),
                        height: TvUtils.responsivePadding(8, context),
                        width: isActive
                            ? TvUtils.responsivePadding(24, context)
                            : TvUtils.responsivePadding(8, context),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFE50914)
                              : Colors.grey[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(
    BuildContext context,
    ContinueWatchingItem item,
    int index,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: TvUtils.responsivePadding(8, context),
        vertical: TvUtils.responsivePadding(8, context),
      ),
      child: GestureDetector(
        onTap: () {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Poster Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  item.posterUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 48,
                    ),
                  ),
                ),
              ),
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.all(
                    TvUtils.responsivePadding(16, context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TvUtils.responsiveFontSize(18, context),
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.nextEpisode != null) ...[
                        SizedBox(
                          height: TvUtils.responsivePadding(8, context),
                        ),
                        Text(
                          item.nextEpisode!,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize:
                                TvUtils.responsiveFontSize(12, context),
                          ),
                        ),
                      ],
                      SizedBox(
                        height: TvUtils.responsivePadding(8, context),
                      ),
                      // Progress Bar with Animation
                      _buildAnimatedProgressBar(item.progress),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedProgressBar(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: TvUtils.responsivePadding(4, context),
            value: progress,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              Color.lerp(
                const Color(0xFF00FF00),
                const Color(0xFFE50914),
                progress > 0.9 ? 1.0 : 0.0,
              )!,
            ),
          ),
        ),
        SizedBox(
          height: TvUtils.responsivePadding(4, context),
        ),
        Text(
          '${(progress * 100).toStringAsFixed(0)}% watched',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: TvUtils.responsiveFontSize(11, context),
          ),
        ),
      ],
    );
  }
}
