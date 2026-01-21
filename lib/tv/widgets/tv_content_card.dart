import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../utils/tv_typography.dart';

/// Enum to define content type
enum ContentType { movie, series, documentary, special }

/// Enhanced TV Content Card with modern design
/// Features:
/// - Rounded corners with subtle shadows
/// - Hover effects with gradient overlays
/// - Icon badges for content type
/// - Rating stars/badges in corners
/// - Focus states for TV remote navigation
class TvContentCard extends StatefulWidget {
  final String posterUrl;
  final String title;
  final ContentType contentType;
  final double? rating;
  final int? year;
  final String? duration;
  final bool isFocused;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final Duration animationDuration;

  const TvContentCard({
    super.key,
    required this.posterUrl,
    required this.title,
    required this.contentType,
    this.rating,
    this.year,
    this.duration,
    this.isFocused = false,
    required this.onTap,
    this.width,
    this.height,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<TvContentCard> createState() => _TvContentCardState();
}

class _TvContentCardState extends State<TvContentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  late Animation<double> _overlayAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _shadowAnimation = Tween<double>(begin: 8.0, end: 24.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _overlayAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.isFocused) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(TvContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getContentTypeLabel() {
    switch (widget.contentType) {
      case ContentType.movie:
        return 'MOVIE';
      case ContentType.series:
        return 'SERIES';
      case ContentType.documentary:
        return 'DOCUMENTARY';
      case ContentType.special:
        return 'SPECIAL';
    }
  }

  IconData _getContentTypeIcon() {
    switch (widget.contentType) {
      case ContentType.movie:
        return Icons.movie;
      case ContentType.series:
        return Icons.tv;
      case ContentType.documentary:
        return Icons.description;
      case ContentType.special:
        return Icons.star;
    }
  }

  Color _getContentTypeColor() {
    switch (widget.contentType) {
      case ContentType.movie:
        return const Color(0xFFE50914); // Netflix Red
      case ContentType.series:
        return const Color(0xFF564D4D); // Dark Purple
      case ContentType.documentary:
        return const Color(0xFF00A8E8); // Blue
      case ContentType.special:
        return const Color(0xFFFFB81C); // Gold
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.width ?? 180.0;
    final posterHeight = widget.height ?? 270.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _scaleAnimation,
            _shadowAnimation,
            _overlayAnimation,
          ]),
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster Image - Full card
                Container(
                  width: cardWidth,
                  height: posterHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      // Main shadow
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.4 * (widget.isFocused ? 1.0 : 0.6),
                        ),
                        blurRadius: _shadowAnimation.value,
                        spreadRadius: widget.isFocused ? 4 : 2,
                        offset: Offset(0, widget.isFocused ? 8 : 4),
                      ),
                      // Secondary glow shadow
                      if (widget.isFocused)
                        BoxShadow(
                          color: _getContentTypeColor().withValues(alpha: 0.3),
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
                        child: Stack(
                          children: [
                            // Background Image
                            Image.network(
                              widget.posterUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey[900],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 48,
                                ),
                              ),
                            ),
                            // Hover/Focus Gradient Overlay
                            if (widget.isFocused || _isHovered)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 2.0,
                                    sigmaY: 2.0,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withValues(
                                            alpha:
                                                0.1 * _overlayAnimation.value,
                                          ),
                                          Colors.cyan.withValues(
                                            alpha:
                                                0.15 * _overlayAnimation.value,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Content Badge - Top Left
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildContentTypeBadge(),
                      ),
                      // Rating Badge - Top Right
                      if (widget.rating != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _buildRatingBadge(),
                        ),
                  // Play Button on Hover/Focus
                  if ((widget.isFocused || _isHovered) &&
                      _overlayAnimation.value > 0.5)
                    Positioned.fill(
                      child: Center(
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: const Interval(0.5, 1.0,
                                  curve: Curves.easeOut),
                            ),
                          ),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.black,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
                ),
                // Title and Year - Below the cover art
                Padding(
                  padding: const EdgeInsets.only(top: TvSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        widget.title,
                        style: TvTypography.cardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.year != null)
                        Padding(
                          padding: const EdgeInsets.only(top: TvSpacing.sm),
                          child: Text(
                            widget.year.toString(),
                            style: TvTypography.caption,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentTypeBadge() {
    return Container(
      decoration: BoxDecoration(
        color: _getContentTypeColor(),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getContentTypeIcon(),
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            _getContentTypeLabel(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge() {
    final rating = widget.rating ?? 0;
    final starsCount = (rating / 2).floor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                size: 12,
                color: index < starsCount ? Colors.amber : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simplified Content Card for grid layouts
/// Lightweight version without some animation features
class TvSimpleContentCard extends StatelessWidget {
  final String posterUrl;
  final String title;
  final ContentType contentType;
  final double? rating;
  final VoidCallback onTap;
  final double width;
  final double height;

  const TvSimpleContentCard({
    super.key,
    required this.posterUrl,
    required this.title,
    required this.contentType,
    this.rating,
    required this.onTap,
    this.width = 160,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Poster Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                posterUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            // Content Type Badge
            Positioned(
              top: 8,
              left: 8,
              child: _buildSimpleBadge(),
            ),
            // Rating Badge
            if (rating != null)
              Positioned(
                top: 8,
                right: 8,
                child: _buildSimpleRatingBadge(),
              ),
            // Title
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleBadge() {
    final colors = {
      ContentType.movie: const Color(0xFFE50914),
      ContentType.series: const Color(0xFF564D4D),
      ContentType.documentary: const Color(0xFF00A8E8),
      ContentType.special: const Color(0xFFFFB81C),
    };

    final icons = {
      ContentType.movie: Icons.movie,
      ContentType.series: Icons.tv,
      ContentType.documentary: Icons.description,
      ContentType.special: Icons.star,
    };

    final labels = {
      ContentType.movie: 'MOVIE',
      ContentType.series: 'SERIES',
      ContentType.documentary: 'DOC',
      ContentType.special: 'SPECIAL',
    };

    return Container(
      decoration: BoxDecoration(
        color: colors[contentType],
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icons[contentType],
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 3),
          Text(
            labels[contentType]!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleRatingBadge() {
    final rating = this.rating ?? 0;
    final starsCount = (rating / 2).floor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                size: 10,
                color: index < starsCount ? Colors.amber : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
