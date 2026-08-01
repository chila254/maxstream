import 'package:flutter/material.dart';

/// TV navigation state management.
/// Handles instant UI updates with async data loading
/// Persists scroll positions and focus state across navigation
///
/// Focus Convention:
/// - Home screen starts on content (hero banner), NOT sidebar
/// - Sidebar is secondary navigation
/// - LEFT from content → sidebar
/// - RIGHT from sidebar → content
class TvNavigationProvider extends ChangeNotifier {
  int _selectedTab = 0;
  bool _focusOnSidebar = false; // Content-first: default to content
  bool _isDeepNavigating = false;
  bool _searchFocused = false;

  // Cache for each tab's scroll offset and focused item
  final Map<int, double> _tabScrollOffsets = {};
  final Map<int, int> _tabFocusedIndices = {};
  final Map<int, int> _sectionFocusIndices = {};
  final Map<String, int> _rowFocusedIndices = {};
  final Map<int, String> _activeRowIds = {};

  // Store ScrollControllers for restoration
  final Map<int, ScrollController> _tabScrollControllers = {};

  int get selectedTab => _selectedTab;
  bool get focusOnSidebar => _focusOnSidebar;
  bool get isDeepNavigating => _isDeepNavigating;
  bool get searchFocused => _searchFocused;

  /// Switch tab instantly with UI feedback, load data async
  void selectTab(int index) {
    if (_selectedTab != index) {
      _selectedTab = index;
      _focusOnSidebar = false; // Move focus to content after selection
      _isDeepNavigating = false;
      _searchFocused = false;
      notifyListeners();
    }
  }

  /// Move focus between sidebar and content
  void setFocusOnSidebar(bool value) {
    if (_focusOnSidebar != value) {
      _focusOnSidebar = value;
      _searchFocused = false;
      notifyListeners();
    }
  }

  /// Set search focus state (for Search screen integration)
  void setSearchFocused(bool value) {
    if (_searchFocused != value) {
      _searchFocused = value;
      if (value) {
        _focusOnSidebar = false;
      }
      notifyListeners();
    }
  }

  /// Track when entering deep navigation (details, player, etc)
  void setDeepNavigating(bool value) {
    _isDeepNavigating = value;
    notifyListeners();
  }

  /// Save scroll offset for current tab (for restoration)
  void saveScrollOffset(int tabIndex, double offset) {
    _tabScrollOffsets[tabIndex] = offset;
  }

  /// Get saved scroll offset for tab
  double getScrollOffset(int tabIndex) {
    return _tabScrollOffsets[tabIndex] ?? 0.0;
  }

  /// Register ScrollController for a tab
  void registerScrollController(int tabIndex, ScrollController controller) {
    _tabScrollControllers[tabIndex] = controller;
  }

  /// Get ScrollController for a tab
  ScrollController? getScrollController(int tabIndex) {
    return _tabScrollControllers[tabIndex];
  }

  /// Restore scroll position when returning from deep navigation
  void restoreScrollPosition(int tabIndex) {
    final controller = _tabScrollControllers[tabIndex];
    final offset = _tabScrollOffsets[tabIndex];

    if (controller != null && offset != null && offset > 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (controller.hasClients) {
          controller.jumpTo(offset);
        }
      });
    }
  }

  /// Save focused item index for current tab
  void saveFocusedIndex(int tabIndex, int index) {
    _tabFocusedIndices[tabIndex] = index;
  }

  /// Get focused item index for tab
  int getFocusedIndex(int tabIndex) {
    return _tabFocusedIndices[tabIndex] ?? 0;
  }

  /// Save section focus index (for D-Pad navigation within screen)
  void setSectionFocusIndex(int tabIndex, int index) {
    _sectionFocusIndices[tabIndex] = index;
  }

  /// Get section focus index
  int getSectionFocusIndex(int tabIndex) {
    return _sectionFocusIndices[tabIndex] ?? 0;
  }

  /// Saves the focused item for a stable row identifier.
  void saveRowFocusedIndex(String rowId, int index) {
    _rowFocusedIndices[rowId] = index;
  }

  /// Returns the last focused item for a stable row identifier.
  int getRowFocusedIndex(String rowId) => _rowFocusedIndices[rowId] ?? 0;

  /// Remembers which stable rail had focus on a tab.
  void saveActiveRowId(int tabIndex, String rowId) {
    _activeRowIds[tabIndex] = rowId;
  }

  String? getActiveRowId(int tabIndex) => _activeRowIds[tabIndex];

  /// Return to sidebar and restore scroll position
  void returnToSidebar() {
    _focusOnSidebar = true;
    _isDeepNavigating = false;
    _searchFocused = false;
    // Restore scroll position for current tab
    restoreScrollPosition(_selectedTab);
    notifyListeners();
  }

  /// Clear all cached state (for logout)
  void clearState() {
    _selectedTab = 0;
    _focusOnSidebar = false; // Content-first reset
    _isDeepNavigating = false;
    _searchFocused = false;
    _tabScrollOffsets.clear();
    _tabFocusedIndices.clear();
    _sectionFocusIndices.clear();
    _rowFocusedIndices.clear();
    _activeRowIds.clear();
    notifyListeners();
  }
}
