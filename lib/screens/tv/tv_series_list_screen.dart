import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/movie.dart';
import '../../models/series.dart';
import '../../services/tmdb_api_service.dart';
import '../../utils/tv_utils.dart';
import 'tv_series_screen.dart';

class TvSeriesListScreen extends StatefulWidget {
  final Movie? seriesItem;
  final int initialSeasonIndex;

  const TvSeriesListScreen({
    super.key,
    this.seriesItem,
    this.initialSeasonIndex = 0,
  });

  @override
  State<TvSeriesListScreen> createState() => _TvSeriesListScreenState();
}

class _TvSeriesListScreenState extends State<TvSeriesListScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularSeries = [];
  List<Map<String, dynamic>> topRatedSeries = [];
  
  // For series-specific details view
  List<Season> seasons = [];
  int selectedSeasonIndex = 0;
  List<Episode> currentEpisodes = [];
  bool isLoadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    if (widget.seriesItem != null) {
      _loadSeriesDetails();
    } else {
      _loadContent();
    }
  }

  Future<void> _loadSeriesDetails() async {
    setState(() => isLoading = true);

    try {
      final details = await TmdbApiService.getSeriesDetails(
        int.parse(widget.seriesItem!.id),
      );
      if (details != null && mounted) {
        setState(() {
          seasons = (details['seasons'] as List)
              .map((season) => Season.fromJson(season))
              .where((season) => season.seasonNumber > 0)
              .toList();
          selectedSeasonIndex = widget.initialSeasonIndex;
        });

        if (seasons.isNotEmpty) {
          _loadSeasonEpisodes(
            seasons[selectedSeasonIndex].seasonNumber,
          );
        }
      }
    } catch (e) {
      print('Error loading series details: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSeasonEpisodes(int seasonNumber) async {
    setState(() {
      isLoadingEpisodes = true;
    });

    try {
      final episodesData = await TmdbApiService.getSeasonEpisodes(
        int.parse(widget.seriesItem!.id),
        seasonNumber,
      );

      final episodes = episodesData.map((ep) => Episode.fromJson(ep)).toList();

      if (mounted) {
        setState(() {
          currentEpisodes = episodes;
          isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      print('Error loading episodes: $e');
      if (mounted) {
        setState(() {
          isLoadingEpisodes = false;
        });
      }
    }
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
      print('Error loading series content: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If seriesItem is provided, show series details with seasons
    if (widget.seriesItem != null) {
      return _buildSeriesDetailsView();
    }
    
    // Otherwise, show the browse view
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        onRefresh: _loadContent,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (isLoading)
              SliverToBoxAdapter(child: _buildLoadingIndicator())
            else ...[
              if (trendingSeries.isNotEmpty) _buildHeroBannerSection(),
              _buildSection('Trending TV Shows', trendingSeries),
              _buildSection('Popular TV Shows', popularSeries),
              _buildSection('Top Rated TV Shows', topRatedSeries),
              SliverToBoxAdapter(
                child: SizedBox(height: TvUtils.responsivePadding(48, context)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesDetailsView() {
    final padding = TvUtils.responsivePadding(24, context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          widget.seriesItem!.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: TvUtils.responsiveFontSize(24, context),
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.red),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seasons',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: TvUtils.responsiveFontSize(22,
                                context, maxSize: 28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(
                            seasons.length,
                            (index) {
                              final season = seasons[index];
                              final isSelected = index == selectedSeasonIndex;
                              return FilterChip(
                                label: Text(
                                  season.name,
                                  style: TextStyle(
                                    fontSize: TvUtils.responsiveFontSize(16,
                                        context),
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      selectedSeasonIndex = index;
                                    });
                                    _loadSeasonEpisodes(season.seasonNumber);
                                  }
                                },
                                selectedColor: Colors.red,
                                backgroundColor: const Color(0xFF2A2A2A),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey,
                                  fontSize: TvUtils.responsiveFontSize(16,
                                      context),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isLoadingEpisodes)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: const CircularProgressIndicator(color: Colors.red),
                    ),
                  )
                else if (currentEpisodes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Episodes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: TvUtils.responsiveFontSize(22,
                                  context, maxSize: 28),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...currentEpisodes.map((episode) {
                            return _buildEpisodeCard(episode);
                          }),
                        ],
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: const Text(
                        'No episodes available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEpisodeCard(Episode episode) {
    final padding = TvUtils.responsivePadding(16, context);

    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                color: const Color(0xFF2A2A2A),
              ),
              child: episode.stillPath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      child: Image.network(
                        'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white54,
                      size: 60,
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${episode.episodeNumber}. ',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: TvUtils.responsiveFontSize(18, context),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            episode.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: TvUtils.responsiveFontSize(18, context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (episode.overview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        episode.overview,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: TvUtils.responsiveFontSize(14, context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.play_arrow,
                color: Colors.red,
                size: TvUtils.responsiveFontSize(32, context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final fontSize = TvUtils.responsiveFontSize(28, context, maxSize: 36);

    return SliverAppBar(
      floating: true,
      backgroundColor: const Color(0xFF1A1A1A),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(TvUtils.responsivePadding(8, context)),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.tv,
              color: Colors.white,
              size: TvUtils.responsiveFontSize(24, context),
            ),
          ),
          SizedBox(width: TvUtils.responsivePadding(12, context)),
          Text(
            'TV Series',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: ListView(
        padding: EdgeInsets.all(TvUtils.responsivePadding(32, context)),
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(32, context)),
          ...List.generate(
            3,
            (index) => Column(
              children: [
                Container(
                  height: 24,
                  width: 200,
                  color: Colors.grey[800],
                  margin: EdgeInsets.only(
                    bottom: TvUtils.responsivePadding(16, context),
                  ),
                ),
                Container(
                  height: 250,
                  color: Colors.grey[800],
                  margin: EdgeInsets.only(
                    bottom: TvUtils.responsivePadding(32, context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBannerSection() {
    if (trendingSeries.isEmpty) return const SizedBox.shrink();

    final heroItem = trendingSeries[0];
    final backdropUrl = TmdbApiService.getBackdropUrl(
      heroItem['backdrop_path'] ?? '',
    );

    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TvSeriesScreen(
                seriesItem: Movie.fromJson(heroItem),
              ),
            ),
          );
        },
        child: Container(
          height: 400,
          margin: EdgeInsets.all(TvUtils.responsivePadding(32, context)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: NetworkImage(backdropUrl),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: TvUtils.responsivePadding(24, context),
                left: TvUtils.responsivePadding(24, context),
                right: TvUtils.responsivePadding(24, context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heroItem['name'] ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize:
                            TvUtils.responsiveFontSize(28, context, maxSize: 36),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: TvUtils.responsivePadding(12, context)),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            'Watch',
                            style: TextStyle(
                              fontSize: TvUtils.responsiveFontSize(16, context),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(
                              horizontal: TvUtils.responsivePadding(24, context),
                              vertical: TvUtils.responsivePadding(12, context),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TvSeriesScreen(
                                  seriesItem: Movie.fromJson(heroItem),
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
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return SliverToBoxAdapter(child: const SizedBox.shrink());

    final padding = TvUtils.responsivePadding(32, context);
    final fontSize = TvUtils.responsiveFontSize(24, context, maxSize: 32);

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(bottom: TvUtils.responsivePadding(48, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: TvUtils.responsivePadding(24, context)),
            SizedBox(
              height: 320,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: padding),
                itemCount: items.take(10).length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildSeriesCard(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Map<String, dynamic> item) {
    final posterUrl = TmdbApiService.getPosterUrl(
      item['poster_path'] ?? '',
    );
    final title = item['name'] ?? 'Unknown';

    return GestureDetector(
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
      child: Container(
        width: 180,
        margin: EdgeInsets.only(
          right: TvUtils.responsivePadding(20, context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Image.network(
                      posterUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.tv,
                          color: Colors.grey,
                          size: 60,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white.withOpacity(0.8),
                        size: 60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: TvUtils.responsivePadding(12, context)),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: TvUtils.responsiveFontSize(14, context),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item['vote_average'] != null)
              Padding(
                padding: EdgeInsets.only(
                  top: TvUtils.responsivePadding(4, context),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${item['vote_average'].toStringAsFixed(1)}/10',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: TvUtils.responsiveFontSize(12, context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
