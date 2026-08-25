import 'package:flutter/material.dart';
import '../screens/web_video_player_screen.dart';

/// Returns the appropriate video player screen based on platform.
/// On web, uses WebVideoPlayerScreen with embed URLs and ad blocking.
Widget buildVideoPlayerScreen({
  required String title,
  required String tmdbId,
  required bool isMovie,
  int season = 1,
  int episode = 1,
  String? offlinePath,
  List<Map<String, dynamic>> offlineSubtitles = const [],
  List<Map<String, dynamic>> offlineEpisodes = const [],
  List<int> genreIds = const [],
}) {
  return WebVideoPlayerScreen(
    title: title,
    tmdbId: tmdbId,
    isMovie: isMovie,
    season: season,
    episode: episode,
  );
}
