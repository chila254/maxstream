import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/movie.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/logger_service.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/index.dart';
import '../widgets/tv_content_card.dart';
import 'tv_series_screen.dart';
import 'tv_video_player_screen.dart';

class TvSeriesListScreen extends StatefulWidget {
  final Movie? seriesItem;
  final int initialSeasonIndex;
  final VoidCallback? onReturnToSidebar;

  const TvSeriesListScreen({
    super.key,
    this.seriesItem,
    this.initialSeasonIndex = 0,
    this.onReturnToSidebar,
  });

  @override
  State<TvSeriesListScreen> createState() => _TvSeriesListScreenState();
}

class _TvSeriesListScreenState extends State<TvSeriesListScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularSeries = [];
  List<Map<String, dynamic>> topRatedSeries = [];

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navProvider = context.read<TvNavigationProvider>();
      navProvider.registerScrollController(3, _scrollController);
      final savedOffset = navProvider.getScrollOffset(3);
      if (savedOffset > 0 && _scrollController.hasClients) {
        _scrollController.jumpTo(savedOffset);
      }
      _scrollController.addListener(() {
        navProvider.saveScrollOffset(3, _scrollController.offset);
      });
    });

    _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        TmdbApiService.fetchTrendingSeries(),
        TmdbApiService.fetchPopularSeries(),
        TmdbApiService.fetchTopRatedSeries(),
      ]);

      setState(() {
        trendingSeries = results[0];
        popularSeries = results[1];
        topRatedSeries = results[2];
      });
    } catch (e) {
      LoggerService.error('Error loading series content: $e', e);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: RefreshIndicator(
        onRefresh: _loadContent,
        child: Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
              TvFocusManager.focusSidebar();
              context.read<TvNavigationProvider>().setFocusOnSidebar(true);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          autofocus: true,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Featured section - first trending series as big card
              if (!isLoading && trendingSeries.isNotEmpty)
                SliverToBoxAdapter(child: _buildFeaturedSection()),
              if (isLoading)
                SliverToBoxAdapter(child: _buildLoadingShimmer())
              else ...[
                if (trendingSeries.isNotEmpty)
                  _buildContentRow(
                    'Trending TV Shows',
                    trendingSeries.take(15).toList(),
                  ),
                if (popularSeries.isNotEmpty)
                  _buildContentRow(
                    'Popular TV Shows',
                    popularSeries.take(15).toList(),
                  ),
                if (topRatedSeries.isNotEmpty)
                  _buildContentRow(
                    'Top Rated TV Shows',
                    topRatedSeries.take(15).toList(),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSection() {
    final series = trendingSeries.first;
    final backdropUrl = TmdbApiService.getBackdropUrl(
      series['backdrop_path'] ?? '',
    );
    final title = series['name'] ?? 'Unknown';
    final rating = (series['vote_average'] as num?)?.toDouble() ?? 0.0;
    final overview = series['overview'] ?? '';
    final year =
        (series['first_air_date'] as String?)?.isNotEmpty == true &&
            (series['first_air_date'] as String).length >= 4
        ? (series['first_air_date'] as String).substring(0, 4)
        : null;
    final seasons = series['number_of_seasons'] as int?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TvSeriesScreen(seriesItem: Movie.fromJson(series)),
            ),
          );
        },
        child: Focus(
          onKey: (node, event) {
            if (event.isKeyPressed(LogicalKeyboardKey.select)) {
              _playSeries(series);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1A1A1A),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  backdropUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.tv, color: Colors.grey, size: 60),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                      stops: [0.0, 0.5],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (rating > 0) ...[
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (year != null)
                            Text(
                              year,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          if (seasons != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              '$seasons Seasons',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        overview,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ActionChip(
                            icon: Icons.play_arrow,
                            label: 'Play S1E1',
                            primary: true,
                            onTap: () => _playSeries(series),
                          ),
                          const SizedBox(width: 8),
                          _ActionChip(
                            icon: Icons.info_outline,
                            label: 'Details',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TvSeriesScreen(
                                    seriesItem: Movie.fromJson(series),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentRow(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final rowId = 'series:$title';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final posterUrl = TmdbApiService.getPosterUrl(
                    item['poster_path'] ?? '',
                  );
                  final itemTitle = item['name'] ?? 'Unknown';
                  final rating = (item['vote_average'] as num?)?.toDouble();
                  final year =
                      (item['first_air_date'] as String?)?.isNotEmpty == true &&
                          (item['first_air_date'] as String).length >= 4
                      ? int.tryParse(
                          (item['first_air_date'] as String).substring(0, 4),
                        )
                      : null;
                  final numberOfSeasons = item['number_of_seasons'] as int?;

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TvContentCard(
                      posterUrl: posterUrl,
                      title: itemTitle,
                      year: year,
                      rating: rating,
                      duration: numberOfSeasons != null
                          ? '$numberOfSeasons Seasons'
                          : null,
                      width: 130,
                      height: 228,
                      contentType: ContentType.series,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TvSeriesScreen(
                              seriesItem: Movie.fromJson(item),
                            ),
                          ),
                        );
                      },
                      onSelect: () => _playSeries(item),
                      autofocus:
                          index ==
                          context
                              .read<TvNavigationProvider>()
                              .getRowFocusedIndex(rowId),
                      onFocusChanged: (focused) {
                        if (!focused) return;
                        context
                            .read<TvNavigationProvider>()
                            .saveRowFocusedIndex(rowId, index);
                        Scrollable.ensureVisible(
                          context,
                          duration: const Duration(milliseconds: 180),
                          alignment: 0.5,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playSeries(Map<String, dynamic> series) {
    final seriesItem = Movie.fromJson(series);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvVideoPlayerScreen(
          title: seriesItem.title,
          tmdbId: seriesItem.id,
          isMovie: false,
          season: 1,
          episode: 1,
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return SliverToBoxAdapter(
      child: Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[600]!,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(
                3,
                (index) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 20, width: 180, color: Colors.grey[800]),
                    const SizedBox(height: 12),
                    Container(height: 240, color: Colors.grey[800]),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.primary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: primary ? Colors.red : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
