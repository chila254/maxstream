import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralized TV navigation handler following Netflix-style patterns
/// Handles LEFT/RIGHT navigation boundaries, sidebar restoration, and focus management
class TvNavigation {
  // Track last focused sidebar focus node for restoration
  static FocusNode? _lastSidebarFocusNode;

  /// Save the current sidebar focus node for later restoration
  static void saveSidebarFocus(FocusNode focusNode) {
    _lastSidebarFocusNode = focusNode;
  }

  /// Get the last focused sidebar node, or fallback to default
  static FocusNode getLastSidebarFocus(FocusNode defaultFocusNode) {
    return _lastSidebarFocusNode ?? defaultFocusNode;
  }

  /// Handle LEFT key navigation at content boundary
  /// Returns true if the event was handled, false otherwise
  static bool handleLeftAtBoundary({
    required bool isAtBoundary,
    required FocusNode fallbackFocusNode,
  }) {
    if (isAtBoundary) {
      fallbackFocusNode.requestFocus();
      return true;
    }
    return false;
  }

  /// Determine if an item is at the leftmost column in a grid
  /// 
  /// Parameters:
  /// - itemIndex: The current item's index in the list
  /// - itemsPerRow: Number of items per row (default: 4)
  static bool isAtLeftBoundary(int itemIndex, {int itemsPerRow = 4}) {
    return (itemIndex % itemsPerRow) == 0;
  }

  /// Determine if an item is at the rightmost column in a grid
  static bool isAtRightBoundary(int itemIndex, int itemCount,
      {int itemsPerRow = 4}) {
    final isLastItemInRow = ((itemIndex + 1) % itemsPerRow) == 0;
    final isLastItem = itemIndex == (itemCount - 1);
    return isLastItemInRow || isLastItem;
  }

  /// Create a focus handler for grid-based content navigation
  /// Wraps content items with LEFT boundary detection
  static KeyEventResult handleGridNavigation(
    RawKeyEvent event,
    int itemIndex,
    int itemCount, {
    int itemsPerRow = 4,
    VoidCallback? onMovePrevious,
    VoidCallback? onMoveNext,
    VoidCallback? onReturnToSidebar,
  }) {
    if (event is! RawKeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (isAtLeftBoundary(itemIndex, itemsPerRow: itemsPerRow)) {
        // At leftmost boundary - return to sidebar
        onReturnToSidebar?.call();
        return KeyEventResult.handled;
      } else {
        // Move left within content
        onMovePrevious?.call();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (!isAtRightBoundary(itemIndex, itemCount, itemsPerRow: itemsPerRow)) {
        onMoveNext?.call();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Lock focus to prevent navigation during critical operations
  /// Returns true if navigation should be blocked
  static bool shouldLockNavigation({
    required bool isTyping,
    required bool isScrubbing,
    required bool isInModal,
    required bool isAnimating,
  }) {
    return isTyping || isScrubbing || isInModal || isAnimating;
  }

  /// Reset sidebar focus tracking (call on logout or app reset)
  static void reset() {
    _lastSidebarFocusNode = null;
  }
}

/// Widget wrapper for TV content items with automatic LEFT boundary handling
/// Simplifies implementation by wrapping grid items with navigation logic
class TvNavigationBoundary extends StatelessWidget {
  final Widget child;
  final int itemIndex;
  final int itemCount;
  final int itemsPerRow;
  final VoidCallback? onMovePrevious;
  final VoidCallback? onMoveNext;
  final VoidCallback? onReturnToSidebar;
  final FocusNode? focusNode;

  const TvNavigationBoundary({
    super.key,
    required this.child,
    required this.itemIndex,
    required this.itemCount,
    this.itemsPerRow = 4,
    this.onMovePrevious,
    this.onMoveNext,
    this.onReturnToSidebar,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKey: (node, event) => TvNavigation.handleGridNavigation(
        event,
        itemIndex,
        itemCount,
        itemsPerRow: itemsPerRow,
        onMovePrevious: onMovePrevious,
        onMoveNext: onMoveNext,
        onReturnToSidebar: onReturnToSidebar,
      ),
      child: child,
    );
  }
}
