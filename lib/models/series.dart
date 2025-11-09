class Series {
  final int id;
  final String name;
  final String backdropPath;
  final String posterPath;
  final String overview;
  final double voteAverage;
  final List<Season> seasons;

  // Getters for backward compatibility
  String get title => name;
  int get year => DateTime.now().year; // Default year if not available

  Series({
    required this.id,
    required this.name,
    required this.backdropPath,
    required this.posterPath,
    required this.overview,
    required this.voteAverage,
    required this.seasons,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'],
      name: json['name'],
      backdropPath: json['backdrop_path'] ?? '',
      posterPath: json['poster_path'] ?? '',
      overview: json['overview'],
      voteAverage: (json['vote_average'] as num).toDouble(),
      seasons: (json['seasons'] as List)
          .map((season) => Season.fromJson(season))
          .toList(),
    );
  }
}

class Season {
  final int id;
  final int seasonNumber;
  final int episodeCount;
  final String name;
  final String overview;
  final String posterPath;
  List<Episode> episodes;

  Season({
    required this.id,
    required this.seasonNumber,
    required this.episodeCount,
    required this.name,
    required this.overview,
    required this.posterPath,
    this.episodes = const [],
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'],
      seasonNumber: json['season_number'],
      episodeCount: json['episode_count'],
      name: json['name'],
      overview: json['overview'],
      posterPath: json['poster_path'] ?? '',
    );
  }
}

class Episode {
  final int id;
  final String name;
  final int episodeNumber;
  final String overview;
  final String stillPath;

  Episode({
    required this.id,
    required this.name,
    required this.episodeNumber,
    required this.overview,
    required this.stillPath,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'],
      name: json['name'],
      episodeNumber: json['episode_number'],
      overview: json['overview'],
      stillPath: json['still_path'] ?? '',
    );
  }
}
