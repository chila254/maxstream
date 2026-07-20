import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_focus_manager.dart';

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

class _TvSidebarNavigationState extends State<TvSidebarNavigation>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late List<FocusNode> _menuItemFocusNodes;
  int _focusedIndex = -1;

  static const _panelColor = Color(0xFF141414);
  static const _selectedBackground = Color(0xFFE50914);
  static const _focusBackground = Color(0x18FFFFFF);
  static const _iconCircleDefault = Color(0xFF222222);
  static const _iconCircleSelected = Color(0x28FFFFFF);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _menuItemFocusNodes = List.generate(
      widget.titles.length,
      (index) => FocusNode(onKey: (node, event) => _handleKeyEvent(event, index)),
    );

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final itemHeight = 52.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = (widget.selectedIndex * itemHeight).clamp(0.0, maxScroll);
    _scrollController.animateTo(offset, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

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

  KeyEventResult _handleKeyEvent(RawKeyEvent event, int itemIndex) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (itemIndex < _menuItemFocusNodes.length - 1) {
        _menuItemFocusNodes[itemIndex + 1].requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (itemIndex > 0) {
        _menuItemFocusNodes[itemIndex - 1].requestFocus();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.select) {
      widget.onItemSelected(itemIndex);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), Color(0xFF111111)],
        ),
        border: Border(
          right: BorderSide(color: Color(0x18FFFFFF), width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          // App logo/icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE50914), Color(0xFFB20710)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 28),
          // Navigation items - vertically centered with compact spacing
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.titles.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: _NavPillItem(
                      focusNode: _menuItemFocusNodes[index],
                      icon: widget.icons[index],
                      label: widget.titles[index],
                      isSelected: widget.selectedIndex == index,
                      isFocused: _focusedIndex == index,
                      onFocusChanged: (focused) {
                        if (focused) {
                          setState(() => _focusedIndex = index);
                          _saveFocusedItem(index);
                          widget.onItemSelected(index);
                        } else {
                          if (_focusedIndex == index) {
                            setState(() => _focusedIndex = -1);
                          }
                        }
                      },
                      onTap: () => widget.onItemSelected(index),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavPillItem extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isFocused;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onTap;

  const _NavPillItem({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isFocused,
    required this.onFocusChanged,
    required this.onTap,
  });

  @override
  State<_NavPillItem> createState() => _NavPillItemState();
}

class _NavPillItemState extends State<_NavPillItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(_NavPillItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused && !oldWidget.isFocused) {
      _controller.forward();
    } else if (!widget.isFocused && oldWidget.isFocused) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? const Color(0x38FFFFFF)
        : widget.isFocused
            ? const Color(0x14FFFFFF)
            : Colors.transparent;
    final borderColor = widget.isFocused
        ? const Color(0x30FFFFFF)
        : Colors.transparent;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: widget.onFocusChanged,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 104,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular icon container
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? const Color(0x28FFFFFF)
                        : const Color(0xFF222222),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.isSelected
                        ? Colors.white
                        : widget.isFocused
                            ? Colors.white
                            : const Color(0xFF999999),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                // Label
                Flexible(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isSelected || widget.isFocused
                          ? Colors.white
                          : const Color(0xFF999999),
                      fontSize: 13,
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
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
