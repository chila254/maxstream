import 'package:flutter_test/flutter_test.dart';
import 'package:maxstream/services/filmboom_service.dart';

void main() {
  group('FilmBoomService', () {
    test('Get video URL directly with known IDs', () async {
      // From the network inspection: Stranger Things S5E1
      // detailPath: stranger-things-wsymkZvcaU5
      // subjectId: 4956801153355891744
      final result = await FilmBoomService.getVideoUrlDirect(
        'stranger-things-wsymkZvcaU5',
        '4956801153355891744',
        season: 5,
        episode: 1,
      );

      expect(result, isNotNull);
      expect(result!['videoUrl'], isNotNull);
      expect(result['quality'], isNotNull);
      expect(result['source'], equals('FilmBoom'));
      expect(result['isPlayable'], true);

      print('✓ Video found');
      print('✓ URL: ${result['videoUrl']}');
      print('✓ Quality: ${result['quality']}');
      print('✓ Duration: ${result['duration']}s');
    });

    test('Get different quality streams', () async {
      final result = await FilmBoomService.getVideoUrlDirect(
        'stranger-things-wsymkZvcaU5',
        '4956801153355891744',
      );

      expect(result, isNotNull);
      expect(result!['quality'], isNotNull);

      // Should prefer highest resolution
      final quality = result['quality'];
      expect(['480p', '720p', '1080p'], contains(quality));

      print('✓ Quality: $quality');
    });

    test('Search returns null (FilmBoom uses JavaScript)', () async {
      // Search endpoint requires JavaScript rendering
      final result = await FilmBoomService.getVideoUrl('Stranger Things');
      expect(result, isNull);
    });
  });
}
