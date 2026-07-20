import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../screens/m3u8_video_player_screen.dart';
import '../screens/web_video_player_screen.dart';

/// Returns the appropriate video player screen based on platform.
Widget buildVideoPlayerScreen({
  required String title,
  required String tmdbId,
  required bool isMovie,
  int season = 1,
  int episode = 1,
  String? offlinePath,
}) {
  if (kIsWeb) {
    return WebVideoPlayerScreen(
      title: title,
      tmdbId: tmdbId,
      isMovie: isMovie,
      season: season,
      episode: episode,
    );
  }

  return M3U8VideoPlayerScreen(
    title: title,
    tmdbId: tmdbId,
    isMovie: isMovie,
    season: season,
    episode: episode,
    offlinePath: offlinePath,
  );
}
