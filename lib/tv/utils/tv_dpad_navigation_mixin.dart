import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// D-Pad navigation mixin for TV content screens
/// Provides navigation within grids/lists and sidebar integration
mixin TvDpadNavigationMixin<T extends StatefulWidget> on State<T> {
  late FocusNode focusNode;
  int _currentFocusIndex = 0;

  /// Override to define max focus index
  int get maxFocusIndex;

  /// Called when focus changes
  void onFocusChanged(int index);

  /// Called when SELECT/ENTER is pressed
  void onSelectPressed() {}

  /// Called when LEFT arrow is pressed
  void onLeftPressed() {}

  /// Called when RIGHT arrow is pressed
  void onRightPressed() {}

  /// Called when UP arrow is pressed (optional)
  void onUpPressed() {}

  /// Called when DOWN arrow is pressed (optional)
  void onDownPressed() {}

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
      onDownPressed();
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      onUpPressed();
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      onLeftPressed();
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      onRightPressed();
    } else if (event.isKeyPressed(LogicalKeyboardKey.select) ||
        event.isKeyPressed(LogicalKeyboardKey.enter)) {
      onSelectPressed();
    }
  }

  /// Set focus to specific index
  void setFocusIndex(int index) {
    if (index >= 0 && index <= maxFocusIndex && index != _currentFocusIndex) {
      _currentFocusIndex = index;
      onFocusChanged(index);
    }
  }

  /// Get current focus index
  int getFocusIndex() => _currentFocusIndex;
}
