import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mixin for TV D-Pad navigation handling
/// 
/// Usage:
/// ```dart
/// class MyTvScreen extends StatefulWidget {
///   @override
///   State<MyTvScreen> createState() => _MyTvScreenState();
/// }
/// 
/// class _MyTvScreenState extends State<MyTvScreen> with TvDpadNavigationMixin {
///   @override
///   int get maxFocusIndex => 3; // Number of focusable items - 1
///   
///   @override
///   void onFocusChanged(int index) {
///     setState(() => _focusedIndex = index);
///   }
///   
///   @override
///   void onSelectPressed() {
///     // Handle select button press
///   }
///   
///   @override
///   Widget build(BuildContext context) {
///     return RawKeyboardListener(
///       onKey: handleKeyEvent,
///       focusNode: focusNode,
///       child: // your widget
///     );
///   }
/// }
/// ```
mixin TvDpadNavigationMixin<T extends StatefulWidget> on State<T> {
  late FocusNode focusNode;
  int _currentFocusIndex = 0;

  /// Override this to define max focusable index
  int get maxFocusIndex;

  /// Override this to handle focus changes
  void onFocusChanged(int index);

  /// Override this to handle select/enter button press
  void onSelectPressed();

  /// Override this to handle left arrow (optional)
  void onLeftPressed() {}

  /// Override this to handle right arrow (optional)
  void onRightPressed() {}

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  /// Handle keyboard events from D-Pad
  void handleKeyEvent(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      _moveFocus(1);
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      _moveFocus(-1);
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      onLeftPressed();
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      onRightPressed();
    } else if (event.isKeyPressed(LogicalKeyboardKey.select) ||
        event.isKeyPressed(LogicalKeyboardKey.enter)) {
      onSelectPressed();
    }
  }

  /// Move focus up or down with bounds checking
  void _moveFocus(int direction) {
    final newIndex = (_currentFocusIndex + direction).clamp(0, maxFocusIndex);
    if (newIndex != _currentFocusIndex) {
      _currentFocusIndex = newIndex;
      onFocusChanged(newIndex);
    }
  }

  /// Set focus to specific index
  void setFocusIndex(int index) {
    if (index >= 0 && index <= maxFocusIndex) {
      _currentFocusIndex = index;
      onFocusChanged(index);
    }
  }

  /// Get current focus index
  int getFocusIndex() => _currentFocusIndex;

  /// Reset focus to first item
  void resetFocus() {
    _currentFocusIndex = 0;
    onFocusChanged(0);
  }
}
