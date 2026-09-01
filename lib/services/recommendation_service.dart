import 'dart:math';

import 'tmdb_api_service.dart';
import 'watch_history_service.dart';

class RecommendationService {
  static final Map<String, List<Map<String, dynamic>>> _cache = {};
  static DateTime? _cacheTime;
  static const Duration _cacheTtl = Duration(minutes: 30);

  /// Analyze the user's watch history and return top genre IDs weighted by
  /// watch count and completion percentage. Fetches genres from TMDB for
  /// any items that don't have stored genre IDs.
  static Future<List<int>> getTopGenres({int limit = 5}) async {
    final history = await WatchHistoryService.getWatchHistory();
    if (history.isEmpty) return [];

    // Group unique items by tmdbId + isMovie to avoid duplicate API calls.
    final uniqueItems = <String, Map<String, dynamic>>{};
    for (final item in history) {
      final key = '${item['tmdbId']}_${item['isMovie']}';
      uniqueItems.putIfAbsent(key, () => item);
    }

    final genreWeights = <int, double>{};
    for (final item in uniqueItems.values) {
      List<int> genreIds = List<int>.from(
        item['genreIds'] ?? item['genre_ids'] ?? const [],
      );

      // Fetch from TMDB if no genre IDs stored.
      if (genreIds.isEmpty) {
        final tmdbId = int.tryParse(item['tmdbId']?.toString() ?? '') ?? 0;
        if (tmdbId > 0) {
          try {
            final isMovie = item['isMovie'] == true;
            final details = isMovie
                ? await TmdbApiService.getMovieDetails(tmdbId)
                : await TmdbApiService.getSeriesDetails(tmdbId);
            final genres = details?['genres'] as List<dynamic>? ?? [];
            genreIds = genres
                .map((g) => g['id'] as int)
                .toList();
          } catch (_) {
            // Skip — genre enrichment is best-effort.
          }
        }
      }
      if (genreIds.isEmpty) continue;

      final isWatched = item['isWatched'] == true;
      final watchPct = (item['watchPercentage'] as num?)?.toDouble() ?? 0.0;

      double weight = 1.0;
      if (isWatched) {
        weight = 2.0;
      } else if (watchPct > 0.5) {
        weight = 1.5;
      }

      for (final genreId in genreIds) {
        genreWeights[genreId] = (genreWeights[genreId] ?? 0) + weight;
      }
    }

    final sorted = genreWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  static bool _isStale() =>
      _cacheTime == null || DateTime.now().difference(_cacheTime!) > _cacheTtl;

  static Future<List<Map<String, dynamic>>> _fetchAndCache(
    String key,
    Future<List<Map<String, dynamic>>> Function() fetcher,
  ) async {
    if (!_isStale() && _cache.containsKey(key)) return _cache[key]!;
    final results = await fetcher();
    _cache[key] = results;
    _cacheTime = DateTime.now();
    return results;
  }

  /// "For You" — trending + popular filtered by the user's top genres,
  /// with a fallback to global trending if no watch history exists.
  static Future<List<Map<String, dynamic>>> getForYou({int page = 1}) async {
    final topGenres = await getTopGenres(limit: 3);
    if (topGenres.isEmpty) {
      return _fetchAndCache('forYou_global', () async {
        final movies = await TmdbApiService.fetchTrendingMovies(page: page);
        final series = await TmdbApiService.fetchTrendingSeries(page: page);
        return _mergeAndShuffle(movies, series, 'movie', 'tv');
      });
    }

    final genreParam = topGenres.join(',');
    return _fetchAndCache('forYou_$genreParam', () async {
      final movies = await TmdbApiService.getMoviesByGenre(
        topGenres.first,
        page: page,
      );
      final series = await TmdbApiService.getSeriesByGenre(
        topGenres.first,
        page: page,
      );
      return _mergeAndShuffle(movies, series, 'movie', 'tv');
    });
  }

  /// "Because You Watched {title}" — uses TMDB recommendations for the most
  /// recently-watched item (movie or episode). Previously this preferred any
  /// old `isWatched==true` entry, so a series watched last week could stay
  /// pinned even after bingeing new content. Now it always reflects the
  /// latest history entry so the row updates after every watch (movie,
  /// single episode, whole season or series).
  static Future<List<Map<String, dynamic>>> getBecauseYouWatched({
    int limit = 20,
  }) async {
    final history = await WatchHistoryService.getWatchHistory();
    if (history.isEmpty) return [];

    // Most recent entry (list is stored newest-first via insert(0) in
    // WatchHistoryService). This guarantees the row follows the latest watch.
    final recent = history.first;
    final tmdbId = int.tryParse(recent['tmdbId']?.toString() ?? '') ?? 0;
    if (tmdbId == 0) return [];

    final isMovie = recent['isMovie'] == true;
    final details = isMovie
        ? await TmdbApiService.getMovieDetails(tmdbId)
        : await TmdbApiService.getSeriesDetails(tmdbId);

    final recs = List<Map<String, dynamic>>.from(
      details?['recommendations']?['results'] ?? const [],
    );

    return recs.take(limit).map((item) {
      item['recommendedFrom'] = recent['title'] ?? recent['seriesTitle'] ?? '';
      item['recommendedMediaType'] = isMovie ? 'movie' : 'tv';
      return item;
    }).toList();
  }

  /// Genre rows — fetch content for each of the user's top genres.
  static Future<List<Map<String, dynamic>>> getByGenre(
    int genreId, {
    int page = 1,
  }) async {
    final movies = await TmdbApiService.getMoviesByGenre(genreId, page: page);
    final series = await TmdbApiService.getSeriesByGenre(genreId, page: page);
    return _mergeAndShuffle(movies, series, 'movie', 'tv');
  }

  /// Get new/trending content for the user's top genres (used by notifications).
  static Future<List<Map<String, dynamic>>> getNewReleasesForNotifications({
    int limit = 5,
  }) async {
    final topGenres = await getTopGenres(limit: 3);
    if (topGenres.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    for (final genreId in topGenres.take(2)) {
      final movies = await TmdbApiService.results('/discover/movie', {
        'with_genres': genreId,
        'sort_by': 'popularity.desc',
        'vote_count.gte': 200,
      });
      final series = await TmdbApiService.results('/discover/tv', {
        'with_genres': genreId,
        'sort_by': 'popularity.desc',
        'vote_count.gte': 200,
      });
      for (final item in [...movies, ...series]) {
        item['mediaType'] = item['media_type'] ??
            (item.containsKey('first_air_date') ? 'tv' : 'movie');
        results.add(item);
      }
    }

    results.shuffle(Random());
    return results.take(limit).toList();
  }

  static List<Map<String, dynamic>> _mergeAndShuffle(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
    String typeA,
    String typeB,
  ) {
    for (final item in a) {
      item['mediaType'] = typeA;
    }
    for (final item in b) {
      item['mediaType'] = typeB;
    }
    final merged = [...a, ...b];
    merged.shuffle(Random());
    return merged;
  }

  static void clearCache() {
    _cache.clear();
    _cacheTime = null;
  }
}
