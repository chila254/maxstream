import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../models/movie.dart';
import '../services/recommendation_service.dart';
import '../services/tmdb_api_service.dart';
import 'maxstream_details_screen.dart';
import 'maxstream_series_screen.dart';

class MaxStreamRecommendationsScreen extends StatefulWidget {
  const MaxStreamRecommendationsScreen({super.key});

  @override
  State<MaxStreamRecommendationsScreen> createState() =>
      _MaxStreamRecommendationsScreenState();
}

class _MaxStreamRecommendationsScreenState
    extends State<MaxStreamRecommendationsScreen> {
  List<Map<String, dynamic>> _forYou = [];
  List<Map<String, dynamic>> _becauseYouWatched = [];
  Map<String, List<Map<String, dynamic>>> _byGenre = {};
  bool _loading = true;
  bool _hasHistory = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _loading = true);
    try {
      final topGenres = await RecommendationService.getTopGenres(limit: 4);
      _hasHistory = topGenres.isNotEmpty;

      final results = await Future.wait([
        RecommendationService.getForYou(),
        RecommendationService.getBecauseYouWatched(),
        if (_hasHistory)
          ...topGenres.map((g) => RecommendationService.getByGenre(g)),
      ]);

      _forYou = results[0];
      _becauseYouWatched = results[1];

      if (_hasHistory) {
        final genreNames = await TmdbApiService.fetchGenres('movie');
        final genreNamesTv = await TmdbApiService.fetchGenres('tv');
        final allGenres = {...genreNames, ...genreNamesTv};

        _byGenre = {};
        for (int i = 0; i < topGenres.length; i++) {
          final name = allGenres[topGenres[i]] ?? 'Genre ${topGenres[i]}';
          _byGenre[name] = results[2 + i];
        }
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _navigateToItem(Map<String, dynamic> item, String mediaType) {
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            mediaType == 'tv'
                ? MaxStreamSeriesScreen(seriesItem: Movie.fromJson(item))
                : MaxStreamDetailsScreen(
                    item: Movie.fromJson(item),
                    mediaType: mediaType,
                  ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: _loading
          ? _buildLoadingShimmer()
          : RefreshIndicator(
              onRefresh: () async {
                RecommendationService.clearCache();
                await _loadRecommendations();
              },
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  if (!_hasHistory) ...[
                    const SliverToBoxAdapter(child: _EmptyState()),
                  ] else ...[
                    if (_becauseYouWatched.isNotEmpty)
                      _buildSection(
                        'Because You Watched ${_becauseYouWatched.first['recommendedFrom'] ?? ''}',
                        _becauseYouWatched,
                      ),
                    if (_forYou.isNotEmpty)
                      _buildSection('For You', _forYou),
                    for (final entry in _byGenre.entries)
                      if (entry.value.isNotEmpty)
                        _buildSection('More ${entry.key}', entry.value),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 60,
      backgroundColor: const Color(0xFF0A0A0A),
      title: const Text(
        'Recommendations',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () async {
            RecommendationService.clearCache();
            await _loadRecommendations();
          },
        ),
      ],
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final mediaType = item['mediaType'] ??
                    (item.containsKey('first_air_date') ? 'tv' : 'movie');
                return _buildCard(item, mediaType);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, String mediaType) {
    final name = item['title'] ?? item['name'] ?? 'Unknown';
    final posterPath = item['poster_path'];
    final rating = item['vote_average'];

    return GestureDetector(
      onTap: () => _navigateToItem(item, mediaType),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  posterPath != null
                      ? Image.network(
                          TmdbApiService.getPosterUrl(posterPath),
                          width: 120,
                          height: 160,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 120,
                          height: 160,
                          color: Colors.grey[800],
                          child: const Icon(Icons.movie, color: Colors.grey),
                        ),
                  if (rating != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      child: ListView(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 200,
                  height: 24,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    itemBuilder: (ctx, idx) => Container(
                      width: 120,
                      height: 200,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore,
              size: 80,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No recommendations yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Watch some movies and series to get\npersonalized recommendations',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
