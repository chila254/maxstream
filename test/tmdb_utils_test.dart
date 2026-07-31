import 'package:flutter_test/flutter_test.dart';
import 'package:maxstream/services/tmdb_api_service.dart';
import 'package:maxstream/utils/tmdb_list_utils.dart';

void main() {
  test('TMDB URI encodes search queries and preserves parameters', () {
    final uri = TmdbApiService.buildUri('/search/multi', {
      'query': 'Dune & Spider-Man/新',
      'page': 2,
    });

    expect(uri.scheme, 'https');
    expect(uri.path, '/3/search/multi');
    expect(uri.queryParameters['query'], 'Dune & Spider-Man/新');
    expect(uri.queryParameters['page'], '2');
    expect(uri.toString(), contains('query=Dune+%26+Spider-Man%2F'));
  });

  test('TMDB list merge deduplicates by media type and id', () {
    final merged = uniqueTmdbItems(
      [
        {'id': 1, 'media_type': 'movie'},
        {'id': 1, 'media_type': 'tv'},
      ],
      [
        {'id': 1, 'media_type': 'movie'},
        {'id': 2},
      ],
      'movie',
    );

    expect(merged.map((item) => tmdbItemKey(item, 'movie')), [
      'movie:1',
      'tv:1',
      'movie:2',
    ]);
  });
}
