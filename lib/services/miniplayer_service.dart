import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MiniplayerService extends ChangeNotifier {
  static final MiniplayerService instance = MiniplayerService._();
  MiniplayerService._();

  VideoPlayerController? _controller;
  String _title = '';
  String _tmdbId = '';
  bool _isMovie = false;
  int _season = 1;
  int _episode = 1;
  List<int> _genreIds = const [];
  bool _minimizing = false;

  VideoPlayerController? get controller => _controller;
  String get title => _title;
  String get tmdbId => _tmdbId;
  bool get isMovie => _isMovie;
  int get season => _season;
  int get episode => _episode;
  List<int> get genreIds => _genreIds;
  bool get isActive => _controller != null;
  bool get isMinimizing => _minimizing;

  void minimize({
    required VideoPlayerController controller,
    required String title,
    required String tmdbId,
    required bool isMovie,
    required int season,
    required int episode,
    required List<int> genreIds,
  }) {
    _controller = controller;
    _title = title;
    _tmdbId = tmdbId;
    _isMovie = isMovie;
    _season = season;
    _episode = episode;
    _genreIds = genreIds;
    _minimizing = true;
    notifyListeners();
    _minimizing = false;
  }

  VideoPlayerController? restore() {
    final c = _controller;
    _controller = null;
    _title = '';
    _tmdbId = '';
    _isMovie = false;
    _season = 1;
    _episode = 1;
    _genreIds = const [];
    notifyListeners();
    return c;
  }

  void close() {
    _controller?.dispose();
    _controller = null;
    _title = '';
    _tmdbId = '';
    _isMovie = false;
    _season = 1;
    _episode = 1;
    _genreIds = const [];
    notifyListeners();
  }
}
