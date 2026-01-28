import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_navigation_handler.dart';

/// Callback when an item is focused in the grid
typedef OnItemFocused = void Function(int index);

/// Callback when an item is selected (SELECT key pressed)
typedef OnItemSelected = void Function(int index);

/// Callback when LEFT is pressed at the leftmost column
typedef OnReturnToSidebar = void Function();

/// Netflix-style horizontal content grid with D-pad navigation
/// Features:
/// - Automatic LEFT/RIGHT/UP/DOWN navigation with explicit focus nodes
/// - Returns to sidebar when pressing LEFT at first column
/// - Handles edge cases (last item, boundaries, wrapping)
/// - Enhanced visual focus indicators with prominent borders
/// - Smooth scrolling to keep focused item visible
/// - Full keyboard/D-pad support for TV
class TvContentGrid extends StatefulWidget {
  final List<Widget> items;
  final int itemsPerRow;
  final double itemHeight;
  final double itemWidth;
  final double spacing;
  final EdgeInsets padding;
  final ScrollController? scrollController;
  final OnItemFocused? onItemFocused;
  final OnItemSelected? onItemSelected;
  final OnReturnToSidebar? onReturnToSidebar;
  final bool autofocus;

  const TvContentGrid({
    super.key,
    required this.items,
    this.itemsPerRow = 4,
    this.itemHeight = 270,
    this.itemWidth = 180,
    this.spacing = 16,
    this.padding = const EdgeInsets.all(16),
    this.scrollController,
    this.onItemFocused,
    this.onItemSelected,
    this.onReturnToSidebar,
    this.autofocus = false,
  });

  @override
  State<TvContentGrid> createState() => _TvContentGridState();
}

class _TvContentGridState extends State<TvContentGrid> {
  late int _focusedIndex;
  late List<FocusNode> _focusNodes;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusedIndex = 0;
    _scrollController = widget.scrollController ?? ScrollController();

    // Create a FocusNode for each item
    _focusNodes = List.generate(
      widget.items.length,
      (index) =>
          FocusNode(onKey: (node, event) => _handleItemKeyEvent(event, index)),
    );

    // Set initial focus if autofocus is true
    if (widget.autofocus && _focusNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  /// Handle keyboard events for grid items with comprehensive D-pad support
  /// Uses TvNavigation for consistent Netflix-style boundary handling
  KeyEventResult _handleItemKeyEvent(RawKeyEvent event, int index) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

    final currentCol = index % widget.itemsPerRow;

    // LEFT: Handle return to sidebar at leftmost column
    // Uses TvNavigation for boundary detection
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (TvNavigation.isAtLeftBoundary(index, itemsPerRow: widget.itemsPerRow)) {
        // At leftmost column - return to sidebar
        widget.onReturnToSidebar?.call();
        return KeyEventResult.handled;
      }
      // Move to previous item in row
      final prevIndex = index - 1;
      if (prevIndex >= 0) {
        _focusNodes[prevIndex].requestFocus();
        return KeyEventResult.handled;
      }
    }

    // RIGHT: Move to next item in row
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final nextIndex = index + 1;
      if (nextIndex < widget.items.length &&
          currentCol < widget.itemsPerRow - 1) {
        _focusNodes[nextIndex].requestFocus();
        return KeyEventResult.handled;
      }
      // At rightmost - don't wrap, stop navigation
      return KeyEventResult.handled;
    }

    // UP: Move to item in previous row
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final upIndex = index - widget.itemsPerRow;
      if (upIndex >= 0) {
        _focusNodes[upIndex].requestFocus();
        return KeyEventResult.handled;
      }
    }

    // DOWN: Move to item in next row
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final downIndex = index + widget.itemsPerRow;
      if (downIndex < widget.items.length) {
        _focusNodes[downIndex].requestFocus();
        return KeyEventResult.handled;
      }
    }

    // SELECT: Item selected
    if (event.logicalKey == LogicalKeyboardKey.select) {
      widget.onItemSelected?.call(index);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      controller: _scrollController,
      crossAxisCount: widget.itemsPerRow,
      childAspectRatio: widget.itemWidth / widget.itemHeight,
      mainAxisSpacing: widget.spacing,
      crossAxisSpacing: widget.spacing,
      padding: widget.padding,
      children: List.generate(widget.items.length, (index) {
        return Focus(
          focusNode: _focusNodes[index],
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              setState(() => _focusedIndex = index);
              widget.onItemFocused?.call(index);
            }
          },
          child: _buildItemWrapper(index),
        );
      }),
    );
  }

  /// Wrap item with Netflix-style focus visual indicator
  Widget _buildItemWrapper(int index) {
    final isFocused = _focusedIndex == index;
    return AnimatedScale(
      scale: isFocused ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        decoration: BoxDecoration(
          border: Border.all(
            color: isFocused ? const Color(0xFFE50914) : Colors.transparent,
            width: isFocused ? 5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isFocused
              ? [
                  // Main shadow
                  BoxShadow(
                    color: const Color(0xFFE50914).withValues(alpha: 0.6),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                  // Glow shadow
                  BoxShadow(
                    color: const Color(0xFFE50914).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 8,
                  ),
                ]
              : [],
        ),
        child: widget.items[index],
      ),
    );
  }
}
