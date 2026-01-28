import 'package:flutter/material.dart';

/// Centralized focus management for TV navigation
/// Handles focus switching between sidebar and content areas
/// Provides hierarchical focus control for grid-based navigation
/// Integrates with Netflix-style sidebar focus restoration
class TvFocusManager {
  // Global reference to sidebar focus node
  static FocusNode? _sidebarFocusNode;
  
  // Global reference to content focus node
  static FocusNode? _contentFocusNode;
  
  // Track which area has focus
  static bool _isSidebarFocused = true;

  // Track last focused sidebar item for restoration (Netflix-style)
  static FocusNode? _lastSidebarItemFocusNode;

  /// Initialize the focus manager with sidebar and content focus nodes
  static void initialize({
    required FocusNode sidebarFocusNode,
    required FocusNode contentFocusNode,
  }) {
    _sidebarFocusNode = sidebarFocusNode;
    _contentFocusNode = contentFocusNode;
  }

  /// Check if sidebar currently has focus
  static bool get isSidebarFocused => _isSidebarFocused;

  /// Request focus to shift to sidebar
  static void focusSidebar() {
    _isSidebarFocused = true;
    // Restore last focused sidebar item (Netflix pattern)
    final targetNode = _lastSidebarItemFocusNode ?? _sidebarFocusNode;
    targetNode?.requestFocus();
  }

  /// Request focus to shift to content area
  static void focusContent() {
    _isSidebarFocused = false;
    _contentFocusNode?.requestFocus();
  }

  /// Toggle between sidebar and content
  static void toggleFocus() {
    if (_isSidebarFocused) {
      focusContent();
    } else {
      focusSidebar();
    }
  }

  /// Save the last focused sidebar menu item for restoration
  /// Call this when a sidebar item receives focus
  static void saveSidebarItemFocus(FocusNode focusNode) {
    _lastSidebarItemFocusNode = focusNode;
  }

  /// Get the last focused sidebar item or fallback to default
  static FocusNode? getLastSidebarItemFocus() {
    return _lastSidebarItemFocusNode;
  }

  /// Dispose resources
  static void dispose() {
    _sidebarFocusNode = null;
    _contentFocusNode = null;
    _lastSidebarItemFocusNode = null;
  }
}
