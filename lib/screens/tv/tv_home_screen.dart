import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../../models/movie.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';
import '../../utils/tv_utils.dart';
import '../../utils/tv_dpad_navigation_mixin.dart';
import '../../widgets/custom_loading_widget.dart';
import '../../widgets/tv_focus_widget.dart';
import 'tv_search_screen.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';
import '../provider_content_screen.dart';

class TvHomeScreen extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;

  const TvHomeScreen({super.key, this.onReturnToSidebar});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen>
    with TvDpadNavigationMixin {
  bool isLoading = true;
  List<Map<String, dynamic>> trendingMovies = [];
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularMovies = [];
  List<Map<String, dynamic>> topRatedMovies = [];
  List<Map<String, dynamic>> continueWatching = [];

  late PageController _heroBannerController;
  Timer? _heroBannerTimer;
  int _heroBannerPage = 0;

  // Focus tracking for content cards
  String? _focusedSection;
  final Map<String, int> _sectionItemIndices = {
    'providers': 0,
    'continue': 0,
    'trending_movies': 0,
    'trending_series': 0,
    'popular_movies': 0,
    'top_rated': 0,
  };

  @override
  void initState() {
    super.initState();
    _heroBannerController = PageController();
    _loadContent();
  }

  @override
  void dispose() {
    _heroBannerController.dispose();
    _heroBannerTimer?.cancel();
    super.dispose();
  }

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex => 5; // Hero banner, Providers, Continue Watching, Trending Movies, Trending Series, Popular Movies, Top Rated

  @override
  void onFocusChanged(int index) {
    setState(() {
      _focusedSection = [
        'hero',
        'providers',
        'continue',
        'trending_movies',
        'trending_series',
        'popular_movies',
        'top_rated',
      ][index];
    });
  }

  @override
  void onSelectPressed() {
    // Selection handled by content cards themselves
  }

  @override
  void onLeftPressed() {
    if (_focusedSection == null) return;

    if (_focusedSection == 'hero' || _focusedSection == 'providers') {
      // For hero and providers, left might not apply or could cycle
      return;
    }

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

    if (_focusedSection == 'hero' || _focusedSection == 'providers') {
      // For hero and providers, right might not apply or could cycle
      return;
    }

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
      case 'continue':
        return continueWatching.take(10).length;
      case 'trending_movies':
        return trendingMovies.take(10).length;
      case 'trending_series':
        return trendingSeries.take(10).length;
      case 'popular_movies':
        return popularMovies.take(10).length;
      case 'top_rated':
        return topRatedMovies.take(10).length;
      default:
        return 0;
    }
  }

  void _startHeroBannerTimer() {
    _heroBannerTimer?.cancel();
    _heroBannerTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (trendingMovies.isNotEmpty) {
        _heroBannerPage = (_heroBannerPage + 1) % trendingMovies.length;
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

  Future<void> _loadContent() async {
    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        TmdbApiService.fetchTrendingMovies(),
        TmdbApiService.fetchTrendingSeries(),
        TmdbApiService.fetchPopularMovies(),
        TmdbApiService.fetchTopRatedMovies(),
        WatchHistoryService.getWatchHistory(),
      ]);

      setState(() {
        trendingMovies = results[0];
        trendingSeries = results[1];
        popularMovies = results[2];
        topRatedMovies = results[3];
        continueWatching = results[4].take(10).toList();
      });

      // Start auto-scrolling hero banner
      if (trendingMovies.isNotEmpty) {
        _startHeroBannerTimer();
      }
    } catch (e) {
      print('Error loading content: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TvSearchScreen()),
    );
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
            'MaxStream TV',
            style: TextStyle(
              fontSize: TvUtils.responsiveFontSize(32, context, maxSize: 48),
              color: const Color(0xFFE50914),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.search,
                size: TvUtils.responsiveFontSize(28, context, maxSize: 40),
              ),
              onPressed: _openSearch,
            ),
            SizedBox(width: TvUtils.responsivePadding(16, context)),
          ],
        ),
        body: isLoading
            ? _buildLoadingShimmer()
            : RefreshIndicator(
                onRefresh: _loadContent,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeroBanner()),
                    SliverToBoxAdapter(child: _buildProvidersSection()),
                    if (continueWatching.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildSection(
                          'Continue Watching',
                          continueWatching,
                          'mixed',
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: _buildSection(
                        'Trending Movies',
                        trendingMovies,
                        'movie',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSection(
                        'Trending Series',
                        trendingSeries,
                        'series',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSection(
                        'Popular Movies',
                        popularMovies,
                        'movie',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSection(
                        'Top Rated Movies',
                        topRatedMovies,
                        'movie',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: TvUtils.responsivePadding(48, context),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
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

  Widget _buildHeroBanner() {
    if (trendingMovies.isEmpty) {
      return Container(height: 500, color: Colors.grey[800]);
    }

    return Column(
      children: [
        SizedBox(
          height: 550,
          child: PageView.builder(
            controller: _heroBannerController,
            onPageChanged: (page) {
              setState(() => _heroBannerPage = page);
            },
            itemCount: trendingMovies.length,
            itemBuilder: (context, index) {
              return _buildBannerItem(trendingMovies[index]);
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
              trendingMovies.length,
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
            builder: (context) => TvDetailsScreen(
              item: Movie.fromJson(heroItem),
              mediaType: 'movie',
            ),
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
                    heroItem['title'] ?? 'Unknown',
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
                  // Meta Info (Rating, Year, Genres, Runtime)
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
                              builder: (context) => TvDetailsScreen(
                                item: Movie.fromJson(heroItem),
                                mediaType: 'movie',
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
                              builder: (context) => TvDetailsScreen(
                                item: Movie.fromJson(heroItem),
                                mediaType: 'movie',
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

  Widget _buildProvidersSection() {
    final providers = [
      _ProviderInfo(
        id: 8,
        name: 'Netflix',
        color: const Color(0xFFE50914),
        logoPath: '/9ghgSC0MA082EL6HCkmYiIsz482.jpg',
      ),
      _ProviderInfo(
        id: 9,
        name: 'Prime Video',
        color: const Color(0xFF146EB7),
        logoPath: '/68MNrwlkpF7WnmNPOKYmetUWezO.jpg',
      ),
      _ProviderInfo(
        id: 337,
        name: 'Disney+',
        color: const Color(0xFF113CCF),
        logoPath: '/97yvRBw1GzX7fXprcF80er19ot.jpg',
      ),
      _ProviderInfo(
        id: 15,
        name: 'Hulu',
        color: const Color(0xFF1CE783),
        logoPath: '/bxBlRPEPpMVDc4jMhSrTf2339DW.jpg',
      ),
      _ProviderInfo(
        id: 350,
        name: 'Apple TV',
        color: const Color(0xFF1F1F1F),
        logoPath: '/mcbz1LgtErU9p4UdbZ0rG6RTWHX.jpg',
      ),
      _ProviderInfo(
        id: 1899,
        name: 'HBO Max',
        color: const Color(0xFF542DBF),
        logoPath: '/jbe4gVSfRlbPTdESXhEKpornsfu.jpg',
      ),
      _ProviderInfo(
        id: 386,
        name: 'Peacock',
        color: const Color(0xFF1B365D),
        logoPath: '/2aGrp1xw3qhwCYvNGAJZPdjfeeX.jpg',
      ),
      _ProviderInfo(
        id: 582,
        name: 'Paramount+',
        color: const Color(0xFF0064FF),
        logoPath: '/5qda0qKT6I1tm5EUOlw3YqQ5w.jpg',
      ),
      _ProviderInfo(
        id: 526,
        name: 'AMC+',
        color: const Color(0xFF1A1A1A),
        logoPath: '/ovmu6uot1XVvsemM2dDySXLiX57.jpg',
      ),
    ];

    final padding = TvUtils.responsivePadding(32, context);

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, padding * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Streaming Providers',
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(24, context, maxSize: 32),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(16, context)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(providers.length, (index) {
                final provider = providers[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == providers.length - 1 ? 0 : 16,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProviderContentScreen(
                            providerId: provider.id,
                            providerName: provider.name,
                            providerColor: provider.color,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: provider.color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: provider.color.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: provider.logoPath != null
                                ? Image.network(
                                    'https://image.tmdb.org/t/p/w92${provider.logoPath}',
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) => Center(
                                          child: Text(
                                            provider.name.substring(0, 1),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                  )
                                : Center(
                                    child: Text(
                                      provider.name.substring(0, 1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: TvUtils.responsiveFontSize(12, context),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> items,
    String type,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final padding = TvUtils.responsivePadding(32, context);
    final fontSize = TvUtils.responsiveFontSize(24, context, maxSize: 32);

    return Padding(
      padding: EdgeInsets.only(bottom: TvUtils.responsivePadding(48, context)),
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
                  onTap: () => _showFullList(title, type),
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
                final isFocused =
                    _focusedSection == type &&
                    _sectionItemIndices[type] == index;
                return _buildContentCard(
                  item,
                  type,
                  index: index,
                  section: type,
                  isFocused: isFocused,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullList(String title, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TvFullListScreen(
          title: title,
          contentType: type,
          onReturnToSidebar: widget.onReturnToSidebar,
        ),
      ),
    );
  }

  Widget _buildContentCard(
    Map<String, dynamic> item,
    String type, {
    int index = 0,
    String section = '',
    bool isFocused = false,
  }) {
    final posterUrl = TmdbApiService.getPosterUrl(item['poster_path'] ?? '');

    final isMovie = type == 'movie' || item['media_type'] == 'movie';
    final title = item['title'] ?? item['name'] ?? 'Unknown';

    return TvContentFocusCard(
      isFocused: isFocused,
      scale: 1.12,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (item['media_type'] == 'tv' ||
                  (type == 'series' && !isMovie)) {
                return TvSeriesScreen(seriesItem: Movie.fromJson(item));
              } else {
                return TvDetailsScreen(
                  item: Movie.fromJson(item),
                  mediaType: isMovie ? 'movie' : 'tv',
                );
              }
            },
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
                        child: Icon(
                          isMovie ? Icons.movie : Icons.tv,
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

class _ProviderInfo {
  final int id;
  final String name;
  final Color color;
  final String? logoPath;

  _ProviderInfo({
    required this.id,
    required this.name,
    required this.color,
    this.logoPath,
  });
}

class _TvFullListScreen extends StatefulWidget {
  final String title;
  final String contentType;
  final VoidCallback? onReturnToSidebar;

  const _TvFullListScreen({
    required this.title,
    required this.contentType,
    this.onReturnToSidebar,
  });

  @override
  State<_TvFullListScreen> createState() => _TvFullListScreenState();
}

class _TvFullListScreenState extends State<_TvFullListScreen>
    with TvDpadNavigationMixin {
  List<Map<String, dynamic>> _allItems = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  late ScrollController _scrollController;

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
    if (currentFocus > 0 && currentFocus % 3 != 0) {
      // Navigate left within grid
      setFocusIndex(currentFocus - 1);
    } else if (currentFocus % 3 == 0 && widget.onReturnToSidebar != null) {
      // At leftmost column: return to sidebar
      widget.onReturnToSidebar!();
    }
  }

  @override
  void onRightPressed() {
    final currentFocus = getFocusIndex();
    if (currentFocus + 1 < _allItems.length && (currentFocus + 1) % 3 != 0) {
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
    int newIndex = currentFocus + 3;
    if (newIndex < _allItems.length) {
      setFocusIndex(newIndex);
    }
  }

  void _moveUp() {
    final currentFocus = getFocusIndex();
    int newIndex = currentFocus - 3;
    if (newIndex >= 0) {
      setFocusIndex(newIndex);
    }
  }

  Future<void> _loadInitialItems() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> items = [];

      if (widget.title.contains('Trending') && widget.contentType == 'movie') {
        items = await TmdbApiService.fetchTrendingMovies(page: 1);
      } else if (widget.title.contains('Trending') &&
          widget.contentType == 'series') {
        items = await TmdbApiService.fetchTrendingSeries(page: 1);
      } else if (widget.title.contains('Popular') &&
          widget.contentType == 'movie') {
        items = await TmdbApiService.fetchPopularMovies(page: 1);
      } else if (widget.title.contains('Top Rated') &&
          widget.contentType == 'movie') {
        items = await TmdbApiService.fetchTopRatedMovies(page: 1);
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

      if (widget.title.contains('Trending') && widget.contentType == 'movie') {
        newItems = await TmdbApiService.fetchTrendingMovies(page: _currentPage);
      } else if (widget.title.contains('Trending') &&
          widget.contentType == 'series') {
        newItems = await TmdbApiService.fetchTrendingSeries(page: _currentPage);
      } else if (widget.title.contains('Popular') &&
          widget.contentType == 'movie') {
        newItems = await TmdbApiService.fetchPopularMovies(page: _currentPage);
      } else if (widget.title.contains('Top Rated') &&
          widget.contentType == 'movie') {
        newItems = await TmdbApiService.fetchTopRatedMovies(page: _currentPage);
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
    final isMovie = widget.contentType == 'movie';
    final title = item['title'] ?? item['name'] ?? 'Unknown';
    final year = isMovie
        ? (item['release_date']?.toString().split('-')[0] ?? '')
        : (item['first_air_date']?.toString().split('-')[0] ?? '');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (isMovie) {
                return TvDetailsScreen(
                  item: Movie.fromJson(item),
                  mediaType: 'movie',
                );
              } else {
                return TvSeriesScreen(seriesItem: Movie.fromJson(item));
              }
            },
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
                      child: Icon(
                        isMovie ? Icons.movie : Icons.tv,
                        color: Colors.grey,
                        size: 40,
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
