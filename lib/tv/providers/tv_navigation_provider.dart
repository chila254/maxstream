import 'package:flutter/material.dart';

/// Netflix-style TV navigation state management
/// Handles instant UI updates with async data loading
class TvNavigationProvider extends ChangeNotifier {
  int _selectedTab = 0;
  bool _focusOnSidebar = true;

  // Cache for each tab's scroll position and focused item
  final Map<int, ScrollPosition> _tabScrollPositions = {};
  final Map<int, int> _tabFocusedIndices = {};

  int get selectedTab => _selectedTab;
  bool get focusOnSidebar => _focusOnSidebar;

  /// Switch tab instantly with UI feedback, load data async
  void selectTab(int index) {
    if (_selectedTab != index) {
      _selectedTab = index;
      _focusOnSidebar = false; // Move focus to content after selection
      notifyListeners();
    }
  }

  /// Move focus between sidebar and content
  void setFocusOnSidebar(bool value) {
    if (_focusOnSidebar != value) {
      _focusOnSidebar = value;
      notifyListeners();
    }
  }

  /// Save scroll position for current tab
  void saveScrollPosition(int tabIndex, ScrollPosition position) {
    _tabScrollPositions[tabIndex] = position;
  }

  /// Get saved scroll position for tab (for restoration)
  ScrollPosition? getScrollPosition(int tabIndex) {
    return _tabScrollPositions[tabIndex];
  }

  /// Save focused item index for current tab
  void saveFocusedIndex(int tabIndex, int index) {
    _tabFocusedIndices[tabIndex] = index;
  }

  /// Get focused item index for tab
  int getFocusedIndex(int tabIndex) {
    return _tabFocusedIndices[tabIndex] ?? 0;
  }

  /// Move to sidebar
  void returnToSidebar() {
    _focusOnSidebar = true;
    notifyListeners();
  }
}
