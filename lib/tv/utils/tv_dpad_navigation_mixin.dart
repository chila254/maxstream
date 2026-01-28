import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tv_navigation_handler.dart';

/// Mixin for handling D-Pad grid navigation in TV content screens
/// Provides row/column based navigation between items using arrow keys
/// Integrates with TvNavigation for Netflix-style boundary handling
mixin TvDPadNavigationMixin<T extends StatefulWidget> on State<T> {
  late FocusNode contentFocusNode;
  int _focusedItemIndex = 0;
  int _focusedRowIndex = 0;
  int _focusedColumnIndex = 0;
  late ScrollController horizontalScrollController;
  late ScrollController verticalScrollController;

  @override
  void initState() {
    super.initState();
    contentFocusNode = FocusNode();
    horizontalScrollController = ScrollController();
    verticalScrollController = ScrollController();
  }

  @override
  void dispose() {
    contentFocusNode.dispose();
    horizontalScrollController.dispose();
    verticalScrollController.dispose();
    super.dispose();
  }

  /// Handle grid-based D-Pad arrow key navigation
  /// Supports LEFT/RIGHT for horizontal movement within rows
  /// Supports UP/DOWN for vertical movement between rows
  /// When pressing LEFT on leftmost column, calls onReturnToSidebar
  /// Uses TvNavigation for consistent boundary handling
  KeyEventResult handleGridNavigation(
    RawKeyEvent event,
    int itemCount, {
    int itemsPerRow = 4,
    VoidCallback? onItemFocused,
    VoidCallback? onSelectItem,
    VoidCallback? onReturnToSidebar,
  }) {
    final currentColumn = _focusedItemIndex % itemsPerRow;

    if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      // Move right within the same row
      if (currentColumn < itemsPerRow - 1 &&
          _focusedItemIndex < itemCount - 1) {
        setState(() {
          _focusedItemIndex++;
          _focusedColumnIndex++;
        });
        onItemFocused?.call();
      }
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      // Use TvNavigation for boundary detection
      if (TvNavigation.isAtLeftBoundary(_focusedItemIndex,
          itemsPerRow: itemsPerRow)) {
        // At leftmost boundary - return to sidebar
        onReturnToSidebar?.call();
      } else {
        // Move left within content
        setState(() {
          _focusedItemIndex--;
          _focusedColumnIndex--;
        });
        onItemFocused?.call();
      }
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      // Move down to next row
      int nextIndex = _focusedItemIndex + itemsPerRow;
      if (nextIndex < itemCount) {
        setState(() {
          _focusedItemIndex = nextIndex;
          _focusedRowIndex++;
        });
        onItemFocused?.call();
      }
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      // Move up to previous row
      int nextIndex = _focusedItemIndex - itemsPerRow;
      if (nextIndex >= 0) {
        setState(() {
          _focusedItemIndex = nextIndex;
          _focusedRowIndex--;
        });
        onItemFocused?.call();
      }
      return KeyEventResult.handled;
    } else if (event.isKeyPressed(LogicalKeyboardKey.select)) {
      onSelectItem?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Get whether an item is currently focused
  bool isItemFocused(int index) => _focusedItemIndex == index;

  /// Reset focus to first item
  void resetFocus() {
    setState(() {
      _focusedItemIndex = 0;
      _focusedRowIndex = 0;
      _focusedColumnIndex = 0;
    });
  }

  /// Set focus to specific item
  void setFocus(int index) {
    setState(() {
      _focusedItemIndex = index;
      _focusedRowIndex = index ~/ 4; // Assuming 4 items per row
      _focusedColumnIndex = index % 4;
    });
  }

  /// Get current focused item index
  int get focusedItemIndex => _focusedItemIndex;

  /// Get current row
  int get focusedRowIndex => _focusedRowIndex;

  /// Get current column
  int get focusedColumnIndex => _focusedColumnIndex;
}
