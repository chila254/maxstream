import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class TmdbApiService {
  static const String _apiKey = ApiConfig.tmdbApiKey;
  static const String _baseUrl = ApiConfig.tmdbBaseUrl;
  static const Duration _timeout = Duration(seconds: 10);

  // Movies
  static Future<List<Map<String, dynamic>>> fetchTrendingMovies({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/trending/movie/week?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching trending movies: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchPopularMovies({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/popular?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching popular movies: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchTopRatedMovies({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/top_rated?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching top-rated movies: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchUpcomingMovies({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/upcoming?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching upcoming movies: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchNowPlayingMovies({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/now_playing?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching now playing movies: $e');
    }
    return [];
  }

  // TV Series
  static Future<List<Map<String, dynamic>>> fetchTrendingSeries({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/trending/tv/week?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching trending series: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchPopularSeries({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tv/popular?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching popular series: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchTopRatedSeries({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tv/top_rated?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching top-rated series: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchOnTheAirSeries({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tv/on_the_air?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching on the air series: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchAiringTodaySeries({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tv/airing_today?api_key=$_apiKey&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching airing today series: $e');
    }
    return [];
  }

  // Search
  static Future<List<Map<String, dynamic>>> searchMovies(String query, {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search/movie?api_key=$_apiKey&query=$query&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error searching movies: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> searchSeries(String query, {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search/tv?api_key=$_apiKey&query=$query&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error searching series: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> searchActors(String query, {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search/person?api_key=$_apiKey&query=$query&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error searching actors: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> searchAll(String query, {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search/multi?api_key=$_apiKey&query=$query&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error searching all: $e');
    }
    return [];
  }

  // Details
  static Future<Map<String, dynamic>?> getMovieDetails(int movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/$movieId?api_key=$_apiKey&append_to_response=credits,videos,similar,recommendations'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching movie details: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getSeriesDetails(int seriesId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tv/$seriesId?api_key=$_apiKey&append_to_response=credits,videos,similar,recommendations'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching series details: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getActorDetails(int actorId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/person/$actorId?api_key=$_apiKey&append_to_response=movie_credits,tv_credits,external_ids'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching actor details: $e');
    }
    return null;
  }

  // Season & Episode Details
  static Future<List<Map<String, dynamic>>> getSeasonEpisodes(int seriesId, int seasonNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tv/$seriesId/season/$seasonNumber?api_key=$_apiKey'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['episodes'] ?? []);
      }
    } catch (e) {
      print('Error fetching season episodes: $e');
    }
    return [];
  }

  // Genres
  static Future<Map<int, String>> fetchGenres(String type) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/genre/$type/list?api_key=$_apiKey'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          for (var genre in data['genres'])
            genre['id'] as int: genre['name'] as String,
        };
      }
    } catch (e) {
      print('Error fetching genres: $e');
    }
    return {};
  }

  static Future<List<Map<String, dynamic>>> getMoviesByGenre(int genreId, {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=$genreId&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching movies by genre: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getSeriesByGenre(int genreId, {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=$genreId&page=$page'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching series by genre: $e');
    }
    return [];
  }

  // Videos/Trailers
  static Future<String> getTrailerUrl(int id, {bool isMovie = true}) async {
    try {
      final type = isMovie ? 'movie' : 'tv';
      final response = await http.get(
        Uri.parse('$_baseUrl/$type/$id/videos?api_key=$_apiKey'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = List<Map<String, dynamic>>.from(data['results'] ?? []);
        
        final trailer = videos.firstWhere(
          (video) => video['type'] == 'Trailer' && video['site'] == 'YouTube',
          orElse: () => {},
        );
        
        if (trailer.containsKey('key')) {
          return 'https://www.youtube.com/watch?v=${trailer['key']}';
        }
      }
    } catch (e) {
      print('Error fetching trailer URL: $e');
    }
    return '';
  }

  static Future<List<Map<String, dynamic>>> getVideos(int id, {bool isMovie = true}) async {
    try {
      final type = isMovie ? 'movie' : 'tv';
      final response = await http.get(
        Uri.parse('$_baseUrl/$type/$id/videos?api_key=$_apiKey'),
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Error fetching videos: $e');
    }
    return [];
  }

  // Helper Methods
  static String getImageUrl(String? imagePath, {String size = 'w500'}) {
    if (imagePath == null || imagePath.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$imagePath';
  }

  static String getFullImageUrl(String? imagePath) {
    return getImageUrl(imagePath, size: 'original');
  }

  static String getPosterUrl(String? posterPath) {
    return getImageUrl(posterPath, size: 'w500');
  }

  static String getBackdropUrl(String? backdropPath) {
    return getImageUrl(backdropPath, size: 'w1280');
  }

  static String getProfileUrl(String? profilePath) {
    return getImageUrl(profilePath, size: 'w185');
  }

  // Enrich item with additional data
  static Future<Map<String, dynamic>> enrichItem(
    Map<String, dynamic> item,
    String mediaType,
  ) async {
    final id = item['id'];
    final isMovie = mediaType == 'movie';
    
    try {
      // Get genres
      final genresMap = await fetchGenres(mediaType);
      final genreIds = List<int>.from(item['genre_ids'] ?? []);
      final genreNames = genreIds
          .map((id) => genresMap[id] ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      // Get trailer URL
      final trailerUrl = await getTrailerUrl(id, isMovie: isMovie);

      // Add enriched data
      item['trailerUrl'] = trailerUrl;
      item['genres'] = genreNames;
      item['poster_url'] = getPosterUrl(item['poster_path']);
      item['backdrop_url'] = getBackdropUrl(item['backdrop_path']);
      
      return item;
    } catch (e) {
      print('Error enriching item: $e');
      return item;
    }
  }
}
