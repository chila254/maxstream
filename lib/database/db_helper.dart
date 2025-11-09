import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/movie.dart';


class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'watchlist.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  static Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE watchlist (
        id INTEGER PRIMARY KEY,
        title TEXT,
        description TEXT,
        thumbnail TEXT,
        videoUrl TEXT,
        trailerUrl TEXT,
        genres TEXT,
        releaseDate TEXT,
        year TEXT,
        rating REAL,
        mediaType TEXT,
        isDownloaded INTEGER DEFAULT 0,
        offlinePath TEXT
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
      await db.execute('ALTER TABLE watchlist ADD COLUMN isDownloaded INTEGER DEFAULT 0');
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
  }

  static Future<void> addToWatchlist(Movie movie) async {
    final db = await database;
    await db.insert('watchlist', {
      'id': int.tryParse(movie.id) ?? movie.id,
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
      where: 'id = ?',
      whereArgs: [movie.id],
    );
  }

  static Future<void> removeMovie(int id) async {
    final db = await database;
    await db.delete('watchlist', where: 'id = ?', whereArgs: [id]);
  }

  static Future<bool> isInWatchlist(int id) async {
    final db = await database;
    final result = await db.query(
      'watchlist',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty;
  }

  static Future<List<Movie>> getWatchlist({
    String? orderBy = 'releaseDate DESC',
  }) async {
    final db = await database;
    final result = await db.query('watchlist', orderBy: orderBy);

    // Fix 1: Always convert id to String in mapping
    return result.map((json) {
      return Movie(
        id: json['id'].toString(),
        title: json['title'] as String,
        description: json['description'] as String,
        thumbnail: json['thumbnail'] as String,
        videoUrl: json['videoUrl'] as String,
        trailerUrl: json['trailerUrl'] as String,
        genres: json['genres'] is String
            ? List<String>.from(jsonDecode(json['genres'] as String))
            : [],
        year: json['year'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        mediaType: json['mediaType'] as String? ?? 'movie',
        backdrop: '',
        country: '',
      );
    }).toList();
  }

  static Future<List<Movie>> getDownloads() async {
    final db = await database;
    final result = await db.query('watchlist', where: 'isDownloaded = 1');

    return result.map((json) {
      return Movie(
        id: json['id'].toString(),
        title: json['title'] as String,
        description: json['description'] as String,
        thumbnail: json['thumbnail'] as String,
        videoUrl: json['offlinePath'] as String,
        trailerUrl: json['trailerUrl'] as String,
        genres: json['genres'] is String
            ? List<String>.from(jsonDecode(json['genres'] as String))
            : [],
        year: json['year'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        mediaType: json['mediaType'] as String? ?? 'movie',
        backdrop: '',
        country: '',
      );
    }).toList();
  }

  static Future<List<Movie>> searchFromLocal(String keyword) async {
    final db = await database;
    final result = await db.query(
      'watchlist',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
    );

    return result.map((json) {
      return Movie(
        id: json['id'].toString(),
        title: json['title'] as String,
        description: json['description'] as String,
        thumbnail: json['thumbnail'] as String,
        videoUrl: json['videoUrl'] as String,
        trailerUrl: json['trailerUrl'] as String,
        genres: json['genres'] is String
            ? List<String>.from(jsonDecode(json['genres'] as String))
            : [],
        year: json['year'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        mediaType: json['mediaType'] as String? ?? 'movie',
        backdrop: '',
        country: '',
      );
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

  static Future<void> removeEpisodeDownload(int seriesId, int seasonNumber, int episodeNumber) async {
    final db = await database;
    await db.delete(
      'downloaded_episodes',
      where: 'seriesId = ? AND seasonNumber = ? AND episodeNumber = ?',
      whereArgs: [seriesId, seasonNumber, episodeNumber],
    );
  }

  static Future<bool> isEpisodeDownloaded(int seriesId, int seasonNumber, int episodeNumber) async {
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
    return await getWatchlist();
  }

  static Future<void> addToWatchlistItem(Movie movie) async {
    await DBHelper.addToWatchlist(movie);
  }

  static Future<void> removeFromWatchlist(dynamic id) async {
    await removeMovie(id is int ? id : int.tryParse(id.toString()) ?? id);
  }

  static Future<bool> isMovieInWatchlist(String id) async {
    return await isInWatchlist(int.parse(id));
  }
}
