import 'package:flutter/material.dart';
import '../../services/tmdb_api_service.dart';

/// MaxStream Netflix-style hero section
/// Displays large banner with movie/series info and action buttons
class TvMaxStreamHeroSection extends StatefulWidget {
  final Map<String, dynamic> movie;
  final bool isFocused;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onMoreInfoPressed;

  const TvMaxStreamHeroSection({
    super.key,
    required this.movie,
    this.isFocused = false,
    this.onPlayPressed,
    this.onMoreInfoPressed,
  });

  @override
  State<TvMaxStreamHeroSection> createState() => _TvMaxStreamHeroSectionState();
}

class _TvMaxStreamHeroSectionState extends State<TvMaxStreamHeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    if (widget.isFocused) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(TvMaxStreamHeroSection oldWidget) {
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

  String _getGenreLabel() {
    // This is a placeholder - genres would come from API
    return 'Action • Drama • Sci-Fi';
  }

  @override
  Widget build(BuildContext context) {
    final backdropUrl = TmdbApiService.getBackdropUrl(
      widget.movie['backdrop_path'] ?? '',
    );
    final title = widget.movie['title'] ?? widget.movie['name'] ?? 'Unknown';
    final overview = widget.movie['overview'] ?? '';
    final rating = (widget.movie['vote_average'] as num?)?.toDouble() ?? 0.0;

    return Stack(
      children: [
        // Background image with gradient overlay
        Container(
          height: 400,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(backdropUrl),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
        // Content overlay
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                // Genre and Rating
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${rating.toStringAsFixed(1)}/10',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getGenreLabel(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Description
                SizedBox(
                  width: 600,
                  child: Text(
                    overview,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    AnimatedScale(
                      scale: widget.isFocused ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: _buildActionButton(
                        'Play',
                        Icons.play_arrow,
                        isPrimary: true,
                        onPressed: widget.onPlayPressed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedScale(
                      scale: widget.isFocused ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: _buildActionButton(
                        'More Info',
                        Icons.info_outline,
                        isPrimary: false,
                        onPressed: widget.onMoreInfoPressed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon, {
    required bool isPrimary,
    VoidCallback? onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFFE50914) : Colors.transparent,
            border: isPrimary
                ? null
                : Border.all(color: Colors.white.withOpacity(0.7), width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : Colors.white.withOpacity(0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary
                      ? Colors.white
                      : Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
