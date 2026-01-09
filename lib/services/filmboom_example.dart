import 'package:flutter/foundation.dart';
import 'filmboom_service.dart';

/// Example usage of FilmBoomService
Future<void> filmBoomExample() async {
  debugPrint('=== FilmBoom Service Example ===');

  try {
    // Search and get video URL in one call
    final result = await FilmBoomService.getVideoUrl('Stranger Things');

    if (result != null) {
      debugPrint('✓ Found content');
      debugPrint('  Title: ${result['title']}');
      debugPrint('  Video URL: ${result['videoUrl']}');
      debugPrint('  Quality: ${result['quality']}');
      debugPrint('  Duration: ${result['duration']}s');
      debugPrint('  Type: ${result['type']}');
      debugPrint('  Source: ${result['source']}');
      debugPrint('  Playable: ${result['isPlayable']}');
    } else {
      debugPrint('✗ Failed to get video');
    }
  } catch (e) {
    debugPrint('✗ Error: $e');
  }
}

/// Get video for specific season/episode
Future<void> filmBoomSeriesExample() async {
  debugPrint('=== FilmBoom Series Example ===');

  try {
    final result = await FilmBoomService.getVideoUrl(
      'Stranger Things',
      season: 5,
      episode: 1,
    );

    if (result != null) {
      debugPrint('✓ Found episode');
      debugPrint('  Title: ${result['title']}');
      debugPrint('  Video URL: ${result['videoUrl']}');
      debugPrint('  Quality: ${result['quality']}');
    } else {
      debugPrint('✗ Episode not found');
    }
  } catch (e) {
    debugPrint('✗ Error: $e');
  }
}

/// Test the service
Future<void> testFilmBoomService() async {
  await filmBoomExample();
  debugPrint('');
  await filmBoomSeriesExample();
}
