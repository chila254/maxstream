import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../database/db_helper.dart';
import '../models/movie.dart';
import 'watch_history_service.dart';

/// Syncs a user's watch history and watchlist between devices through
/// Firebase Realtime Database. Writes on any device push the activity to the
/// user's node, and a real-time listener (see [startListening]) mirrors every
/// cloud change back into local storage so all signed-in devices stay in sync.
class CloudSyncService {
  static final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  static bool _pullInProgress = false;
  static bool _listening = false;
  static StreamSubscription<DatabaseEvent>? _historySub;
  static StreamSubscription<DatabaseEvent>? _watchlistSub;

  /// Bumped whenever synced watch history changes; screens listen to refresh.
  static final ValueNotifier<int> historyRevision = ValueNotifier<int>(0);

  /// Bumped whenever synced watchlist changes; screens listen to refresh.
  static final ValueNotifier<int> watchlistRevision = ValueNotifier<int>(0);

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DatabaseReference _watchHistoryRef(String uid) =>
      _rtdb.ref('users/$uid/watch_history');

  static DatabaseReference _watchlistRef(String uid) =>
      _rtdb.ref('users/$uid/watchlist');

  /// Deterministic doc id for a watch-history item. Keep in sync with
  /// WatchHistoryService.getWatchHistoryKey.
  static String watchHistoryKey(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) {
    return isMovie ? 'movie_$tmdbId' : 'tv_${tmdbId}_${season}_$episode';
  }

  static String watchlistKey(String id, String mediaType) =>
      '${id}_$mediaType';

  // ---------------------------------------------------------------------
  // Real-time listener
  // ---------------------------------------------------------------------

