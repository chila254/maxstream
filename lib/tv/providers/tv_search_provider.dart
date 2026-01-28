import 'package:flutter/material.dart';

/// Search screen state management
/// Handles search query, results, loading state, and focus
class TvSearchProvider extends ChangeNotifier {
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _movieResults = [];
  List<Map<String, dynamic>> _seriesResults = [];
  bool _isLoading = false;
  bool _showNoResults = false;
  bool _searchFocused = false;

  // Getters
  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  List<Map<String, dynamic>> get movieResults => _movieResults;
  List<Map<String, dynamic>> get seriesResults => _seriesResults;
  bool get isLoading => _isLoading;
  bool get showNoResults => _showNoResults;
  bool get searchFocused => _searchFocused;

  /// Update search query
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  /// Set search results
  void setSearchResults(
    List<Map<String, dynamic>> results,
    List<Map<String, dynamic>> movies,
    List<Map<String, dynamic>> series,
  ) {
    _searchResults = results;
    _movieResults = movies;
    _seriesResults = series;
    _showNoResults = results.isEmpty;
    notifyListeners();
  }

  /// Clear search results
  void clearResults() {
    _searchResults = [];
    _movieResults = [];
    _seriesResults = [];
    _showNoResults = false;
    notifyListeners();
  }

  /// Set loading state
  void setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  /// Set search focus state
  void setSearchFocused(bool value) {
    if (_searchFocused != value) {
      _searchFocused = value;
      notifyListeners();
    }
  }

  /// Reset search state
  void resetSearch() {
    _searchQuery = '';
    _searchResults = [];
    _movieResults = [];
    _seriesResults = [];
    _isLoading = false;
    _showNoResults = false;
    _searchFocused = false;
    notifyListeners();
  }
}
