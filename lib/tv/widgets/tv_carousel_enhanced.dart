import 'package:flutter/material.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';
import '../utils/tv_image_cache_util.dart';

/// Enhanced carousel widget for Continue Watching section
/// Features:
/// - Smooth page transitions with parallax effect
/// - Animated progress bars with color transitions
/// - Focus-aware scaling and elevation
/// - D-pad navigation support
/// - Responsive indicators with active state animation
/// - Optimized for TV viewing experience
class TvContinueWatchingCarousel extends StatefulWidget {
  final List<ContinueWatchingItem> items;
  final ValueChanged<int> onItemSelected;
  final Duration scrollDuration;
  final Duration animationDuration;
  final bool enableParallax;

  const TvContinueWatchingCarousel({
    super.key,
    required this.items,
    required this.onItemSelected,
    this.scrollDuration = const Duration(milliseconds: 500),
    this.animationDuration = const Duration(milliseconds: 300),
    this.enableParallax = true,
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
  final String? rating;
  final int? releaseYear;
  final DateTime? watchedAt; // New: timestamp of when user stopped watching

  ContinueWatchingItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.progress,
    required this.duration,
    this.nextEpisode,
    this.rating,
    this.releaseYear,
    this.watchedAt,
  });

  /// Format the watched timestamp as user-friendly text
  String getWatchedTimeAgo() {
    if (watchedAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(watchedAt!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).ceil()}w ago';
    }
  }
}