  /// Subscribes to the signed-in user's cloud nodes and mirrors
  /// changes into local storage. No-op if already listening or signed out.
  /// Uploads the device's entire local watchlist to the cloud. This backfills
  /// items that were added before cloud sync existed (or while the other device
  /// was offline) so they appear on every signed-in device, not just items
  /// added after the sync feature was enabled. Idempotent (upsert by key).
  static Future<void> pushEntireWatchlist() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final items = await DBHelper.getWatchlist();
      for (final movie in items) {
        await pushWatchlist(movie);
      }
    } catch (e) {
      debugPrint('CloudSync: backfill watchlist failed: $e');
    }
  }

  static void startListening() {
    final uid = _uid;
    if (uid == null || _listening) return;
    _listening = true;
    // Backfill any pre-existing local watchlist entries to the cloud as soon
    // as we're signed in, so other devices can pull them.
    unawaited(pushEntireWatchlist());
    _historySub = _watchHistoryRef(uid).onValue.listen(
      _onHistoryEvent,
      onError: (Object e) =>
          debugPrint('CloudSync: history listener error: $e'),
    );
    _watchlistSub = _watchlistRef(uid).onValue.listen(
      _onWatchlistEvent,
      onError: (Object e) =>
          debugPrint('CloudSync: watchlist listener error: $e'),
    );
  }

  /// Cancels the real-time subscriptions.
  static void stopListening() {
    _historySub?.cancel();
    _watchlistSub?.cancel();
    _historySub = null;
    _watchlistSub = null;
    _listening = false;
  }

  static void _onHistoryEvent(DatabaseEvent event) {
    final snapshot = event.snapshot;
    if (snapshot.value == null) return;
    final data = Map<String, dynamic>.from(snapshot.value as Map);

    for (final entry in data.entries) {
      final value = Map<String, dynamic>.from(entry.value as Map);
      final tmdbId = (value['tmdbId'] ?? '').toString();
      if (tmdbId.isEmpty) continue;
      unawaited(
        WatchHistoryService.importWatchProgress(value),
      );
    }
    historyRevision.value++;
  }

  static void _onWatchlistEvent(DatabaseEvent event) {
    final snapshot = event.snapshot;
    if (snapshot.value == null) return;
    final data = Map<String, dynamic>.from(snapshot.value as Map);

    for (final entry in data.entries) {
      final value = Map<String, dynamic>.from(entry.value as Map);
      final id = (value['id'] ?? '').toString();
      if (id.isEmpty) continue;
      unawaited(DBHelper.importWatchlist(_movieFromData(value)));
    }
    watchlistRevision.value++;
  }

  // ---------------------------------------------------------------------
  // Push (called from phone/TV write paths)
  // ---------------------------------------------------------------------

  static Future<void> pushWatchProgress(Map<String, dynamic> item) async {
    final uid = _uid;
    final tmdbId = (item['tmdbId'] ?? '').toString();
    if (uid == null || tmdbId.isEmpty || tmdbId == '0') return;
    final key = watchHistoryKey(
      tmdbId,
      item['isMovie'] == true,
      (item['season'] as num?)?.toInt() ?? 0,
      (item['episode'] as num?)?.toInt() ?? 0,
    );
    try {
      await _watchHistoryRef(uid).child(key).set({
        ...item,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('CloudSync: watch progress push failed: $e');
    }
  }

  static Future<void> deleteWatchProgress(
    String tmdbId,
    bool isMovie,
    int season,
    int episode,
  ) async {
    final uid = _uid;
    if (uid == null || tmdbId.isEmpty) return;
    try {
      await _watchHistoryRef(uid)
          .child(watchHistoryKey(tmdbId, isMovie, season, episode))
          .remove();
    } catch (e) {
      debugPrint('CloudSync: watch progress delete failed: $e');
    }
  }

  static Future<void> pushWatchlist(Movie movie) async {
    final uid = _uid;
    if (uid == null || movie.id.isEmpty || movie.id == '0') return;
    try {
      await _watchlistRef(uid).child(watchlistKey(movie.id, movie.mediaType)).set({
        'id': movie.id,
        'title': movie.title,
        'description': movie.description,
        'thumbnail': movie.thumbnail,
        'backdrop': movie.backdrop,
        'videoUrl': movie.videoUrl,
        'trailerUrl': movie.trailerUrl,
        'genres': movie.genres,
        'year': movie.year,
        'rating': movie.rating,
        'mediaType': movie.mediaType,
        'country': movie.country,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('CloudSync: watchlist push failed: $e');
    }
  }

  static Future<void> deleteWatchlist(String id, String mediaType) async {
    final uid = _uid;
    if (uid == null || id.isEmpty) return;
    try {
      await _watchlistRef(uid).child(watchlistKey(id, mediaType)).remove();
    } catch (e) {
      debugPrint('CloudSync: watchlist delete failed: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Pull (called on TV sign-in / home + watchlist loads)
  // ---------------------------------------------------------------------

  /// Pulls the signed-in user's cloud data into local storage. Safe to call
  /// repeatedly; concurrent pulls are collapsed into one.
  static Future<void> pullToDevice() async {
    final uid = _uid;
    if (uid == null || _pullInProgress) return;
    _pullInProgress = true;
    try {
      final historySnap = await _watchHistoryRef(uid).get();
      if (historySnap.value != null) {
        final data = Map<String, dynamic>.from(historySnap.value as Map);
        for (final entry in data.entries) {
          final value = Map<String, dynamic>.from(entry.value as Map);
          await WatchHistoryService.importWatchProgress(value);
        }
      }

      final watchlistSnap = await _watchlistRef(uid).get();
      if (watchlistSnap.value != null) {
        final data = Map<String, dynamic>.from(watchlistSnap.value as Map);
        for (final entry in data.entries) {
          final value = Map<String, dynamic>.from(entry.value as Map);
          await DBHelper.importWatchlist(_movieFromData(value));
        }
      }
    } catch (e) {
      debugPrint('CloudSync: pull failed: $e');
    } finally {
      _pullInProgress = false;
    }
  }

  static Movie _movieFromData(Map<String, dynamic> data) {
    final rawGenres = data['genres'];
    final genres = rawGenres is List
        ? rawGenres.map((g) => g.toString()).toList()
        : (rawGenres?.toString() ?? '')
            .split(',')
            .where((g) => g.isNotEmpty)
            .toList();
    return Movie(
      id: (data['id'] ?? '').toString(),
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      thumbnail: data['thumbnail']?.toString() ?? '',
      backdrop: data['backdrop']?.toString() ?? '',
      videoUrl: data['videoUrl']?.toString() ?? '',
      trailerUrl: data['trailerUrl']?.toString() ?? '',
      genres: genres,
      year: data['year']?.toString() ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      mediaType: data['mediaType']?.toString() ?? 'movie',
      country: data['country']?.toString() ?? '',
    );
  }
}
