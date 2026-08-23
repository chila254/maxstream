import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/movie.dart';
import '../services/cloud_sync_service.dart';
import '../services/user_scope.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (kIsWeb) throw UnsupportedError('sqflite is not available on web');
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'watchlist.db');
    return openDatabase(
      path,
      version: 10,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  static Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE watchlist (
        ownerId TEXT NOT NULL,
        id TEXT NOT NULL,
        title TEXT,
        description TEXT,
        thumbnail TEXT,
        videoUrl TEXT,
        trailerUrl TEXT,
        genres TEXT,
        releaseDate TEXT,
        year TEXT,
        rating REAL,
        mediaType TEXT NOT NULL,
        isDownloaded INTEGER DEFAULT 0,
        offlinePath TEXT,
        PRIMARY KEY (ownerId, id, mediaType)
      )
    ''');

    await db.execute('''
      CREATE TABLE downloaded_episodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        seriesId INTEGER,
        seriesTitle TEXT,
        seasonNumber INTEGER,
        episodeNumber INTEGER,
        episodeId INTEGER,
        episodeTitle TEXT,
        episodeDescription TEXT,
        thumbnail TEXT,
        offlinePath TEXT,
        downloadDate TEXT,
        UNIQUE(seriesId, seasonNumber, episodeNumber)
      )
    ''');

    await _createMediaDownloadsTable(db);
  }

  static Future<void> _upgradeDb(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE watchlist ADD COLUMN genres TEXT');
      await db.execute('ALTER TABLE watchlist ADD COLUMN releaseDate TEXT');
      await db.execute('ALTER TABLE watchlist ADD COLUMN rating REAL');
      await db.execute('ALTER TABLE watchlist ADD COLUMN mediaType TEXT');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE watchlist ADD COLUMN isDownloaded INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE watchlist ADD COLUMN offlinePath TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE downloaded_episodes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          seriesId INTEGER,
          seriesTitle TEXT,
          seasonNumber INTEGER,
          episodeNumber INTEGER,
          episodeId INTEGER,
          episodeTitle TEXT,
          episodeDescription TEXT,
          thumbnail TEXT,
          offlinePath TEXT,
          downloadDate TEXT,
          UNIQUE(seriesId, seasonNumber, episodeNumber)
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE watchlist ADD COLUMN year TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS provider_preferences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          providerId INTEGER UNIQUE,
          providerName TEXT,
          isPreferred INTEGER DEFAULT 0,
          addedDate TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      // Ensure the table exists (may have been skipped if DB was already at v6+)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS provider_preferences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          providerId INTEGER UNIQUE,
          providerName TEXT,
          isPreferred INTEGER DEFAULT 0,
          addedDate TEXT
        )
      ''');
      // Fix mismatched provider IDs: Apple TV (192→350), AMC+ (591→526)
      await db.rawUpdate('''
        UPDATE provider_preferences
        SET providerId = 350, providerName = 'Apple TV'
        WHERE providerId = 192
      ''');
      await db.rawUpdate('''
        UPDATE provider_preferences
        SET providerId = 526, providerName = 'AMC+'
        WHERE providerId = 591
      ''');
    }
    if (oldVersion < 8) {
      await _createMediaDownloadsTable(db);
    } else if (oldVersion < 9) {
      await db.execute(
        "ALTER TABLE media_downloads ADD COLUMN subtitles TEXT NOT NULL DEFAULT '[]'",
      );
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE watchlist RENAME TO watchlist_legacy');
      await db.execute('''
        CREATE TABLE watchlist (
          ownerId TEXT NOT NULL,
          id TEXT NOT NULL,
          title TEXT,
          description TEXT,
          thumbnail TEXT,
          videoUrl TEXT,
          trailerUrl TEXT,
          genres TEXT,
          releaseDate TEXT,
          year TEXT,
          rating REAL,
          mediaType TEXT NOT NULL,
          isDownloaded INTEGER DEFAULT 0,
          offlinePath TEXT,
          PRIMARY KEY (ownerId, id, mediaType)
        )
      ''');
      await db.rawInsert(
        '''
        INSERT INTO watchlist
          (ownerId, id, title, description, thumbnail, videoUrl, trailerUrl,
           genres, releaseDate, year, rating, mediaType, isDownloaded, offlinePath)
        SELECT ?, CAST(id AS TEXT), title, description, thumbnail, videoUrl,
          trailerUrl, genres, releaseDate, year, rating,
          COALESCE(NULLIF(mediaType, ''), 'movie'), isDownloaded, offlinePath
        FROM watchlist_legacy
      ''',
        [UserScope.legacyOwner],
      );
      await db.execute('DROP TABLE watchlist_legacy');
    }
  }

  static Future<void> _createMediaDownloadsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_downloads (
        downloadKey TEXT PRIMARY KEY,
        mediaId TEXT NOT NULL,
        mediaType TEXT NOT NULL,
        seriesId TEXT,
        seasonNumber INTEGER,
        episodeNumber INTEGER,
        title TEXT NOT NULL,
        thumbnail TEXT NOT NULL,
        localPath TEXT NOT NULL,
        subtitles TEXT NOT NULL DEFAULT '[]',
        downloadDate TEXT NOT NULL
      )
    ''');
  }

  static Future<void> insertMediaDownload({
    required String downloadKey,
    required String mediaId,
    required String mediaType,
    required String title,
    required String thumbnail,
    required String localPath,
    List<Map<String, dynamic>> subtitles = const [],
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    DateTime? downloadDate,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('media_downloads', {
      'downloadKey': downloadKey,
      'mediaId': mediaId,
      'mediaType': mediaType,
      'seriesId': seriesId,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'title': title,
      'thumbnail': thumbnail,
      'localPath': localPath,
      'subtitles': jsonEncode(subtitles),
      'downloadDate': (downloadDate ?? DateTime.now()).toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getMediaDownloads({
    String? mediaType,
  }) async {
    if (kIsWeb) return const [];
    final db = await database;
    final downloads = await db.query(
      'media_downloads',
      where: mediaType == null ? null : 'mediaType = ?',
      whereArgs: mediaType == null ? null : [mediaType],
      orderBy: 'downloadDate DESC',
    );
    return downloads.map((download) {
      final result = Map<String, dynamic>.from(download);
      try {
        result['subtitles'] = jsonDecode(
          download['subtitles']?.toString() ?? '[]',
        );
      } on FormatException {
        result['subtitles'] = <dynamic>[];
      }
      return result;
    }).toList();
  }

  static Future<void> deleteMediaDownload(String downloadKey) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(
      'media_downloads',
      where: 'downloadKey = ?',
      whereArgs: [downloadKey],
    );
  }

  static Future<void> addToWatchlist(Movie movie) async {
    if (kIsWeb) return;
    await _insertWatchlist(movie);
    unawaited(CloudSyncService.pushWatchlist(movie));
  }

  /// Upserts a watchlist item into local storage without pushing it back to
  /// the cloud (used by the cloud listener to apply a remote change).
  static Future<void> importWatchlist(Movie movie) async {
    if (kIsWeb) return;
    await _insertWatchlist(movie);
  }

  static Future<void> _insertWatchlist(Movie movie) async {
    final db = await database;
    await db.insert('watchlist', {
      'ownerId': UserScope.currentOwner,
      'id': movie.id,
      'title': movie.title,
      'description': movie.description,
      'thumbnail': movie.thumbnail,
      'videoUrl': movie.videoUrl,
      'trailerUrl': movie.trailerUrl,
      'genres': jsonEncode(movie.genres),
      'releaseDate': movie.releaseDate,
      'year': movie.year,
      'rating': movie.rating,
      'mediaType': movie.mediaType,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateMovie(Movie movie) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'watchlist',
      {
        'title': movie.title,
        'description': movie.description,
        'thumbnail': movie.thumbnail,
        'videoUrl': movie.videoUrl,
        'trailerUrl': movie.trailerUrl,
        'genres': jsonEncode(movie.genres),
        'releaseDate': movie.releaseDate,
        'year': movie.year,
        'rating': movie.rating,
        'mediaType': movie.mediaType,
      },
      where: 'ownerId = ? AND id = ? AND mediaType = ?',
      whereArgs: [UserScope.currentOwner, movie.id, movie.mediaType],
    );
  }

  static Future<void> removeMovie(dynamic id, String mediaType) async {
    if (kIsWeb) return;
    await removeMovieLocal(id, mediaType);
    unawaited(CloudSyncService.deleteWatchlist(id.toString(), mediaType));
  }

  /// Removes a watchlist item from local storage only (used by the cloud
  /// listener to apply a remote deletion without pushing it back).
  static Future<void> removeMovieLocal(dynamic id, String mediaType) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(
      'watchlist',
      where: 'ownerId = ? AND id = ? AND mediaType = ?',
      whereArgs: [UserScope.currentOwner, id.toString(), mediaType],
    );
  }

  static Future<bool> isInWatchlist(dynamic id, String mediaType) async {
    if (kIsWeb) return false;
    final db = await database;
    final result = await db.query(
      'watchlist',
      where: 'ownerId = ? AND id = ? AND mediaType = ?',
      whereArgs: [UserScope.currentOwner, id.toString(), mediaType],
    );
    return result.isNotEmpty;
  }

  static Future<List<Movie>> getWatchlist({
    String? orderBy = 'releaseDate DESC',
  }) async {
    if (kIsWeb) return const [];
    final db = await database;
    final result = await db.query(
      'watchlist',
      where: 'ownerId = ?',
      whereArgs: [UserScope.currentOwner],
      orderBy: orderBy,
    );

    // Fix 1: Always convert id to String in mapping
    return result.map((json) {
      final genres = json['genres'];
      final decoded = genres is String
          ? (jsonDecode(genres) as List?) ?? const []
          : const [];
      return Movie(
        id: json['id'].toString(),
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        thumbnail: (json['thumbnail'] as String?) ?? '',
        videoUrl: (json['videoUrl'] as String?) ?? '',
        trailerUrl: (json['trailerUrl'] as String?) ?? '',
        genres: decoded.whereType<String>().toList(),
        year: json['year'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        mediaType: json['mediaType'] as String? ?? 'movie',
        backdrop: '',
        country: '',
      );
    }).toList();
  }

  static Future<List<Movie>> getDownloads() async {
    if (kIsWeb) return const [];
    final db = await database;
    final result = await db.query(
      'watchlist',
      where: 'ownerId = ? AND isDownloaded = 1',
      whereArgs: [UserScope.currentOwner],
    );

    return result.map((json) {
      final genres = json['genres'];
      try {
        final decoded = genres is String ? jsonDecode(genres) : null;
        return Movie(
          id: json['id'].toString(),
          title: (json['title'] as String?) ?? '',
          description: (json['description'] as String?) ?? '',
          thumbnail: (json['thumbnail'] as String?) ?? '',
          videoUrl: (json['offlinePath'] as String?) ?? '',
          trailerUrl: (json['trailerUrl'] as String?) ?? '',
          genres: decoded is List ? decoded.whereType<String>().toList() : [],
          year: json['year'] as String? ?? '',
          rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
          mediaType: json['mediaType'] as String? ?? 'movie',
          backdrop: '',
          country: '',
        );
      } catch (_) {
        return Movie(
          id: json['id'].toString(),
          title: (json['title'] as String?) ?? '',
          description: (json['description'] as String?) ?? '',
          thumbnail: (json['thumbnail'] as String?) ?? '',
          videoUrl: (json['offlinePath'] as String?) ?? '',
          trailerUrl: (json['trailerUrl'] as String?) ?? '',
          genres: const [],
          year: json['year'] as String? ?? '',
          rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
          mediaType: json['mediaType'] as String? ?? 'movie',
          backdrop: '',
          country: '',
        );
      }
    }).toList();
  }

  static Future<List<Movie>> searchFromLocal(String keyword) async {
    if (kIsWeb) return const [];
    final db = await database;
    final result = await db.query(
      'watchlist',
      where: 'ownerId = ? AND (title LIKE ? OR description LIKE ?)',
      whereArgs: [UserScope.currentOwner, '%$keyword%', '%$keyword%'],
    );

    return result.map((json) {
      final genres = json['genres'];
      try {
        final decoded = genres is String ? jsonDecode(genres) : null;
        return Movie(
          id: json['id'].toString(),
          title: (json['title'] as String?) ?? '',
          description: (json['description'] as String?) ?? '',
          thumbnail: (json['thumbnail'] as String?) ?? '',
          videoUrl: (json['videoUrl'] as String?) ?? '',
          trailerUrl: (json['trailerUrl'] as String?) ?? '',
          genres: decoded is List ? decoded.whereType<String>().toList() : [],
          year: json['year'] as String? ?? '',
          rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
          mediaType: json['mediaType'] as String? ?? 'movie',
          backdrop: '',
          country: '',
        );
      } catch (_) {
        return Movie(
          id: json['id'].toString(),
          title: (json['title'] as String?) ?? '',
          description: (json['description'] as String?) ?? '',
          thumbnail: (json['thumbnail'] as String?) ?? '',
          videoUrl: (json['videoUrl'] as String?) ?? '',
          trailerUrl: (json['trailerUrl'] as String?) ?? '',
          genres: const [],
          year: json['year'] as String? ?? '',
          rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
          mediaType: json['mediaType'] as String? ?? 'movie',
          backdrop: '',
          country: '',
        );
      }
    }).toList();
  }

  // Episode download methods
  static Future<void> insertEpisodeDownload({
    required int seriesId,
    required String seriesTitle,
    required int seasonNumber,
    required int episodeNumber,
    required int episodeId,
    required String episodeTitle,
    required String episodeDescription,
    required String thumbnail,
    required String offlinePath,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('downloaded_episodes', {
      'seriesId': seriesId,
      'seriesTitle': seriesTitle,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'episodeId': episodeId,
      'episodeTitle': episodeTitle,
      'episodeDescription': episodeDescription,
      'thumbnail': thumbnail,
      'offlinePath': offlinePath,
      'downloadDate': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> removeEpisodeDownload(
    int seriesId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(
      'downloaded_episodes',
      where: 'seriesId = ? AND seasonNumber = ? AND episodeNumber = ?',
      whereArgs: [seriesId, seasonNumber, episodeNumber],
    );
  }

  static Future<bool> isEpisodeDownloaded(
    int seriesId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    if (kIsWeb) return false;
    final db = await database;
    final result = await db.query(
      'downloaded_episodes',
      where: 'seriesId = ? AND seasonNumber = ? AND episodeNumber = ?',
      whereArgs: [seriesId, seasonNumber, episodeNumber],
    );
    return result.isNotEmpty;
  }

  // OnStream-style methods for backwards compatibility
  static Future<List<Movie>> getWatchlistItems() async {
    if (kIsWeb) return const [];
    return await getWatchlist();
  }

  static Future<void> addToWatchlistItem(Movie movie) async {
    if (kIsWeb) return;
    await DBHelper.addToWatchlist(movie);
  }

  static Future<void> removeFromWatchlist(dynamic id, String mediaType) async {
    if (kIsWeb) return;
    await removeMovie(id, mediaType);
  }

  static Future<bool> isMovieInWatchlist(
    String id, [
    String mediaType = 'movie',
  ]) async {
    if (kIsWeb) return false;
    return await isInWatchlist(id, mediaType);
  }

  // Provider Preferences methods

  /// Ensure the provider_preferences table exists, creating it if necessary.
  static Future<void> _ensureProviderPreferencesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS provider_preferences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        providerId INTEGER UNIQUE,
        providerName TEXT,
        isPreferred INTEGER DEFAULT 0,
        addedDate TEXT
      )
    ''');
  }

  static Future<void> initializeProviderPreferences() async {
    if (kIsWeb) return;
    final db = await database;
    await _ensureProviderPreferencesTable(db);

    final providers = [
      {'id': 8, 'name': 'Netflix'},
      {'id': 9, 'name': 'Prime Video'},
      {'id': 337, 'name': 'Disney+'},
      {'id': 15, 'name': 'Hulu'},
      {'id': 350, 'name': 'Apple TV'},
      {'id': 1899, 'name': 'HBO Max'},
      {'id': 386, 'name': 'Peacock'},
      {'id': 582, 'name': 'Paramount+'},
      {'id': 526, 'name': 'AMC+'},
    ];

    for (var provider in providers) {
      final existing = await db.query(
        'provider_preferences',
        where: 'providerId = ?',
        whereArgs: [provider['id']],
      );

      if (existing.isEmpty) {
        await db.insert('provider_preferences', {
          'providerId': provider['id'],
          'providerName': provider['name'],
          'isPreferred': 0,
          'addedDate': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  static Future<void> setProviderPreference(
    int providerId,
    bool isPreferred,
  ) async {
    if (kIsWeb) return;
    final db = await database;
    await _ensureProviderPreferencesTable(db);

    final count = await db.update(
      'provider_preferences',
      {'isPreferred': isPreferred ? 1 : 0},
      where: 'providerId = ?',
      whereArgs: [providerId],
    );
    if (count == 0) {
      await db.insert('provider_preferences', {
        'providerId': providerId,
        'isPreferred': isPreferred ? 1 : 0,
        'addedDate': DateTime.now().toIso8601String(),
      });
    }
  }

  static Future<List<Map<String, dynamic>>> getProviderPreferences() async {
    if (kIsWeb) return const [];
    final db = await database;
    await _ensureProviderPreferencesTable(db);
    return await db.query('provider_preferences', orderBy: 'providerName ASC');
  }

  static Future<List<int>> getPreferredProviderIds() async {
    if (kIsWeb) return const [];
    final db = await database;
    await _ensureProviderPreferencesTable(db);
    final result = await db.query(
      'provider_preferences',
      where: 'isPreferred = 1',
      columns: ['providerId'],
    );
    return result.map((row) => row['providerId'] as int).toList();
  }

  static Future<bool> isProviderPreferred(int providerId) async {
    if (kIsWeb) return false;
    final db = await database;
    await _ensureProviderPreferencesTable(db);
    final result = await db.query(
      'provider_preferences',
      where: 'providerId = ? AND isPreferred = 1',
      whereArgs: [providerId],
    );
    return result.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getPreferredProviders() async {
    if (kIsWeb) return const [];
    final db = await database;
    await _ensureProviderPreferencesTable(db);
    final result = await db.query(
      'provider_preferences',
      where: 'isPreferred = 1',
      orderBy: 'providerName ASC',
    );
    return result;
  }
}
