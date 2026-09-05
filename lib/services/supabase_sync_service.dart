import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../database/db_helper.dart';
import '../models/movie.dart';
import 'cloud_sync_service.dart';
import 'watch_history_service.dart';

/// Full cloud sync via Supabase (free) - watches, watchlist, provider_prefs, downloads, settings.
/// Uses Firebase UID as user_id so you keep Firebase Auth, just data lives in Supabase Postgres.
/// Realtime Postgres Changes mirrors Firebase RTDB onValue.
class SupabaseSyncService {
  static SupabaseClient? _client;
  static bool _initialized = false;
  static bool _listening = false;
  static RealtimeChannel? _historyChan;
  static RealtimeChannel? _watchlistChan;
  static RealtimeChannel? _prefsChan;

  static final ValueNotifier<int> historyRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> watchlistRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> prefsRevision = ValueNotifier<int>(0);

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static SupabaseClient get _supa {
    if (_client == null) throw StateError('Supabase not initialized');
    return _client!;
  }

  static Future<void> initialize() async {
    if (_initialized || !SupabaseConfig.isConfigured) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _initialized = true;
      debugPrint('SupabaseSync: initialized');
    } catch (e) {
      debugPrint('SupabaseSync init failed: $e');
    }
  }

  static bool get isAvailable => _initialized && _uid != null;

  // -----------------------------------------------------------------
  // Realtime
  // -----------------------------------------------------------------
  static void startListening() {
    if (!isAvailable || _listening) return;
    _listening = true;
    final uid = _uid!;
    // Backfill once on sign-in
    unawaited(pushEntireWatchlist());
    unawaited(pushEntireHistory());

    _historyChan = _supa.channel('watch_history:$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'watch_history',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
        callback: (payload) async {
          final rec = payload.newRecord;
          if (rec.isEmpty) return;
          await WatchHistoryService.importWatchProgress(_fromSupaHistory(rec));
          historyRevision.value++;
          CloudSyncService.historyRevision.value++;
        },
      )
      ..subscribe();

    _watchlistChan = _supa.channel('watchlist:$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'watchlist',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
        callback: (payload) async {
          final rec = payload.newRecord;
          if (rec.isEmpty) return;
          await DBHelper.importWatchlist(_movieFromSupa(rec));
          watchlistRevision.value++;
          CloudSyncService.watchlistRevision.value++;
        },
      )
      ..subscribe();

    _prefsChan = _supa.channel('prefs:$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'provider_preferences',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
        callback: (payload) async {
          final rec = payload.newRecord;
          if (rec.isEmpty) return;
          await DBHelper.setProviderPreference(rec['provider_id'] as int, rec['is_preferred'] as bool, pushToCloud: false);
          prefsRevision.value++;
          CloudSyncService.prefsRevision.value++;
        },
      )
      ..subscribe();
  }

  static void stopListening() {
    _historyChan?.unsubscribe();
    _watchlistChan?.unsubscribe();
    _prefsChan?.unsubscribe();
    _historyChan = null;
    _watchlistChan = null;
    _prefsChan = null;
    _listening = false;
  }

  // -----------------------------------------------------------------
  // Push
  // -----------------------------------------------------------------
  static String _historyKey(String tmdbId, bool isMovie, int season, int episode) =>
      isMovie ? 'movie_$tmdbId' : 'tv_${tmdbId}_${season}_$episode';

  static Future<void> pushWatchProgress(Map<String, dynamic> item) async {
    if (!isAvailable) return;
    final tmdbId = (item['tmdbId'] ?? '').toString();
    if (tmdbId.isEmpty || tmdbId == '0') return;
    try {
      await _supa.from('watch_history').upsert({
        'user_id': _uid,
        'tmdb_id': tmdbId,
        'is_movie': item['isMovie'] == true,
        'season': (item['season'] as num?)?.toInt() ?? 0,
        'episode': (item['episode'] as num?)?.toInt() ?? 0,
        'title': item['title'] ?? '',
        'series_title': item['seriesTitle'],
        'poster_url': item['posterUrl'] ?? '',
        'position_seconds': (item['position'] as num?)?.toDouble() ?? 0,
        'duration_seconds': (item['duration'] as num?)?.toDouble() ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,tmdb_id,is_movie,season,episode');
    } catch (e) {
      debugPrint('Supabase pushHistory failed: $e');
    }
  }

  static Future<void> deleteWatchProgress(String tmdbId, bool isMovie, int season, int episode) async {
    if (!isAvailable) return;
    try {
      await _supa
          .from('watch_history')
          .delete()
          .eq('user_id', _uid!)
          .eq('tmdb_id', tmdbId)
          .eq('is_movie', isMovie)
          .eq('season', season)
          .eq('episode', episode);
    } catch (e) {
      debugPrint('Supabase deleteHistory failed: $e');
    }
  }

  static Future<void> pushWatchlist(Movie movie) async {
    if (!isAvailable || movie.id.isEmpty) return;
    try {
      await _supa.from('watchlist').upsert({
        'user_id': _uid,
        'id': movie.id,
        'media_type': movie.mediaType,
        'title': movie.title,
        'description': movie.description,
        'thumbnail': movie.thumbnail,
        'backdrop': movie.backdrop,
        'video_url': movie.videoUrl,
        'trailer_url': movie.trailerUrl,
        'genres': movie.genres.join(','),
        'year': movie.year,
        'rating': movie.rating,
        'country': movie.country,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,id,media_type');
    } catch (e) {
      debugPrint('Supabase pushWatchlist failed: $e');
    }
  }

  static Future<void> deleteWatchlist(String id, String mediaType) async {
    if (!isAvailable) return;
    try {
      await _supa.from('watchlist').delete().eq('user_id', _uid!).eq('id', id).eq('media_type', mediaType);
    } catch (e) {
      debugPrint('Supabase deleteWatchlist failed: $e');
    }
  }

  static Future<void> pushProviderPreference(int providerId, String providerName, bool isPreferred) async {
    if (!isAvailable) return;
    try {
      await _supa.from('provider_preferences').upsert({
        'user_id': _uid,
        'provider_id': providerId,
        'provider_name': providerName,
        'is_preferred': isPreferred,
      }, onConflict: 'user_id,provider_id');
    } catch (e) {
      debugPrint('Supabase pushPref failed: $e');
    }
  }

  static Future<void> pushProviderPrefs() async {
    if (!isAvailable) return;
    try {
      final prefs = await DBHelper.getProviderPreferences();
      for (final row in prefs) {
        await _supa.from('provider_preferences').upsert({
          'user_id': _uid,
          'provider_id': row['providerId'],
          'provider_name': row['providerName'],
          'is_preferred': (row['isPreferred'] as int) == 1,
        }, onConflict: 'user_id,provider_id');
      }
    } catch (e) {
      debugPrint('Supabase pushPrefs failed: $e');
    }
  }

  static Future<void> pushEntireWatchlist() async {
    if (!isAvailable) return;
    try {
      final items = await DBHelper.getWatchlist();
      for (final m in items) await pushWatchlist(m);
      await pushProviderPrefs();
    } catch (e) {
      debugPrint('Supabase backfill failed: $e');
    }
  }

  static Future<void> pushEntireHistory() async {
    if (!isAvailable) return;
    try {
      final history = await WatchHistoryService.getWatchHistory();
      for (final h in history) await pushWatchProgress(h);
    } catch (e) {
      debugPrint('Supabase backfill history failed: $e');
    }
  }

  // -----------------------------------------------------------------
  // Pull
  // -----------------------------------------------------------------
  static Future<void> pullToDevice() async {
    if (!isAvailable) return;
    try {
      final history = await _supa.from('watch_history').select().eq('user_id', _uid!);
      for (final row in history as List) {
        await WatchHistoryService.importWatchProgress(_fromSupaHistory(row as Map<String, dynamic>));
      }
      final wl = await _supa.from('watchlist').select().eq('user_id', _uid!);
      for (final row in wl as List) {
        await DBHelper.importWatchlist(_movieFromSupa(row as Map<String, dynamic>));
      }
      final prefs = await _supa.from('provider_preferences').select().eq('user_id', _uid!);
      for (final row in prefs as List) {
        final r = row as Map<String, dynamic>;
        await DBHelper.setProviderPreference(r['provider_id'] as int, r['is_preferred'] as bool, pushToCloud: false);
      }
      historyRevision.value++;
      watchlistRevision.value++;
      prefsRevision.value++;
    } catch (e) {
      debugPrint('Supabase pull failed: $e');
    }
  }

  // -----------------------------------------------------------------
  // Mappers
  // -----------------------------------------------------------------
  static Map<String, dynamic> _fromSupaHistory(Map<String, dynamic> r) => {
        'tmdbId': r['tmdb_id']?.toString() ?? '',
        'isMovie': r['is_movie'] == true,
        'season': r['season'] ?? 0,
        'episode': r['episode'] ?? 0,
        'title': r['title'] ?? '',
        'seriesTitle': r['series_title'],
        'posterUrl': r['poster_url'] ?? '',
        'position': r['position_seconds'] ?? 0,
        'duration': r['duration_seconds'] ?? 0,
      };

  static Movie _movieFromSupa(Map<String, dynamic> r) => Movie(
        id: (r['id'] ?? '').toString(),
        title: r['title']?.toString() ?? '',
        description: r['description']?.toString() ?? '',
        thumbnail: r['thumbnail']?.toString() ?? '',
        backdrop: r['backdrop']?.toString() ?? '',
        videoUrl: r['video_url']?.toString() ?? '',
        trailerUrl: r['trailer_url']?.toString() ?? '',
        genres: (r['genres']?.toString() ?? '').split(',').where((g) => g.isNotEmpty).toList(),
        year: r['year']?.toString() ?? '',
        rating: (r['rating'] as num?)?.toDouble() ?? 0.0,
        mediaType: r['media_type']?.toString() ?? 'movie',
        country: r['country']?.toString() ?? '',
      );
}
