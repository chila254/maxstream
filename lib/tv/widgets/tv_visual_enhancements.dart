import 'package:flutter/material.dart';

/// Gradient text widget for enhanced typography
class GradientText extends StatelessWidget {
  final String text;
  final List<Color> colors;
  final TextStyle? baseStyle;
  final bool animate;

  const GradientText(
    this.text, {
    super.key,
    this.colors = const [Color(0xFFE50914), Color(0xFFFF6B6B)],
    this.baseStyle,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(bounds);
      },
      child: Text(
        text,
        style: (baseStyle ?? const TextStyle()).copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Animated progress bar with gradient colors
class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final double height;
  final List<Color>? colors;
  final Duration animationDuration;
  final bool showLabel;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 6.0,
    this.colors,
    this.animationDuration = const Duration(milliseconds: 800),
    this.showLabel = true,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _fillAnimation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _fillAnimation =
          Tween<double>(begin: _fillAnimation.value, end: widget.value).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOutCubic,
            ),
          );
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _fillAnimation,
          builder: (context, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(widget.height / 2),
              child: Stack(
                children: [
                  // Background
                  Container(
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                  // Filled Progress
                  Container(
                    height: widget.height,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: _fillAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            widget.height / 2,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors:
                                widget.colors ??
                                [
                                  const Color(0xFFE50914),
                                  const Color(0xFFFF6B6B),
                                ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFE50914,
                              ).withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.showLabel)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AnimatedBuilder(
              animation: _fillAnimation,
              builder: (context, child) {
                return Text(
                  '${(_fillAnimation.value * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Status badge widget for content status
class StatusBadge extends StatefulWidget {
  final String label;
  final BadgeType type;
  final bool animate;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.animate = true,
  });

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

enum BadgeType { new_, trending, topRated, exclusive, comingSoon }

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getBadgeColor() {
    switch (widget.type) {
      case BadgeType.new_:
        return const Color(0xFF00D4FF);
      case BadgeType.trending:
        return const Color(0xFFFF6B6B);
      case BadgeType.topRated:
        return const Color(0xFFFFB81C);
      case BadgeType.exclusive:
        return const Color(0xFFE50914);
      case BadgeType.comingSoon:
        return Colors.grey[600]!;
    }
  }

  IconData _getBadgeIcon() {
    switch (widget.type) {
      case BadgeType.new_:
        return Icons.fiber_new;
      case BadgeType.trending:
        return Icons.trending_up;
      case BadgeType.topRated:
        return Icons.star;
      case BadgeType.exclusive:
        return Icons.lock;
      case BadgeType.comingSoon:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animate ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getBadgeColor().withValues(alpha: 0.2),
              border: Border.all(color: _getBadgeColor(), width: 1.5),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                if (widget.animate)
                  BoxShadow(
                    color: _getBadgeColor().withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getBadgeIcon(), color: _getBadgeColor(), size: 14),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: _getBadgeColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Category chip/tag widget
class CategoryChip extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? selectedColor;

  const CategoryChip({
    super.key,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.selectedColor,
  });

  @override
  State<CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<CategoryChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    if (widget.isSelected) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(CategoryChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? (widget.selectedColor ?? const Color(0xFFE50914))
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isSelected
                      ? (widget.selectedColor ?? const Color(0xFFE50914))
                      : Colors.grey[700]!,
                  width: 1.5,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color:
                              (widget.selectedColor ?? const Color(0xFFE50914))
                                  .withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected ? Colors.white : Colors.grey[300],
                  fontSize: 14,
                  fontWeight: widget.isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
