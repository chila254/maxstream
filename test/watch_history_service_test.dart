import 'package:flutter_test/flutter_test.dart';
import 'package:maxstream/services/user_scope.dart';
import 'package:maxstream/services/watch_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserScope.ownerResolver = () => 'user-a';
  });

  tearDown(() => UserScope.ownerResolver = null);

  test('history and item keys are scoped by owner', () async {
    await WatchHistoryService.saveWatchProgress(
      tmdbId: '42',
      title: 'Movie',
      isMovie: true,
      season: 0,
      episode: 0,
      position: const Duration(seconds: 60),
      duration: const Duration(seconds: 120),
    );
    expect(await WatchHistoryService.getWatchHistory(), hasLength(1));

    UserScope.ownerResolver = () => 'user-b';
    expect(await WatchHistoryService.getWatchHistory(), isEmpty);
    expect(
      await WatchHistoryService.loadWatchPosition('42', true, 0, 0),
      Duration.zero,
    );

    UserScope.ownerResolver = () => 'user-a';
    expect(
      await WatchHistoryService.loadWatchPosition('42', true, 0, 0),
      const Duration(seconds: 60),
    );
  });

  test('malformed JSON and wrong shapes return safe defaults', () async {
    SharedPreferences.setMockInitialValues({
      'watch_history_list_user-a': '{broken',
      'watch_history_user-a_movie_42': '[]',
    });

    expect(await WatchHistoryService.getWatchHistory(), isEmpty);
    expect(
      await WatchHistoryService.loadWatchPosition('42', true, 0, 0),
      Duration.zero,
    );
    expect(
      await WatchHistoryService.getWatchProgressPercentage('42', true, 0, 0),
      0,
    );
    expect(await WatchHistoryService.isWatched('42', true, 0, 0), isFalse);
  });

  test('empty injected owner uses stable anonymous owner', () {
    UserScope.ownerResolver = () => '  ';
    expect(UserScope.currentOwner, UserScope.anonymousOwner);
    expect(
      WatchHistoryService.getWatchHistoryKey('7', false, 1, 2),
      'watch_history___anonymous___tv_7_1_2',
    );
  });
}
