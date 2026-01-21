import 'package:flutter/material.dart';
import '../utils/tv_utils.dart';

/// Quick action button component for TV app
/// Provides Play, Add to Watchlist, Share actions with smooth animations
class TvQuickActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isHighlighted;
  final Color? highlightColor;

  const TvQuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isHighlighted = false,
    this.highlightColor,
  });

  @override
  State<TvQuickActionButton> createState() => _TvQuickActionButtonState();
}

class _TvQuickActionButtonState extends State<TvQuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.isHighlighted) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(TvQuickActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted != oldWidget.isHighlighted) {
      if (widget.isHighlighted) {
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (widget.isHighlighted || _isHovered)
                    BoxShadow(
                      color: (widget.highlightColor ?? const Color(0xFFE50914))
                          .withValues(alpha: 0.5 * _glowAnimation.value),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: TvUtils.responsivePadding(20, context),
                      vertical: TvUtils.responsivePadding(12, context),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: widget.isHighlighted || _isHovered
                          ? (widget.highlightColor ?? const Color(0xFFE50914))
                          : Colors.grey[800],
                      border: Border.all(
                        color: widget.isHighlighted
                            ? (widget.highlightColor ?? const Color(0xFFE50914))
                            : Colors.grey[700]!,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon,
                          color: widget.isHighlighted
                              ? Colors.white
                              : Colors.white70,
                          size: TvUtils.responsiveFontSize(20, context),
                        ),
                        SizedBox(width: TvUtils.responsivePadding(8, context)),
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.isHighlighted
                                ? Colors.white
                                : Colors.white70,
                            fontSize: TvUtils.responsiveFontSize(16, context),
                            fontWeight: widget.isHighlighted
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Container for multiple quick action buttons
class TvQuickActionsBar extends StatefulWidget {
  final List<QuickAction> actions;
  final int? focusedIndex;
  final ValueChanged<int>? onFocusChanged;

  const TvQuickActionsBar({
    super.key,
    required this.actions,
    this.focusedIndex,
    this.onFocusChanged,
  });

  @override
  State<TvQuickActionsBar> createState() => _TvQuickActionsBarState();
}

class QuickAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  QuickAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });
}

class _TvQuickActionsBarState extends State<TvQuickActionsBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _appearanceController;
  late List<Animation<double>> _staggeredAnimations;

  @override
  void initState() {
    super.initState();
    _appearanceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _staggeredAnimations = List.generate(
      widget.actions.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _appearanceController,
          curve: Interval(
            (index * 0.1),
            (index * 0.1) + 0.6,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );

    _appearanceController.forward();
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: TvUtils.responsivePadding(24, context),
        vertical: TvUtils.responsivePadding(16, context),
      ),
      child: Wrap(
        spacing: TvUtils.responsivePadding(12, context),
        runSpacing: TvUtils.responsivePadding(12, context),
        children: List.generate(widget.actions.length, (index) {
          final action = widget.actions[index];
          return AnimatedBuilder(
            animation: _staggeredAnimations[index],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - _staggeredAnimations[index].value)),
                child: Opacity(
                  opacity: _staggeredAnimations[index].value,
                  child: TvQuickActionButton(
                    label: action.label,
                    icon: action.icon,
                    onPressed: action.onPressed,
                    isHighlighted: widget.focusedIndex == index ? true : false,
                    highlightColor: action.color,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
