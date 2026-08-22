import 'package:flutter/material.dart';
import '../screens/m3u8_video_player_screen.dart';

/// Returns the appropriate video player screen based on platform.
/// On mobile/native platforms, uses M3U8VideoPlayerScreen with native extractors.
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
  return M3U8VideoPlayerScreen(
    title: title,
    tmdbId: tmdbId,
    isMovie: isMovie,
    season: season,
    episode: episode,
    offlinePath: offlinePath,
    offlineSubtitles: offlineSubtitles,
    offlineEpisodes: offlineEpisodes,
    genreIds: genreIds,
  );
}
