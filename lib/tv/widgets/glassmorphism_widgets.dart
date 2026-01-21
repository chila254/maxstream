import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../utils/tv_utils.dart';

/// Glassmorphism overlay widget with backdrop blur and frosted glass effect
class GlassmorphicOverlay extends StatelessWidget {
  final Widget child;
  final double blurStrength;
  final double opacity;
  final Color glassColor;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final List<BoxShadow>? boxShadow;

  const GlassmorphicOverlay({
    super.key,
    required this.child,
    this.blurStrength = 10.0,
    this.opacity = 0.1,
    this.glassColor = Colors.white,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: glassColor.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow:
                boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Enhanced hero banner with gradient overlay and glassmorphism elements
class GlassmorphicHeroBanner extends StatefulWidget {
  final String backdropUrl;
  final String title;
  final String? description;
  final double? rating;
  final VoidCallback onTap;
  final bool isFocused;
  final Duration transitionDuration;

  const GlassmorphicHeroBanner({
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
  State<GlassmorphicHeroBanner> createState() => _GlassmorphicHeroBannerState();
}

class _GlassmorphicHeroBannerState extends State<GlassmorphicHeroBanner>
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
  void didUpdateWidget(GlassmorphicHeroBanner oldWidget) {
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
            // Gradient Overlay - Multi-layer with glassmorphism effect
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
                                  : Colors.grey[600],
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
                child: GlassmorphicOverlay(
                  blurStrength: 10,
                  opacity: 0.15,
                  glassColor: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(60)),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
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

/// Glassmorphic button with blur effect
class GlassmorphicButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final double blurStrength;
  final Color glassColor;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final bool isSelected;

  const GlassmorphicButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.blurStrength = 10.0,
    this.glassColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.isSelected = false,
  });

  @override
  State<GlassmorphicButton> createState() => _GlassmorphicButtonState();
}

class _GlassmorphicButtonState extends State<GlassmorphicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown() {
    _animationController.forward();
  }

  void _onTapUp() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onTapDown(),
      onTapUp: (_) {
        _onTapUp();
        widget.onPressed();
      },
      onTapCancel: _onTapUp,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) => ClipRRect(
            borderRadius: widget.borderRadius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: widget.blurStrength,
                sigmaY: widget.blurStrength,
              ),
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.glassColor.withValues(
                    alpha: widget.isSelected ? 0.25 : 0.15,
                  ),
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: 0.2 * _glowAnimation.value,
                      ),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic card for content display
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double blurStrength;
  final VoidCallback? onTap;
  final bool isSelected;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.blurStrength = 8.0,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: blurStrength,
            sigmaY: blurStrength,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isSelected ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: isSelected ? 0.5 : 0.2,
                ),
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFFE50914).withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Gradient overlay widget for modern hero banners
class GradientOverlay extends StatelessWidget {
  final List<Color> colors;
  final List<double>? stops;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final double opacity;

  const GradientOverlay({
    super.key,
    this.colors = const [Colors.transparent, Colors.black],
    this.stops,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.opacity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: colors.map((color) => color.withValues(alpha: opacity)).toList(),
          stops: stops,
        ),
      ),
    );
  }
}
