import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/app_shimmer.dart';

import '../models/movie.dart';
import '../services/cloud_sync_service.dart';
import '../services/recommendation_service.dart';
import '../services/tmdb_api_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/profile_menu_button.dart';
import 'maxstream_details_screen.dart';
import 'maxstream_series_screen.dart';
import '../widgets/app_network_image.dart';

class MaxStreamRecommendationsScreen extends StatefulWidget {
  const MaxStreamRecommendationsScreen({super.key});

  @override
  State<MaxStreamRecommendationsScreen> createState() =>
      _MaxStreamRecommendationsScreenState();
}

class _MaxStreamRecommendationsScreenState
    extends State<MaxStreamRecommendationsScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _forYou = [];
  List<Map<String, dynamic>> _becauseYouWatched = [];
  Map<String, List<Map<String, dynamic>>> _byGenre = {};
  Map<int, String> _genreIdByName = {};
  bool _loading = true;
  bool _hasHistory = false;
  int _forYouPage = 1;
  bool _loadingMoreForYou = false;
  final Map<String, int> _genrePage = {};
  final Map<String, bool> _loadingMoreGenre = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CloudSyncService.historyRevision.addListener(_onHistoryChanged);
    WatchHistoryService.localHistoryRevision.addListener(_onHistoryChanged);
    _loadRecommendations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CloudSyncService.historyRevision.removeListener(_onHistoryChanged);
    WatchHistoryService.localHistoryRevision.removeListener(_onHistoryChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User may have watched on TV while phone was backgrounded — pull and refresh.
      _onHistoryChanged();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _onHistoryChanged() {
    if (!mounted) return;
    // New watch (movie / episode / season / series) changes topGenres and the
    // most-recent item for "Because You Watched". Bust the 30-min cache so
    // For You / By Genre rows recompute immediately instead of staying stale.
    RecommendationService.clearCache();
    // Debounce slightly – rapid episode saves (binge) can fire several times.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _loadRecommendations(showLoading: false);
    });
  }

  Future<List<Map<String, dynamic>>> _safeRec(
    Future<List<Map<String, dynamic>>> Function() f,
  ) async {
    try {
      return await f();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadRecommendations({bool showLoading = true}) async {
    // Pull TV watches in background without blocking first paint; the
    // historyRevision listener will auto-reload when new data lands.
    // Awaiting here previously added 1–2s to every load.
    unawaited(CloudSyncService.pullToDevice().catchError((_) {}));
    final bool hasCached = _forYou.isNotEmpty || _becauseYouWatched.isNotEmpty || _byGenre.isNotEmpty;
    if (showLoading) {
      if (!hasCached) {
        if (mounted) setState(() => _loading = true);
      } else {
        // Keep existing content visible while refreshing — feels instant.
        if (mounted) setState(() => _loading = false);
      }
    }
    try {
      final topGenres = await RecommendationService.getTopGenres(limit: 4)
          .catchError((_) => <int>[]);
      _hasHistory = topGenres.isNotEmpty;

      final results = await Future.wait([
        _safeRec(() => RecommendationService.getForYou()),
        _safeRec(() => RecommendationService.getBecauseYouWatched()),
        if (_hasHistory)
          ...topGenres.map((g) => _safeRec(() => RecommendationService.getByGenre(g))),
      ]);

      _forYou = results[0];
      _becauseYouWatched = results[1];

      if (_hasHistory) {
        Map<int, String> allGenres = {};
        try {
          final genreNames = await TmdbApiService.fetchGenres('movie');
          final genreNamesTv = await TmdbApiService.fetchGenres('tv');
          allGenres = {...genreNames, ...genreNamesTv};
        } catch (_) {}
        _byGenre = {};
        _genreIdByName = {};
        for (int i = 0; i < topGenres.length; i++) {
          final name = allGenres[topGenres[i]] ?? 'Genre ${topGenres[i]}';
          _byGenre[name] = (2 + i < results.length) ? results[2 + i] : [];
          _genreIdByName[topGenres[i]] = name;
          _genrePage[name] = 1;
        }
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMoreForYou() async {
    if (_loadingMoreForYou) return;
    setState(() => _loadingMoreForYou = true);
    try {
      _forYouPage++;
      final more = await RecommendationService.getForYou(page: _forYouPage);
      if (mounted) setState(() => _forYou = [..._forYou, ...more]);
    } catch (_) {}
    if (mounted) setState(() => _loadingMoreForYou = false);
  }

  Future<void> _loadMoreGenre(String genreName) async {
    if (_loadingMoreGenre[genreName] == true) return;
    setState(() => _loadingMoreGenre[genreName] = true);
    final current = _genrePage[genreName] ?? 1;
    final genreId = _genreIdByName.entries
        .where((e) => e.value == genreName)
        .map((e) => e.key)
        .firstOrNull;
    if (genreId == null) {
      if (mounted) setState(() => _loadingMoreGenre[genreName] = false);
      return;
    }
    try {
      final more =
          await RecommendationService.getByGenre(genreId, page: current + 1);
      if (mounted) {
        setState(() {
          _genrePage[genreName] = current + 1;
          _byGenre[genreName] = [...(_byGenre[genreName] ?? []), ...more];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMoreGenre[genreName] = false);
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
                        'Because You Watched',
                        _becauseYouWatched.first['recommendedFrom'] ?? '',
                        _becauseYouWatched,
                      ),
                    if (_forYou.isNotEmpty)
                      _buildSection(
                        'For You',
                        'Picked for you',
                        _forYou,
                        onLoadMore: _loadMoreForYou,
                        loadingMore: _loadingMoreForYou,
                      ),
                    for (final entry in _byGenre.entries)
                      if (entry.value.isNotEmpty)
                        _buildSection(
                          'Top in ${entry.key}',
                          entry.key,
                          entry.value,
                          onLoadMore: () => _loadMoreGenre(entry.key),
                          loadingMore:
                              _loadingMoreGenre[entry.key] == true,
                        ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: ProfileMenuButton(),
        ),
      ],
    );
  }

  Widget _buildSection(
    String label,
    String title,
    List<Map<String, dynamic>> items, {
    VoidCallback? onLoadMore,
    bool loadingMore = false,
  }) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length + (onLoadMore != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return _buildLoadMoreTile(onLoadMore!, loadingMore);
                }
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

  Widget _buildLoadMoreTile(VoidCallback onTap, bool loading) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: Colors.grey[500], size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'More',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, String mediaType) {
    final name = item['title'] ?? item['name'] ?? 'Unknown';
    final posterPath = item['poster_path'];
    final rating = (item['vote_average'] as num?)?.toDouble();
    final year = (item['release_date'] ?? item['first_air_date'] ?? '')
        .toString()
        .split('-')
        .first;
    final typeLabel = mediaType == 'tv' ? 'TV' : 'MOVIE';

    return GestureDetector(
      onTap: () => _navigateToItem(item, mediaType),
      child: Container(
        width: 135,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  posterPath != null
                      ? AppNetworkImage(
                          url: TmdbApiService.getPosterUrl(posterPath),
                          width: 135,
                          height: 200,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            width: 135,
                            height: 200,
                            color: Colors.grey[850],
                            child: const Icon(Icons.movie,
                                color: Colors.grey, size: 40),
                          ),
                        )
                      : Container(
                          width: 135,
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey[850]!,
                                Colors.grey[900]!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.movie,
                              color: Colors.grey, size: 40),
                        ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (rating != null && rating > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 10),
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
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
            if (year.isNotEmpty)
              Text(
                year,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return AppShimmer(
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
                  height: 280,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    itemBuilder: (ctx, idx) => Container(
                      width: 135,
                      height: 280,
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
