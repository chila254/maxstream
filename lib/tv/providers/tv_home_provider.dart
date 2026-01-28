import 'package:flutter/material.dart';

/// Home screen state management
/// Handles async data loading, trending/popular content, continue watching
class TvHomeProvider extends ChangeNotifier {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _trendingMovies = [];
  List<Map<String, dynamic>> _trendingSeries = [];
  List<Map<String, dynamic>> _popularMovies = [];
  List<Map<String, dynamic>> _topRatedMovies = [];
  List<Map<String, dynamic>> _continueWatching = [];

  int _heroCurrentIndex = 0;
  double _scrollOffset = 0;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get trendingMovies => _trendingMovies;
  List<Map<String, dynamic>> get trendingSeries => _trendingSeries;
  List<Map<String, dynamic>> get popularMovies => _popularMovies;
  List<Map<String, dynamic>> get topRatedMovies => _topRatedMovies;
  List<Map<String, dynamic>> get continueWatching => _continueWatching;

  int get heroCurrentIndex => _heroCurrentIndex;
  double get scrollOffset => _scrollOffset;

  /// Set loading state
  void setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  /// Set error message
  void setErrorMessage(String? message) {
    if (_errorMessage != message) {
      _errorMessage = message;
      notifyListeners();
    }
  }

  /// Set trending movies
  void setTrendingMovies(List<Map<String, dynamic>> movies) {
    _trendingMovies = movies;
    notifyListeners();
  }

  /// Set trending series
  void setTrendingSeries(List<Map<String, dynamic>> series) {
    _trendingSeries = series;
    notifyListeners();
  }

  /// Set popular movies
  void setPopularMovies(List<Map<String, dynamic>> movies) {
    _popularMovies = movies;
    notifyListeners();
  }

  /// Set top rated movies
  void setTopRatedMovies(List<Map<String, dynamic>> movies) {
    _topRatedMovies = movies;
    notifyListeners();
  }

  /// Set continue watching
  void setContinueWatching(List<Map<String, dynamic>> items) {
    _continueWatching = items;
    notifyListeners();
  }

  /// Set all content at once
  void setAllContent({
    required List<Map<String, dynamic>> trending,
    required List<Map<String, dynamic>> trendingSeries,
    required List<Map<String, dynamic>> popular,
    required List<Map<String, dynamic>> topRated,
    required List<Map<String, dynamic>> continueWatching,
  }) {
    _trendingMovies = trending;
    _trendingSeries = trendingSeries;
    _popularMovies = popular;
    _topRatedMovies = topRated;
    _continueWatching = continueWatching;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Update hero banner index
  void setHeroIndex(int index) {
    if (_heroCurrentIndex != index) {
      _heroCurrentIndex = index;
      notifyListeners();
    }
  }

  /// Update scroll position
  void setScrollOffset(double offset) {
    if (_scrollOffset != offset) {
      _scrollOffset = offset;
      notifyListeners();
    }
  }

  /// Clear all data
  void clear() {
    _isLoading = true;
    _errorMessage = null;
    _trendingMovies = [];
    _trendingSeries = [];
    _popularMovies = [];
    _topRatedMovies = [];
    _continueWatching = [];
    _heroCurrentIndex = 0;
    _scrollOffset = 0;
    notifyListeners();
  }
}
