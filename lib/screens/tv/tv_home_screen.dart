import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/movie.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';
import '../../utils/tv_utils.dart';
import 'tv_search_screen.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';
import '../provider_content_screen.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> trendingMovies = [];
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularMovies = [];
  List<Map<String, dynamic>> topRatedMovies = [];
  List<Map<String, dynamic>> continueWatching = [];

  @override
  void initState() {
    super.initState();
    _loadContent();
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
    } catch (e) {
      print('Error loading content: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TvSearchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                   SliverToBoxAdapter(
                     child: _buildHeroBanner(),
                   ),
                   SliverToBoxAdapter(
                     child: _buildProvidersSection(),
                   ),
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
                    child: SizedBox(height: TvUtils.responsivePadding(48, context)),
                  ),
                ],
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
      return Container(
        height: 500,
        color: Colors.grey[800],
      );
    }

    final heroItem = trendingMovies[0];
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
        height: 550,
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
                    Colors.black.withOpacity(0.9),
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
                  // Title
                  Text(
                    heroItem['title'] ?? 'Unknown',
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
                          'Play',
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
    final releaseDate =
        item['release_date'] ?? item['first_air_date'] ?? '';
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
          .map<String>((genre) =>
              (genre is Map && genre.containsKey('name'))
                  ? genre['name']
                  : genre.toString())
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
                              fontSize:
                                  TvUtils.responsiveFontSize(12, context),
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
                return _buildContentCard(item, type);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> item, String type) {
    final posterUrl = TmdbApiService.getPosterUrl(
      item['poster_path'] ?? '',
    );

    final isMovie = type == 'movie' || item['media_type'] == 'movie';
    final title = item['title'] ?? item['name'] ?? 'Unknown';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (item['media_type'] == 'tv' ||
                  (type == 'series' && !isMovie)) {
                return TvSeriesScreen(
                  seriesItem: Movie.fromJson(item),
                );
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
