import 'package:flutter/material.dart';
import '../utils/tv_utils.dart';

/// Netflix-style TV sidebar with smooth animation and focus feedback
/// Features:
/// - Instant visual feedback on selection
/// - Focus border animation
/// - Smooth item transitions
/// - Responsive sizing
class TvNetflixSidebar extends StatefulWidget {
  final int selectedIndex;
  final bool isFocused;
  final List<String> titles;
  final List<IconData> icons;
  final Function(int) onItemSelected;
  final Duration itemAnimationDuration;

  const TvNetflixSidebar({
    super.key,
    required this.selectedIndex,
    required this.isFocused,
    required this.titles,
    required this.icons,
    required this.onItemSelected,
    this.itemAnimationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<TvNetflixSidebar> createState() => _TvNetflixSidebarState();
}

class _TvNetflixSidebarState extends State<TvNetflixSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _focusController;
  late Animation<double> _focusAnimation;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _focusAnimation = Tween<double>(begin: widget.isFocused ? 1.0 : 0.0)
        .animate(
          CurvedAnimation(parent: _focusController, curve: Curves.easeInOut),
        );

    if (widget.isFocused) {
      _focusController.forward();
    }
  }

  @override
  void didUpdateWidget(TvNetflixSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        _focusController.forward();
      } else {
        _focusController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = TvUtils.responsiveWidth(140, context, maxWidth: 200);
    final padding = TvUtils.responsivePadding(12, context);

    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        return Container(
          width: sidebarWidth,
          color: const Color(0xFF1A1A1A),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            border: Border(
              right: BorderSide(
                color: Colors.red.withValues(
                  alpha: 0.3 + (_focusAnimation.value * 0.7),
                ),
                width: 1 + (_focusAnimation.value * 2),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(
                  alpha: 0.1 * _focusAnimation.value,
                ),
                blurRadius: 4 + (4 * _focusAnimation.value),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Logo/Title with scale animation
              Container(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: widget.isFocused ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.red,
                        size: TvUtils.responsiveFontSize(40, context,
                            maxSize: 60),
                      ),
                    ),
                    SizedBox(height: TvUtils.responsivePadding(8, context)),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: TvUtils.responsiveFontSize(16, context,
                            maxSize: 24),
                        fontWeight: widget.isFocused
                            ? FontWeight.bold
                            : FontWeight.bold,
                        color: Colors.red,
                      ),
                      child: const Text(
                        'MaxStream',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.grey[800], thickness: 1),
              // Navigation Items with staggered animation
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: List.generate(
                      widget.icons.length,
                      (index) => _buildNavItem(context, index),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final isSelected = widget.selectedIndex == index;
    final fontSize = TvUtils.responsiveFontSize(13, context, maxSize: 18);
    final iconSize = TvUtils.responsiveFontSize(24, context, maxSize: 36);
    final padding = TvUtils.responsivePadding(10, context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onItemSelected(index),
        child: AnimatedContainer(
          duration: widget.itemAnimationDuration,
          margin: EdgeInsets.symmetric(
            horizontal: TvUtils.responsivePadding(6, context),
            vertical: TvUtils.responsivePadding(4, context),
          ),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.red.withOpacity(0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.red : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: widget.itemAnimationDuration,
                child: Icon(
                  widget.icons[index],
                  color: isSelected ? Colors.red : Colors.grey,
                  size: iconSize,
                ),
              ),
              SizedBox(height: TvUtils.responsivePadding(6, context)),
              AnimatedDefaultTextStyle(
                duration: widget.itemAnimationDuration,
                style: TextStyle(
                  color: isSelected ? Colors.red : Colors.grey,
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                child: Text(
                  widget.titles[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
