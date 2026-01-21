import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Netflix-style D-Pad navigation mixin
/// - Instant sidebar/content switching with arrow keys
/// - Non-blocking content loading
/// - Smooth transitions with visual feedback
mixin TvNetflixDpadMixin<T extends StatefulWidget> on State<T> {
  late FocusNode focusNode;
  int _currentTabIndex = 0;

  /// Override to define number of tabs
  int get tabCount;

  /// Called when tab changes (use for instant UI update)
  void onTabChanged(int index);

  /// Called when focus moves to sidebar
  void onFocusToSidebar();

  /// Called when focus moves to content
  void onFocusToContent();

  /// Called for internal navigation within content (left/right within grid)
  void onContentNavigate(int direction) {} // Optional

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

  /// Handle all keyboard events from D-Pad
  void handleKeyEvent(RawKeyEvent event) {
    // UP/DOWN arrows: Navigate between tabs in sidebar
    if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      _navigateTab(1);
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      _navigateTab(-1);
    }
    // LEFT arrow: Move focus to sidebar
    else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      onFocusToSidebar();
    }
    // RIGHT arrow: Move focus to content
    else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      onFocusToContent();
    }
    // SELECT/ENTER: Handled by content or sidebar tap
    else if (event.isKeyPressed(LogicalKeyboardKey.select) ||
        event.isKeyPressed(LogicalKeyboardKey.enter)) {
      // Each content screen handles this
    }
  }

  /// Navigate between tabs (up/down on sidebar)
  void _navigateTab(int direction) {
    final newIndex = (_currentTabIndex + direction).clamp(0, tabCount - 1);
    if (newIndex != _currentTabIndex) {
      _currentTabIndex = newIndex;
      onTabChanged(newIndex); // Instant UI update
    }
  }

  /// Set current tab
  void setTab(int index) {
    if (index >= 0 && index < tabCount && index != _currentTabIndex) {
      _currentTabIndex = index;
      onTabChanged(index);
    }
  }

  /// Get current tab
  int getCurrentTab() => _currentTabIndex;
}
