import 'package:flutter/material.dart';
import '../utils/tv_utils.dart';

/// Netflix-style TV sidebar with smooth navigation
class TvNetflixSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isFocused;
  final List<String> titles;
  final List<IconData> icons;
  final Function(int) onItemSelected;

  const TvNetflixSidebar({
    super.key,
    required this.selectedIndex,
    required this.isFocused,
    required this.titles,
    required this.icons,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = TvUtils.responsiveWidth(140, context, maxWidth: 200);
    final padding = TvUtils.responsivePadding(12, context);

    return Container(
      width: sidebarWidth,
      color: const Color(0xFF1A1A1A),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: isFocused
            ? Border(right: BorderSide(color: Colors.red, width: 3))
            : null,
      ),
      child: Column(
        children: [
          // Logo/Title - No animation, instant display
          Container(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_fill,
                  color: Colors.red,
                  size: TvUtils.responsiveFontSize(40, context, maxSize: 60),
                ),
                SizedBox(height: TvUtils.responsivePadding(8, context)),
                Text(
                  'MaxStream',
                  style: TextStyle(
                    fontSize: TvUtils.responsiveFontSize(16, context, maxSize: 24),
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey[800], thickness: 1),
          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(
                  icons.length,
                  (index) => _buildNavItem(context, index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final isSelected = selectedIndex == index;
    final fontSize = TvUtils.responsiveFontSize(13, context, maxSize: 18);
    final iconSize = TvUtils.responsiveFontSize(24, context, maxSize: 36);
    final padding = TvUtils.responsivePadding(10, context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
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
            border: isSelected
                ? Border.all(color: Colors.red, width: 2)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icons[index],
                color: isSelected ? Colors.red : Colors.grey,
                size: iconSize,
              ),
              SizedBox(height: TvUtils.responsivePadding(6, context)),
              Text(
                titles[index],
                style: TextStyle(
                  color: isSelected ? Colors.red : Colors.grey,
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
