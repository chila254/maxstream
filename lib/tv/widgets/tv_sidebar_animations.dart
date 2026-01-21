import 'package:flutter/material.dart';
import '../utils/tv_utils.dart';

/// Enhanced sidebar with smooth animations for TV app
/// Features:
/// - Smooth expand/collapse animation
/// - Individual item entrance animations
/// - Focus-aware visual feedback
/// - Responsive sizing and spacing
class TvAnimatedSidebar extends StatefulWidget {
  final List<SidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final double width;
  final bool isExpanded;
  final bool isFocused;
  final Duration expandDuration;
  final Duration itemAnimationDuration;

  const TvAnimatedSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.width = 280,
    this.isExpanded = true,
    this.isFocused = false,
    this.expandDuration = const Duration(milliseconds: 500),
    this.itemAnimationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<TvAnimatedSidebar> createState() => _TvAnimatedSidebarState();
}

class SidebarItem {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final Color? badgeColor;

  SidebarItem({
    required this.label,
    required this.icon,
    this.onTap,
    this.badge,
    this.badgeColor,
  });
}

class _TvAnimatedSidebarState extends State<TvAnimatedSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: widget.expandDuration,
      vsync: this,
    );

    _expandAnimation = Tween<double>(begin: widget.isExpanded ? 1.0 : 0.0)
        .animate(
          CurvedAnimation(parent: _expandController, curve: Curves.easeInOut),
        );

    if (widget.isExpanded) {
      _expandController.forward();
    }
  }

  @override
  void didUpdateWidget(TvAnimatedSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final currentWidth = widget.width * _expandAnimation.value;
        return Container(
          width: currentWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            border: Border(
              right: BorderSide(
                color: Colors.grey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isFocused ? 0.5 : 0.3),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRect(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Sidebar Header with fade animation
                  if (widget.isExpanded)
                    Padding(
                      padding: EdgeInsets.all(
                        TvUtils.responsivePadding(16, context),
                      ),
                      child: Opacity(
                        opacity: _expandAnimation.value,
                        child: ScaleTransition(
                          scale: _expandAnimation,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'MaxStream',
                            style: TextStyle(
                              color: const Color(0xFFE50914),
                              fontSize:
                                  TvUtils.responsiveFontSize(24, context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Menu Items with staggered animation
                  ...List.generate(
                    widget.items.length,
                    (index) {
                      final item = widget.items[index];
                      final isSelected = index == widget.selectedIndex;
                      return _buildSidebarItem(
                        item,
                        isSelected,
                        index,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarItem(SidebarItem item, bool isSelected, int index) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        // Could add hover animation here if needed
      },
      child: GestureDetector(
        onTap: () {
          widget.onItemSelected(index);
          item.onTap?.call();
        },
        child: AnimatedContainer(
          duration: widget.itemAnimationDuration,
          margin: EdgeInsets.symmetric(
            horizontal: TvUtils.responsivePadding(8, context),
            vertical: TvUtils.responsivePadding(4, context),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: TvUtils.responsivePadding(12, context),
            vertical: TvUtils.responsivePadding(14, context),
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE50914).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFE50914)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Icon with scale animation on selection
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: widget.itemAnimationDuration,
                child: Icon(
                  item.icon,
                  color: isSelected
                      ? const Color(0xFFE50914)
                      : Colors.grey[400],
                  size: TvUtils.responsiveFontSize(22, context),
                ),
              ),
              if (widget.isExpanded) ...[
                SizedBox(
                  width: TvUtils.responsivePadding(12, context),
                ),
                // Label with opacity animation
                Expanded(
                  child: Opacity(
                    opacity: _expandAnimation.value,
                    child: AnimatedDefaultTextStyle(
                      duration: widget.itemAnimationDuration,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFE50914)
                            : Colors.grey[300],
                        fontSize:
                            TvUtils.responsiveFontSize(16, context),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                // Badge with animation
                if (item.badge != null)
                  ScaleTransition(
                    scale: isSelected
                        ? AlwaysStoppedAnimation(1.0)
                        : AlwaysStoppedAnimation(0.9),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: TvUtils.responsivePadding(8, context),
                        vertical: TvUtils.responsivePadding(2, context),
                      ),
                      decoration: BoxDecoration(
                        color: item.badgeColor ?? const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
