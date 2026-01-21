import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../utils/tv_utils.dart';

/// Enhanced Hero Banner with smooth animations and modern effects
/// Features:
/// - Smooth fade and zoom transitions
/// - Animated overlay gradient
/// - Smooth indicator animations
/// - Title/description fade effects
/// - Glassmorphism effects with backdrop blur
class TvEnhancedHeroBanner extends StatefulWidget {
  final String backdropUrl;
  final String title;
  final String? description;
  final double? rating;
  final VoidCallback onTap;
  final bool isFocused;
  final Duration transitionDuration;

  const TvEnhancedHeroBanner({
    super.key,
    required this.backdropUrl,
    required this.title,
    this.description,
    this.rating,
    required this.onTap,
    this.isFocused = false,
    this.transitionDuration = const Duration(milliseconds: 500),
  });

  @override
  State<TvEnhancedHeroBanner> createState() => _TvEnhancedHeroBannerState();
}

class _TvEnhancedHeroBannerState extends State<TvEnhancedHeroBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _overlayAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _overlayAnimation = Tween<double>(begin: 0.4, end: 0.6).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(TvEnhancedHeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backdropUrl != oldWidget.backdropUrl) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) => Stack(
          children: [
            // Background Image with Scale Animation
            ScaleTransition(
              scale: _scaleAnimation,
              child: Image.network(
                widget.backdropUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 80,
                  ),
                ),
              ),
            ),
            // Multi-layer Gradient Overlay with modern glassmorphism effect
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: _overlayAnimation.value),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Secondary radial gradient for depth
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.2,
                  colors: [Colors.black.withValues(alpha: 0.1), Colors.transparent],
                ),
              ),
            ),
            // Content with Fade Animation
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.all(TvUtils.responsivePadding(32, context)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TvUtils.responsiveFontSize(
                          36,
                          context,
                          maxSize: 48,
                        ),
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: TvUtils.responsivePadding(12, context)),
                    // Rating
                    if (widget.rating != null)
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              Icons.star,
                              color: index < (widget.rating! / 2).floor()
                                  ? Colors.amber
                                  : Colors.grey.withValues(alpha: 0.6),
                              size: 20,
                            ),
                          ),
                          SizedBox(
                            width: TvUtils.responsivePadding(8, context),
                          ),
                          Text(
                            '${widget.rating!.toStringAsFixed(1)}/10',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: TvUtils.responsiveFontSize(14, context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: TvUtils.responsivePadding(16, context)),
                    // Description
                    if (widget.description != null &&
                        widget.description!.isNotEmpty)
                      Text(
                        widget.description!,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: TvUtils.responsiveFontSize(16, context),
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            // Play Button with Glassmorphic effect
            Positioned(
              top: 50,
              right: 50,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced Page Indicator with smooth animations
class TvEnhancedPageIndicator extends StatelessWidget {
  final int itemCount;
  final int currentIndex;
  final Duration animationDuration;

  const TvEnhancedPageIndicator({
    super.key,
    required this.itemCount,
    required this.currentIndex,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) => AnimatedContainer(
          duration: animationDuration,
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: currentIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentIndex == index
                ? const Color(0xFFE50914)
                : Colors.grey.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
            boxShadow: currentIndex == index
                ? [
                    BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
