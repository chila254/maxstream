import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../../models/movie.dart';
import '../../models/series.dart';
import '../../services/tmdb_api_service.dart';
import '../../utils/tv_utils.dart';
import '../../utils/tv_dpad_navigation_mixin.dart';
import '../../widgets/custom_loading_widget.dart';
import '../../widgets/tv_focus_widget.dart';
import 'tv_series_screen.dart';

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

class _TvSeriesListScreenState extends State<TvSeriesListScreen>
    with TvDpadNavigationMixin {
  bool isLoading = true;
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularSeries = [];
  List<Map<String, dynamic>> topRatedSeries = [];

  // For series-specific details view
  List<Season> seasons = [];
  int selectedSeasonIndex = 0;
  List<Episode> currentEpisodes = [];
  bool isLoadingEpisodes = false;

  // Auto-scroll banner
  late PageController _heroBannerController;
  Timer? _heroBannerTimer;
  int _heroBannerPage = 0;

  // Focus tracking
  String? _focusedSection;
  final Map<String, int> _sectionItemIndices = {
    'trending_series': 0,
    'popular_series': 0,
    'top_rated_series': 0,
  };

  @override
  void initState() {
    super.initState();
    _heroBannerController = PageController();
    if (widget.seriesItem != null) {
      _loadSeriesDetails();
    } else {
      _loadContent();
    }
  }

  @override
  void dispose() {
    _heroBannerController.dispose();
    _heroBannerTimer?.cancel();
    super.dispose();
  }

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex => 2; // Trending Series, Popular Series, Top Rated Series

  @override
  void onFocusChanged(int index) {
    setState(() {
      _focusedSection = [
        'trending_series',
        'popular_series',
        'top_rated_series',
      ][index];
    });
  }

  @override
  void onSelectPressed() {
    // Selection handled by content cards
  }

  @override
  void onLeftPressed() {
    if (_focusedSection == null) return;

    // Navigate left within content sections
    final currentIndex = _sectionItemIndices[_focusedSection] ?? 0;
    if (currentIndex > 0) {
      setState(() {
        _sectionItemIndices[_focusedSection!] = currentIndex - 1;
      });
    }
  }

  @override
  void onRightPressed() {
    if (_focusedSection == null) return;

    // Navigate right within content sections
    final currentIndex = _sectionItemIndices[_focusedSection] ?? 0;
    final maxItems = _getMaxItemsForSection(_focusedSection!);
    if (currentIndex < maxItems - 1) {
      setState(() {
        _sectionItemIndices[_focusedSection!] = currentIndex + 1;
      });
    }
  }

  int _getMaxItemsForSection(String section) {
    switch (section) {
      case 'trending_series':
        return trendingSeries.take(10).length;
      case 'popular_series':
        return popularSeries.take(10).length;
      case 'top_rated_series':
        return topRatedSeries.take(10).length;
      default:
        return 0;
    }
  }

  void _startHeroBannerTimer() {
    _heroBannerTimer?.cancel();
    _heroBannerTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (trendingSeries.isNotEmpty) {
        _heroBannerPage = (_heroBannerPage + 1) % trendingSeries.length;
        if (_heroBannerController.hasClients) {
          _heroBannerController.animateToPage(
            _heroBannerPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      }
    });
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
          _loadSeasonEpisodes(seasons[selectedSeasonIndex].seasonNumber);
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

      // Start auto-scrolling hero banner
      if (trendingSeries.isNotEmpty) {
        _startHeroBannerTimer();
      }
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
    return RawKeyboardListener(
      onKey: handleKeyEvent,
      focusNode: focusNode,
      child: Scaffold(
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
                  child: SizedBox(
                    height: TvUtils.responsivePadding(48, context),
                  ),
                ),
              ],
            ],
          ),
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
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
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
                            fontSize: TvUtils.responsiveFontSize(
                              22,
                              context,
                              maxSize: 28,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(seasons.length, (index) {
                            final season = seasons[index];
                            final isSelected = index == selectedSeasonIndex;
                            return FilterChip(
                              label: Text(
                                season.name,
                                style: TextStyle(
                                  fontSize: TvUtils.responsiveFontSize(
                                    16,
                                    context,
                                  ),
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
                                fontSize: TvUtils.responsiveFontSize(
                                  16,
                                  context,
                                ),
                              ),
                            );
                          }),
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
                              fontSize: TvUtils.responsiveFontSize(
                                22,
                                context,
                                maxSize: 28,
                              ),
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
    if (trendingSeries.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        children: [
          SizedBox(
            height: 550,
            child: PageView.builder(
              controller: _heroBannerController,
              onPageChanged: (page) {
                setState(() => _heroBannerPage = page);
              },
              itemCount: trendingSeries.length,
              itemBuilder: (context, index) {
                return _buildBannerItem(trendingSeries[index]);
              },
            ),
          ),
          // Page indicators
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: TvUtils.responsivePadding(16, context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                trendingSeries.length,
                (index) => Container(
                  width: _heroBannerPage == index ? 24 : 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(
                    horizontal: TvUtils.responsivePadding(4, context),
                  ),
                  decoration: BoxDecoration(
                    color: _heroBannerPage == index
                        ? const Color(0xFFE50914)
                        : Colors.grey[600],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerItem(Map<String, dynamic> heroItem) {
    final backdropUrl = TmdbApiService.getBackdropUrl(
      heroItem['backdrop_path'] ?? '',
    );
    final rating = heroItem['vote_average']?.toStringAsFixed(1) ?? 'N/A';
    final year = _extractYear(heroItem);
    final genres = _extractGenres(heroItem);
    final overview = heroItem['overview'] ?? 'No description available';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TvSeriesScreen(seriesItem: Movie.fromJson(heroItem)),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: TvUtils.responsivePadding(24, context),
          vertical: TvUtils.responsivePadding(16, context),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
                  colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                ),
              ),
            ),
            Positioned(
              bottom: TvUtils.responsivePadding(20, context),
              left: TvUtils.responsivePadding(20, context),
              right: TvUtils.responsivePadding(20, context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    heroItem['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: TvUtils.responsiveFontSize(
                        28,
                        context,
                        maxSize: 36,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: TvUtils.responsivePadding(12, context)),
                  // Meta Info (Rating, Year, Genres)
                  Row(
                    children: [
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$rating/10',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: TvUtils.responsiveFontSize(12, context),
                          ),
                        ),
                      ),
                      SizedBox(width: TvUtils.responsivePadding(12, context)),
                      // Year
                      Text(
                        year,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: TvUtils.responsiveFontSize(12, context),
                        ),
                      ),
                      SizedBox(width: TvUtils.responsivePadding(12, context)),
                      // Genres
                      Expanded(
                        child: Text(
                          genres,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: TvUtils.responsiveFontSize(12, context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: TvUtils.responsivePadding(12, context)),
                  // Overview
                  Text(
                    overview,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: TvUtils.responsiveFontSize(14, context),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: TvUtils.responsivePadding(16, context)),
                  // Buttons
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
                      SizedBox(width: TvUtils.responsivePadding(12, context)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.info_outline),
                        label: Text(
                          'Details',
                          style: TextStyle(
                            fontSize: TvUtils.responsiveFontSize(16, context),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
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
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty)
      return SliverToBoxAdapter(child: const SizedBox.shrink());

    final padding = TvUtils.responsivePadding(32, context);
    final fontSize = TvUtils.responsiveFontSize(24, context, maxSize: 32);

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: TvUtils.responsivePadding(48, context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showFullList(title),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: TvUtils.responsivePadding(20, context),
                        vertical: TvUtils.responsivePadding(8, context),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'See More',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TvUtils.responsiveFontSize(14, context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
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
                  final sectionKey = title.contains('Trending')
                      ? 'trending_series'
                      : title.contains('Popular')
                      ? 'popular_series'
                      : 'top_rated_series';
                  final isFocused = _sectionItemIndices[sectionKey] == index;
                  return _buildSeriesCard(item, isFocused: isFocused);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullList(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TvSeriesFullListScreen(
          title: title,
          onReturnToSidebar: widget.onReturnToSidebar,
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Map<String, dynamic> item, {bool isFocused = false}) {
    final posterUrl = TmdbApiService.getPosterUrl(item['poster_path'] ?? '');
    final title = item['name'] ?? 'Unknown';

    return TvContentFocusCard(
      isFocused: isFocused,
      scale: 1.12,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TvSeriesScreen(seriesItem: Movie.fromJson(item)),
          ),
        );
      },
      child: Container(
        width: 180,
        margin: EdgeInsets.only(right: TvUtils.responsivePadding(20, context)),
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
                      errorBuilder: (context, error, stackTrace) => Container(
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

  String _extractYear(Map<String, dynamic> item) {
    final releaseDate = item['release_date'] ?? item['first_air_date'] ?? '';
    if (releaseDate.isNotEmpty && releaseDate.length >= 4) {
      return releaseDate.substring(0, 4);
    }
    return 'N/A';
  }

  String _extractGenres(Map<String, dynamic> item) {
    List<String> genreList = [];

    if (item['genre_ids'] is List) {
      final ids = item['genre_ids'] as List;
      genreList = ids.map((id) => _genreMap[id] ?? '').toList();
    } else if (item['genres'] is List) {
      genreList = item['genres']
          .map<String>(
            (genre) => (genre is Map && genre.containsKey('name'))
                ? genre['name']
                : genre.toString(),
          )
          .toList();
    }

    return genreList.take(2).join(', ');
  }

  // Genre mapping
  final _genreMap = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
  };
}

class _TvSeriesFullListScreen extends StatefulWidget {
  final String title;
  final VoidCallback? onReturnToSidebar;

  const _TvSeriesFullListScreen({required this.title, this.onReturnToSidebar});

  @override
  State<_TvSeriesFullListScreen> createState() =>
      _TvSeriesFullListScreenState();
}

class _TvSeriesFullListScreenState extends State<_TvSeriesFullListScreen>
    with TvDpadNavigationMixin {
  List<Map<String, dynamic>> _allItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  late ScrollController _scrollController;
  static const int _columnsPerRow = 3;

  @override
  int get maxFocusIndex => _allItems.isNotEmpty ? _allItems.length - 1 : 0;

  @override
  void onFocusChanged(int index) {
    // Handle focus change if needed
  }

  @override
  void onSelectPressed() {
    // Handle select if needed
  }

  @override
  void onLeftPressed() {
    final currentFocus = getFocusIndex();
    if (currentFocus > 0 && currentFocus % _columnsPerRow != 0) {
      // Navigate left within grid
      setFocusIndex(currentFocus - 1);
    } else if (currentFocus % _columnsPerRow == 0 &&
        widget.onReturnToSidebar != null) {
      // At leftmost column: return to sidebar
      widget.onReturnToSidebar!();
    }
  }

  @override
  void onRightPressed() {
    final currentFocus = getFocusIndex();
    if (currentFocus + 1 < _allItems.length &&
        (currentFocus + 1) % _columnsPerRow != 0) {
      setFocusIndex(currentFocus + 1);
    }
  }

  @override
  void handleKeyEvent(RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      _moveDown();
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      _moveUp();
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      onLeftPressed();
    } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      onRightPressed();
    } else if (event.isKeyPressed(LogicalKeyboardKey.select) ||
        event.isKeyPressed(LogicalKeyboardKey.enter)) {
      onSelectPressed();
    }
  }

  void _moveDown() {
    final currentFocus = getFocusIndex();
    int newIndex = currentFocus + _columnsPerRow;
    if (newIndex < _allItems.length) {
      setFocusIndex(newIndex);
    }
  }

  void _moveUp() {
    final currentFocus = getFocusIndex();
    int newIndex = currentFocus - _columnsPerRow;
    if (newIndex >= 0) {
      setFocusIndex(newIndex);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _loadInitialItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialItems() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> items = [];

      if (widget.title.contains('Trending')) {
        items = await TmdbApiService.fetchTrendingSeries(page: 1);
      } else if (widget.title.contains('Popular')) {
        items = await TmdbApiService.fetchPopularSeries(page: 1);
      } else if (widget.title.contains('Top Rated')) {
        items = await TmdbApiService.fetchTopRatedSeries(page: 1);
      }

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading items: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        !_isLoading) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || _isLoading) return;

    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      List<Map<String, dynamic>> newItems = [];

      if (widget.title.contains('Trending')) {
        newItems = await TmdbApiService.fetchTrendingSeries(page: _currentPage);
      } else if (widget.title.contains('Popular')) {
        newItems = await TmdbApiService.fetchPopularSeries(page: _currentPage);
      } else if (widget.title.contains('Top Rated')) {
        newItems = await TmdbApiService.fetchTopRatedSeries(page: _currentPage);
      }

      if (newItems.isNotEmpty) {
        setState(() {
          _allItems.addAll(newItems);
        });
      }
    } catch (e) {
      print('Error loading more items: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      onKey: handleKeyEvent,
      focusNode: focusNode,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: TvUtils.responsiveFontSize(28, context, maxSize: 40),
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              size: TvUtils.responsiveFontSize(24, context, maxSize: 36),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CustomLoadingWidget(
                      size: 60,
                      color: Color(0xFFE50914),
                      style: LoadingStyle.dots,
                    ),
                    SizedBox(height: TvUtils.responsivePadding(24, context)),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: TvUtils.responsiveFontSize(16, context),
                      ),
                    ),
                  ],
                ),
              )
            : _allItems.isEmpty
            ? Center(
                child: Text(
                  'No content available',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: TvUtils.responsiveFontSize(16, context),
                  ),
                ),
              )
            : GridView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.6,
                  crossAxisSpacing: TvUtils.responsivePadding(16, context),
                  mainAxisSpacing: TvUtils.responsivePadding(16, context),
                ),
                itemCount: _allItems.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _allItems.length) {
                    return Center(
                      child: const CustomLoadingWidget(
                        size: 40,
                        color: Color(0xFFE50914),
                        style: LoadingStyle.dots,
                      ),
                    );
                  }

                  final item = _allItems[index];
                  return _buildFullListItem(item);
                },
              ),
      ),
    );
  }

  Widget _buildFullListItem(Map<String, dynamic> item) {
    final posterUrl = TmdbApiService.getPosterUrl(item['poster_path'] ?? '');
    final title = item['name'] ?? 'Unknown';
    final year = item['first_air_date']?.toString().split('-')[0] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TvSeriesScreen(seriesItem: Movie.fromJson(item)),
          ),
        );
      },
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
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.tv, color: Colors.grey, size: 40),
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
                      size: 50,
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
          if (year.isNotEmpty)
            Text(
              year,
              style: TextStyle(
                color: Colors.grey,
                fontSize: TvUtils.responsiveFontSize(12, context),
              ),
            ),
        ],
      ),
    );
  }
}
