import 'package:flutter/material.dart';

/// Centralized focus management for TV navigation
/// Handles focus switching between sidebar and content areas
/// Provides hierarchical focus control for grid-based navigation
class TvFocusManager {
  // Global reference to sidebar focus node
  static FocusNode? _sidebarFocusNode;

  // Global reference to content focus node
  static FocusNode? _contentFocusNode;

  // Track which area has focus
  static bool _isSidebarFocused = true;

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
    _sidebarFocusNode?.requestFocus();
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

  /// Dispose resources
  static void dispose() {
    _sidebarFocusNode = null;
    _contentFocusNode = null;
  }
}
