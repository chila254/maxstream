import 'package:flutter/material.dart';

/// Details screen state management
/// Handles movie/series details, cast, recommendations, watchlist state
class TvDetailsProvider extends ChangeNotifier {
  bool _isLoading = true;
  bool _isLoadingEpisodes = false;
  String? _errorMessage;

  Map<String, dynamic>? _details;
  List<Map<String, dynamic>> _cast = [];
  List<Map<String, dynamic>> _recommendations = [];
  bool _isInWatchlist = false;

  // For series
  List<Season> _seasons = [];
  int _selectedSeasonIndex = 0;
  List<Episode> _currentEpisodes = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingEpisodes => _isLoadingEpisodes;
  String? get errorMessage => _errorMessage;

  Map<String, dynamic>? get details => _details;
  List<Map<String, dynamic>> get cast => _cast;
  List<Map<String, dynamic>> get recommendations => _recommendations;
  bool get isInWatchlist => _isInWatchlist;

  List<Season> get seasons => _seasons;
  int get selectedSeasonIndex => _selectedSeasonIndex;
  List<Episode> get currentEpisodes => _currentEpisodes;

  /// Set loading state
  void setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  /// Set episode loading state
  void setLoadingEpisodes(bool value) {
    if (_isLoadingEpisodes != value) {
      _isLoadingEpisodes = value;
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

  /// Set details
  void setDetails(Map<String, dynamic> details) {
    _details = details;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Set cast
  void setCast(List<Map<String, dynamic>> cast) {
    _cast = cast;
    notifyListeners();
  }

  /// Set recommendations
  void setRecommendations(List<Map<String, dynamic>> recommendations) {
    _recommendations = recommendations;
    notifyListeners();
  }

  /// Toggle watchlist status
  void toggleWatchlist() {
    _isInWatchlist = !_isInWatchlist;
    notifyListeners();
  }

  /// Set watchlist status
  void setWatchlistStatus(bool inWatchlist) {
    if (_isInWatchlist != inWatchlist) {
      _isInWatchlist = inWatchlist;
      notifyListeners();
    }
  }

  // Series-specific methods

  /// Set seasons (for series)
  void setSeasons(List<Season> seasons) {
    _seasons = seasons;
    notifyListeners();
  }

  /// Set selected season and episodes
  void setSeasonAndEpisodes(int seasonIndex, List<Episode> episodes) {
    if (_selectedSeasonIndex != seasonIndex) {
      _selectedSeasonIndex = seasonIndex;
      _currentEpisodes = episodes;
      notifyListeners();
    }
  }

  /// Set current episodes for selected season
  void setCurrentEpisodes(List<Episode> episodes) {
    _currentEpisodes = episodes;
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _isLoading = true;
    _isLoadingEpisodes = false;
    _errorMessage = null;
    _details = null;
    _cast = [];
    _recommendations = [];
    _isInWatchlist = false;
    _seasons = [];
    _selectedSeasonIndex = 0;
    _currentEpisodes = [];
    notifyListeners();
  }
}

/// Season model for series
class Season {
  final int id;
  final int seasonNumber;
  final String name;
  final String? posterPath;
  final int episodeCount;

  Season({
    required this.id,
    required this.seasonNumber,
    required this.name,
    required this.posterPath,
    required this.episodeCount,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] ?? 0,
      seasonNumber: json['season_number'] ?? 0,
      name: json['name'] ?? 'Season ${json['season_number']}',
      posterPath: json['poster_path'],
      episodeCount: json['episode_count'] ?? 0,
    );
  }
}

/// Episode model for series
class Episode {
  final int id;
  final int episodeNumber;
  final String name;
  final String? overview;
  final String? stillPath;
  final int? runtime;
  final double? voteAverage;

  Episode({
    required this.id,
    required this.episodeNumber,
    required this.name,
    required this.overview,
    required this.stillPath,
    required this.runtime,
    required this.voteAverage,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] ?? 0,
      episodeNumber: json['episode_number'] ?? 0,
      name: json['name'] ?? 'Episode ${json['episode_number']}',
      overview: json['overview'],
      stillPath: json['still_path'],
      runtime: json['runtime'],
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
    );
  }
}
