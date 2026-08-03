import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_image_cache_util.dart';

/// Enum to define content type
enum ContentType { movie, series, documentary, special }

/// Enhanced TV Content Card with modern design
/// Features:
/// - Rounded corners with subtle shadows
/// - Hover effects with gradient overlays
/// - Icon badges for content type
/// - Rating stars/badges in corners
/// - Focus states using traditional Flutter focus system
class TvContentCard extends StatefulWidget {
  final String posterUrl;
  final String title;
  final ContentType contentType;
  final double? rating;
  final int? year;
  final String? duration;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final Duration animationDuration;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onSelect;
  final double? progress;
  final FocusOnKeyEventCallback? onKeyEvent;

  const TvContentCard({
    super.key,
    required this.posterUrl,
    required this.title,
    required this.contentType,
    this.rating,
    this.year,
    this.duration,
    required this.onTap,
    this.width,
    this.height,
    this.animationDuration = const Duration(milliseconds: 180),
    this.focusNode,
    this.autofocus = false,
    this.onFocusChanged,
    this.onSelect,
    this.progress,
    this.onKeyEvent,
  });

  @override
  State<TvContentCard> createState() => _TvContentCardState();
}

class _TvContentCardState extends State<TvContentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  FocusNode? _internalFocusNode;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) _internalFocusNode = FocusNode();

    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(TvContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == null && widget.focusNode != null) {
      _internalFocusNode?.dispose();
      _internalFocusNode = null;
    } else if (oldWidget.focusNode != null && widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
  }

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange(bool isFocused) {
    if (isFocused) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    widget.onFocusChanged?.call(isFocused);
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

  Color _getContentTypeColor() {
    switch (widget.contentType) {
      case ContentType.movie:
        return const Color(0xFFE50914);
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
    final focusNode = widget.focusNode ?? _internalFocusNode!;
    final cardWidth = widget.width ?? 180.0;
    final posterHeight = widget.height ?? 270.0;

    return Focus(
      focusNode: focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        final result = widget.onKeyEvent?.call(node, event);
        if (result != null && result != KeyEventResult.ignored) return result;
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          (widget.onSelect ?? widget.onTap).call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: _onFocusChange,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) => SizedBox(
              width: cardWidth + 16,
              height: posterHeight + 20,
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: cardWidth,
                    height: posterHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: focusNode.hasFocus
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: focusNode.hasFocus ? 0.42 : 0.24,
                          ),
                          blurRadius: focusNode.hasFocus ? 10 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: TvImageCacheUtil.getCachedImage(
                            widget.posterUrl,
                            cacheType: ImageCacheType.poster,
                          ),
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
                        if (focusNode.hasFocus || _isHovered)
                          Container(color: Colors.black12),
                        Positioned(
                          top: 7,
                          left: 7,
                          child: _buildContentTypeBadge(),
                        ),
                        if (widget.rating != null)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: _buildRatingBadge(),
                          ),
                        if (widget.progress != null)
                          Positioned(
                            left: 7,
                            right: 7,
                            bottom: 7,
                            child: LinearProgressIndicator(
                              value: widget.progress!.clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: Colors.white24,
                              color: const Color(0xFFE50914),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
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
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Text(
        _getContentTypeLabel(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildRatingBadge() {
    final rating = widget.rating ?? 0;

    return Text(
      rating.toStringAsFixed(1),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
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
                  child: const Icon(Icons.broken_image, color: Colors.grey),
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
            Positioned(top: 8, left: 8, child: _buildSimpleBadge()),
            // Rating Number - Top Right (no container, just text)
            if (rating != null)
              Positioned(
                top: 12,
                right: 12,
                child: Text(
                  rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
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
          Icon(icons[contentType], color: Colors.white, size: 12),
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
}
