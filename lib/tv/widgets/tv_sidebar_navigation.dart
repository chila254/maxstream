import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_focus_manager.dart';

/// MaxStream left sidebar navigation for TV
/// Displays vertical navigation tabs with red rounded borders
/// Features D-pad UP/DOWN navigation between menu items
/// Integrates with TvFocusManager for Netflix-style focus restoration
class TvSidebarNavigation extends StatefulWidget {
  final int selectedIndex;
  final List<String> titles;
  final List<IconData> icons;
  final Function(int) onItemSelected;

  const TvSidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.titles,
    required this.icons,
    required this.onItemSelected,
  });

  @override
  State<TvSidebarNavigation> createState() => _TvSidebarNavigationState();
}

class _TvSidebarNavigationState extends State<TvSidebarNavigation> {
  late ScrollController _scrollController;
  late List<FocusNode> _menuItemFocusNodes;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Create focus nodes for each menu item (indices: 0=Home, 1=Search, 2=Genre, 3=Series, 4=Watchlist, 5=Settings)
    _menuItemFocusNodes = List.generate(
      widget.titles.length,
      (index) =>
          FocusNode(onKey: (node, event) => _handleMenuKeyEvent(event, index)),
    );

    // Auto-focus the last focused item or first item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lastFocused = TvFocusManager.getLastSidebarItemFocus();
      if (lastFocused != null && _menuItemFocusNodes.contains(lastFocused)) {
        lastFocused.requestFocus();
      } else {
        _menuItemFocusNodes[widget.selectedIndex].requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(TvSidebarNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final itemHeight = 100.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = (widget.selectedIndex * itemHeight).clamp(0.0, maxScroll);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Save the currently focused sidebar item
  void _saveFocusedItem(int index) {
    TvFocusManager.saveSidebarItemFocus(_menuItemFocusNodes[index]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var node in _menuItemFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Handle D-pad navigation within sidebar menu
  /// Saves focus when moving between items for Netflix-style restoration
  /// LEFT key returns focus to content area
  KeyEventResult _handleMenuKeyEvent(RawKeyEvent event, int itemIndex) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      // Move to next menu item
      if (itemIndex < _menuItemFocusNodes.length - 1) {
        _menuItemFocusNodes[itemIndex + 1].requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      // Move to previous menu item
      if (itemIndex > 0) {
        _menuItemFocusNodes[itemIndex - 1].requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // LEFT key: Move focus back to content area (Netflix-style)
      // This is handled by the parent Action in tv_maxstream_main
      return KeyEventResult.ignored;
    } else if (event.logicalKey == LogicalKeyboardKey.select) {
      // Select menu item
      widget.onItemSelected(itemIndex);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.vertical,
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Home button
            Focus(
              focusNode: _menuItemFocusNodes[0],
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  _saveFocusedItem(0);
                  widget.onItemSelected(0);
                }
              },
              child: _buildNavButton(
                context,
                0,
                isSelected: widget.selectedIndex == 0,
              ),
            ),
            const SizedBox(height: 20),

            // Series button
            Focus(
              focusNode: _menuItemFocusNodes[3],
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  _saveFocusedItem(3);
                  widget.onItemSelected(3);
                }
              },
              child: _buildNavButton(
                context,
                3,
                isSelected: widget.selectedIndex == 3,
              ),
            ),
            const SizedBox(height: 20),

            // Genre button
            Focus(
              focusNode: _menuItemFocusNodes[2],
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  _saveFocusedItem(2);
                  widget.onItemSelected(2);
                }
              },
              child: _buildNavButton(
                context,
                2,
                isSelected: widget.selectedIndex == 2,
              ),
            ),
            const SizedBox(height: 20),

            // Search button
            Focus(
              focusNode: _menuItemFocusNodes[1],
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  _saveFocusedItem(1);
                  widget.onItemSelected(1);
                }
              },
              child: _buildNavButton(
                context,
                1,
                isSelected: widget.selectedIndex == 1,
              ),
            ),
            const SizedBox(height: 20),

            // Watchlist button
            Focus(
              focusNode: _menuItemFocusNodes[4],
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  _saveFocusedItem(4);
                  widget.onItemSelected(4);
                }
              },
              child: _buildNavButton(
                context,
                4,
                isSelected: widget.selectedIndex == 4,
              ),
            ),
            const SizedBox(height: 20),

            // Settings button
            Focus(
              focusNode: _menuItemFocusNodes[5],
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  _saveFocusedItem(5);
                  widget.onItemSelected(5);
                }
              },
              child: _buildSettingsButton(
                context,
                isSelected: widget.selectedIndex == 5,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    int index, {
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => widget.onItemSelected(index),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1.0, end: isSelected ? 1.1 : 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0xFFE50914),
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE50914).withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    widget.icons[index],
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSelected ? 11 : 10,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  child: Text(
                    widget.titles[index],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton(
    BuildContext context, {
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => widget.onItemSelected(5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1.0, end: isSelected ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : Border.all(color: const Color(0xFFE50914), width: 1.5),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE50914).withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Icon(Icons.settings, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: isSelected ? 11 : 10,
                  ),
                  child: const Text(
                    'Settings',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