class _TvContinueWatchingCarouselState extends State<TvContinueWatchingCarousel>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressAnimationController;
  late AnimationController _focusAnimationController;
  late List<AnimationController> _itemControllers;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Better viewport fraction - allows seeing previous/next items
    _pageController = PageController(viewportFraction: 0.75);

    _progressAnimationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _progressAnimationController.forward();

    _focusAnimationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Initialize item controllers for staggered animations
    _itemControllers = List.generate(
      widget.items.length,
      (_) =>
          AnimationController(duration: widget.animationDuration, vsync: this),
    );

    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final newPage = _pageController.page?.round() ?? 0;
    if (newPage != _currentPage) {
      setState(() => _currentPage = newPage);
      widget.onItemSelected(newPage);
      _progressAnimationController.reset();
      _progressAnimationController.forward();
      _focusAnimationController.reset();
      _focusAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _progressAnimationController.dispose();
    _focusAnimationController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title with gradient effect
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: TvUtils.responsivePadding(24, context),
            vertical: TvUtils.responsivePadding(16, context),
          ),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [const Color(0xFFE50914), const Color(0xFFFF6B6B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  'Continue Watching',
                  style: TvTypography.sectionTitle,
                ),
              ),
              const Spacer(),
              // Item count indicator
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: TvUtils.responsivePadding(8, context),
                  vertical: TvUtils.responsivePadding(4, context),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE50914).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_currentPage + 1}/${widget.items.length}',
                  style: TextStyle(
                    color: const Color(0xFFE50914),
                    fontSize: TvUtils.responsiveFontSize(12, context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Carousel with enhanced height and better viewport
        SizedBox(
          height: (TvUtils.responsiveWidth(320, context, maxWidth: 380)),
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double pageOffset = 0;
                  if (_pageController.position.hasContentDimensions) {
                    pageOffset = index - (_pageController.page ?? 0);
                  }
                  return Transform.scale(
                    scale: (1 - (pageOffset.abs() * 0.1)).clamp(0.8, 1.0),
                    child: Opacity(
                      opacity: (1 - (pageOffset.abs() * 0.5)).clamp(0.4, 1.0),
                      child: _buildCarouselCard(
                        context,
                        widget.items[index],
                        index,
                        isFocused: index == _currentPage,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Enhanced Indicators with animation
        SizedBox(
          height: TvUtils.responsivePadding(48, context),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: TvUtils.responsivePadding(24, context),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.items.length, (index) {
                    final isActive = index == _currentPage;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: TvUtils.responsivePadding(4, context),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: widget.scrollDuration,
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: widget.animationDuration,
                          height: TvUtils.responsivePadding(8, context),
                          width: isActive
                              ? TvUtils.responsivePadding(28, context)
                              : TvUtils.responsivePadding(8, context),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFE50914)
                                : Colors.grey[600],
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFE50914,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                      ),
                    );
                  }),
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
    int index, {
    bool isFocused = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: TvUtils.responsivePadding(8, context),
        vertical: TvUtils.responsivePadding(8, context),
      ),
      child: GestureDetector(
        onTap: () {
          _pageController.animateToPage(
            index,
            duration: widget.scrollDuration,
            curve: Curves.easeInOut,
          );
        },
        child: AnimatedContainer(
          duration: widget.animationDuration,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isFocused
                    ? const Color(0xFFE50914).withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                blurRadius: isFocused ? 24 : 16,
                spreadRadius: isFocused ? 4 : 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Poster Image with parallax effect - use cached image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(
                  image: TvImageCacheUtil.getCachedImage(
                    item.posterUrl,
                    cacheType: ImageCacheType.poster,
                  ),
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
              // Dynamic Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      isFocused
                          ? Colors.black.withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              // Playback button indicator on focused state
              if (isFocused)
                Center(
                  child: ScaleTransition(
                    scale: AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE50914).withValues(alpha: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFE50914,
                            ).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              // Content Information
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
                      // Title and Meta Info Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: TvUtils.responsiveFontSize(
                                      18,
                                      context,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.releaseYear != null) ...[
                                  SizedBox(
                                    height: TvUtils.responsivePadding(
                                      4,
                                      context,
                                    ),
                                  ),
                                  Text(
                                    item.releaseYear.toString(),
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: TvUtils.responsiveFontSize(
                                        12,
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (item.rating != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: TvUtils.responsivePadding(
                                  8,
                                  context,
                                ),
                                vertical: TvUtils.responsivePadding(4, context),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE50914,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(
                                    0xFFE50914,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                item.rating!,
                                style: TextStyle(
                                  color: const Color(0xFFE50914),
                                  fontSize: TvUtils.responsiveFontSize(
                                    11,
                                    context,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Next Episode or Duration
                      if (item.nextEpisode != null) ...[
                        SizedBox(height: TvUtils.responsivePadding(8, context)),
                        Text(
                          item.nextEpisode!,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: TvUtils.responsiveFontSize(12, context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        SizedBox(height: TvUtils.responsivePadding(8, context)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.duration,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: TvUtils.responsiveFontSize(
                                  12,
                                  context,
                                ),
                              ),
                            ),
                            // Watched timestamp
                            if (item.watchedAt != null)
                              Text(
                                'Watched ${item.getWatchedTimeAgo()}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: TvUtils.responsiveFontSize(
                                    10,
                                    context,
                                  ),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ],
                      SizedBox(height: TvUtils.responsivePadding(8, context)),
                      // Progress Bar with Enhanced Animation
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
    // Determine progress color based on watch progress
    final progressColor = progress >= 0.9
        ? const Color(0xFFE50914) // Red for almost complete
        : progress >= 0.5
        ? const Color(0xFFFFA500) // Orange for halfway
        : const Color(0xFF00CC44); // Green for start

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Background track
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: TvUtils.responsivePadding(6, context),
                color: Colors.grey[800],
              ),
            ),
            // Animated progress fill
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AnimatedBuilder(
                animation: _progressAnimationController,
                builder: (context, child) {
                  final animatedProgress =
                      progress * _progressAnimationController.value;
                  return Container(
                    height: TvUtils.responsivePadding(6, context),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          progressColor,
                          progressColor.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: animatedProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              progressColor,
                              progressColor.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: progressColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: TvUtils.responsivePadding(6, context)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).toStringAsFixed(0)}% watched',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: TvUtils.responsiveFontSize(11, context),
              ),
            ),
            if (progress < 1.0)
              Text(
                '${((1 - progress) * 100).toStringAsFixed(0)}% remaining',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: TvUtils.responsiveFontSize(10, context),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
