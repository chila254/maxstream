import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../database/db_helper.dart';
import '../models/movie.dart';
import 'watch_history_service.dart';

/// Syncs a user's watch history and watchlist between devices through
/// Firestore. Writes on any device push the activity to the user's document,
/// and a real-time listener (see [startListening]) mirrors every cloud change
/// back into local storage so all signed-in devices stay in sync live.
class CloudSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _pullInProgress = false;
  static bool _listening = false;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _historySub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _watchlistSub;

  /// Bumped whenever synced watch history changes; screens listen to refresh.
  static final ValueNotifier<int> historyRevision = ValueNotifier<int>(0);

  /// Bumped whenever synced watchlist changes; screens listen to refresh.
  static final ValueNotifier<int> watchlistRevision = ValueNotifier<int>(0);

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _watchHistoryRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('watch_history');

  static CollectionReference<Map<String, dynamic>> _watchlistRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('watchlist');

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

  /// Subscribes to the signed-in user's cloud subcollections and mirrors
  /// changes into local storage. No-op if already listening or signed out.
  static void startListening() {
    final uid = _uid;
    if (uid == null || _listening) return;
    _listening = true;
    _historySub = _watchHistoryRef(uid).snapshots().listen(
      _onHistorySnapshot,
      onError: (Object e) =>
          debugPrint('CloudSync: history listener error: $e'),
    );
    _watchlistSub = _watchlistRef(uid).snapshots().listen(
      _onWatchlistSnapshot,
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

  static void _onHistorySnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final tmdbId = (data['tmdbId'] ?? '').toString();
      final isMovie = data['isMovie'] == true;
      final season = (data['season'] as num?)?.toInt() ?? 0;
      final episode = (data['episode'] as num?)?.toInt() ?? 0;
      if (change.type == DocumentChangeType.removed) {
        unawaited(
          WatchHistoryService.removeFromHistoryLocal(
            tmdbId,
            isMovie,
            season,
            episode,
          ),
        );
      } else {
        unawaited(
          WatchHistoryService.importWatchProgress(
            Map<String, dynamic>.from(data),
          ),
        );
      }
    }
    historyRevision.value++;
  }

  static void _onWatchlistSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    for (final change in snapshot.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;
      final id = (data['id'] ?? '').toString();
      final mediaType = data['mediaType']?.toString() ?? 'movie';
      if (change.type == DocumentChangeType.removed) {
        unawaited(DBHelper.removeMovieLocal(id, mediaType));
      } else {
        unawaited(DBHelper.importWatchlist(_movieFromDoc(data)));
      }
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
      await _watchHistoryRef(uid).doc(key).set({
        ...item,
        'updatedAt': FieldValue.serverTimestamp(),
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
          .doc(watchHistoryKey(tmdbId, isMovie, season, episode))
          .delete();
    } catch (e) {
      debugPrint('CloudSync: watch progress delete failed: $e');
    }
  }

  static Future<void> pushWatchlist(Movie movie) async {
    final uid = _uid;
    if (uid == null || movie.id.isEmpty || movie.id == '0') return;
    try {
      await _watchlistRef(uid).doc(watchlistKey(movie.id, movie.mediaType)).set({
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
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('CloudSync: watchlist push failed: $e');
    }
  }

  static Future<void> deleteWatchlist(String id, String mediaType) async {
    final uid = _uid;
    if (uid == null || id.isEmpty) return;
    try {
      await _watchlistRef(uid).doc(watchlistKey(id, mediaType)).delete();
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
      for (final doc in historySnap.docs) {
        await WatchHistoryService.importWatchProgress(
          Map<String, dynamic>.from(doc.data()),
        );
      }

      final watchlistSnap = await _watchlistRef(uid).get();
      for (final doc in watchlistSnap.docs) {
        await DBHelper.importWatchlist(_movieFromDoc(doc.data()));
      }
    } catch (e) {
      debugPrint('CloudSync: pull failed: $e');
    } finally {
      _pullInProgress = false;
    }
  }

  static Movie _movieFromDoc(Map<String, dynamic> data) {
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
