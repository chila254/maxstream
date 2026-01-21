import 'package:flutter/material.dart';
import '../utils/tv_utils.dart';

/// Breadcrumb navigation component for TV app
/// Shows navigation path with smooth animations
class TvBreadcrumb extends StatefulWidget {
  final List<BreadcrumbItem> items;
  final ValueChanged<int> onItemTapped;
  final int currentIndex;

  const TvBreadcrumb({
    super.key,
    required this.items,
    required this.onItemTapped,
    this.currentIndex = 0,
  });

  @override
  State<TvBreadcrumb> createState() => _TvBreadcrumbState();
}

class BreadcrumbItem {
  final String label;
  final String? icon;
  final VoidCallback? onTap;

  BreadcrumbItem({required this.label, this.icon, this.onTap});
}

class _TvBreadcrumbState extends State<TvBreadcrumb>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: -20, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: TvUtils.responsivePadding(24, context),
                vertical: TvUtils.responsivePadding(12, context),
              ),
              child: Row(
                children: List.generate(widget.items.length, (index) {
                  final item = widget.items[index];
                  final isLast = index == widget.items.length - 1;
                  final isCurrent = index == widget.currentIndex;

                  return Row(
                    children: [
                      GestureDetector(
                        onTap: () => widget.onItemTapped(index),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: TvUtils.responsivePadding(
                                12,
                                context,
                              ),
                              vertical: TvUtils.responsivePadding(8, context),
                            ),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(
                                      0xFFE50914,
                                    ).withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent
                                    ? const Color(0xFFE50914)
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (item.icon != null) ...[
                                  Icon(
                                    _getIconData(item.icon!),
                                    color: isCurrent
                                        ? const Color(0xFFE50914)
                                        : Colors.grey[400],
                                    size: TvUtils.responsiveFontSize(
                                      16,
                                      context,
                                    ),
                                  ),
                                  SizedBox(
                                    width: TvUtils.responsivePadding(
                                      8,
                                      context,
                                    ),
                                  ),
                                ],
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isCurrent
                                        ? const Color(0xFFE50914)
                                        : Colors.grey[400],
                                    fontSize: TvUtils.responsiveFontSize(
                                      14,
                                      context,
                                    ),
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: TvUtils.responsivePadding(8, context),
                          ),
                          child: Icon(
                            Icons.chevron_right,
                            color: Colors.grey[700],
                            size: TvUtils.responsiveFontSize(16, context),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIconData(String iconName) {
    final icons = {
      'home': Icons.home,
      'trending': Icons.trending_up,
      'search': Icons.search,
      'watchlist': Icons.favorite,
      'series': Icons.tv,
      'movies': Icons.movie,
    };
    return icons[iconName] ?? Icons.circle;
  }
}
