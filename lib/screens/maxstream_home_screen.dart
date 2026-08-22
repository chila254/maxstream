import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../models/movie.dart';
import '../services/cloud_sync_service.dart';
import '../services/tmdb_api_service.dart';
import '../utils/tmdb_list_utils.dart';
import '../services/watch_history_service.dart';
import '../widgets/hero_banner.dart';
import '../widgets/custom_loading_widget.dart';
import '../widgets/continue_watching_section.dart';
import '../widgets/profile_menu_button.dart';
import 'maxstream_details_screen.dart';
import 'maxstream_series_screen.dart';
import 'provider_content_screen.dart';

class MaxStreamHomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const MaxStreamHomeScreen({super.key, this.onTabChange});

  @override
  State<MaxStreamHomeScreen> createState() => _MaxStreamHomeScreenState();
}

class _MaxStreamHomeScreenState extends State<MaxStreamHomeScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> trendingMovies = [];
  List<Map<String, dynamic>> popularMovies = [];
  List<Map<String, dynamic>> topRatedMovies = [];
  List<Map<String, dynamic>> continueWatching = [];

  @override
  void initState() {
    super.initState();
    CloudSyncService.historyRevision.addListener(_onSyncedHistory);
    _loadContent();
  }

  void _onSyncedHistory() {
    if (mounted) _loadContinueWatching();
  }

  @override
  void dispose() {
    CloudSyncService.historyRevision.removeListener(_onSyncedHistory);
    super.dispose();
  }

  Future<void> _loadContent() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final syncFuture = CloudSyncService.pullToDevice();
      final results = await Future.wait([
        TmdbApiService.fetchTrendingMovies(),
        TmdbApiService.fetchPopularMovies(),
        TmdbApiService.fetchTopRatedMovies(),
        syncFuture.then((_) => WatchHistoryService.getContinueWatching()),
      ]);

      if (!mounted) return;
      setState(() {
        trendingMovies = results[0];
        popularMovies = results[1];
        topRatedMovies = results[2];
        continueWatching = results[3].take(10).toList();
      });
    } catch (e) {
      // Error loading content
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        onRefresh: _loadContent,
        child: isLoading
            ? _buildLoadingShimmer()
            : CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  const SliverToBoxAdapter(child: HeroBanner()),
                  SliverToBoxAdapter(
                    child: ContinueWatchingSection(
                      continueWatching: continueWatching,
                      onChanged: _loadContinueWatching,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildProvidersSection()),
                  _buildSection('Trending Movies', trendingMovies, 'movie'),
                  _buildSection('Popular Movies', popularMovies, 'movie'),
                  _buildSection('Top Rated Movies', topRatedMovies, 'movie'),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }

  Future<void> _loadContinueWatching() async {
    final history = await WatchHistoryService.getContinueWatching();
    if (!mounted) return;
    setState(() => continueWatching = history.take(10).toList());
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF1A1A1A),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.grey[800],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 100, height: 24, color: Colors.grey[800]),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero banner skeleton
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Continue watching skeleton
                  Container(height: 24, width: 150, color: Colors.grey[800]),
                  const SizedBox(height: 12),
                  Container(height: 150, color: Colors.grey[800]),
                  const SizedBox(height: 24),

                  // Section 1 skeleton
                  Container(height: 24, width: 150, color: Colors.grey[800]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 160,
                          color: Colors.grey[800],
                          margin: const EdgeInsets.only(right: 8),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 160,
                          color: Colors.grey[800],
                          margin: const EdgeInsets.only(right: 8),
                        ),
                      ),
                      Expanded(
                        child: Container(height: 160, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 2 skeleton
                  Container(height: 24, width: 150, color: Colors.grey[800]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 160,
                          color: Colors.grey[800],
                          margin: const EdgeInsets.only(right: 8),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 160,
                          color: Colors.grey[800],
                          margin: const EdgeInsets.only(right: 8),
                        ),
                      ),
                      Expanded(
                        child: Container(height: 160, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 3 skeleton
                  Container(height: 24, width: 150, color: Colors.grey[800]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 160,
                          color: Colors.grey[800],
                          margin: const EdgeInsets.only(right: 8),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 160,
                          color: Colors.grey[800],
                          margin: const EdgeInsets.only(right: 8),
                        ),
                      ),
                      Expanded(
                        child: Container(height: 160, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: const Color(0xFF1A1A1A),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'MaxStream',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 8),
          child: ProfileMenuButton(),
        ),
      ],
    );
  }

  Widget _buildProvidersSection() {
    final providers = [
      _ProviderInfo(
        id: 8,
        name: 'Netflix',
        color: const Color(0xFFE50914),
        logoPath: '/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg',
      ),
      _ProviderInfo(
        id: 9,
        name: 'Prime Video',
        color: const Color(0xFF00A8E1),
        logoPath: '/pvske1MyAoymrs5bguRfVqYiM9a.jpg',
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Streaming Providers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(providers.length, (index) {
                final provider = providers[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == providers.length - 1 ? 0 : 12,
                  ),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
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
                      child: SizedBox(
                        width: 94,
                        height: 112,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: provider.color,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: provider.color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: provider.logoPath != null
                                    ? Image.network(
                                        'https://image.tmdb.org/t/p/w92${provider.logoPath}',
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Center(
                                                  child: Text(
                                                    provider.name.substring(
                                                      0,
                                                      1,
                                                    ),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
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
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
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
    String mediaType,
  ) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _showFullList(title, mediaType);
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              ],
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
                return _buildMovieCard(item, mediaType);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> item, String mediaType) {
    return GestureDetector(
      onTap: () {
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.fastOutSlowIn,
                          ),
                        ),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 250),
          ),
        );
      },
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
                  item['poster_path'] != null
                      ? Image.network(
                          TmdbApiService.getPosterUrl(item['poster_path']),
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
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${item['vote_average']?.toStringAsFixed(1) ?? 'N/A'}',
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
              item['title'] ?? item['name'] ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _getYear(item),
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullList(String title, String mediaType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _FullListScreen(title: title, mediaType: mediaType),
      ),
    );
  }

  String _getYear(Map<String, dynamic> item) {
    final date = item['release_date'] ?? item['first_air_date'];
    if (date != null && date.length >= 4) {
      return date.substring(0, 4);
    }
    return '';
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

class _FullListScreen extends StatefulWidget {
  final String title;
  final String mediaType;

  const _FullListScreen({required this.title, required this.mediaType});

  @override
  _FullListScreenState createState() => _FullListScreenState();
}

class _FullListScreenState extends State<_FullListScreen> {
  List<Map<String, dynamic>> _allItems = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadInitialItems();
  }

  Future<void> _loadInitialItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> initialItems = [];

      if (widget.title.contains('Trending') && widget.mediaType == 'movie') {
        initialItems = await TmdbApiService.fetchTrendingMovies(page: 1);
      } else if (widget.title.contains('Popular') &&
          widget.mediaType == 'movie') {
        initialItems = await TmdbApiService.fetchPopularMovies(page: 1);
      } else if (widget.title.contains('Top Rated') &&
          widget.mediaType == 'movie') {
        initialItems = await TmdbApiService.fetchTopRatedMovies(page: 1);
      } else if (widget.title.contains('Trending') &&
          widget.mediaType == 'tv') {
        initialItems = await TmdbApiService.fetchTrendingSeries(page: 1);
      } else if (widget.title.contains('Popular') && widget.mediaType == 'tv') {
        initialItems = await TmdbApiService.fetchPopularSeries(page: 1);
      } else if (widget.title.contains('Top Rated') &&
          widget.mediaType == 'tv') {
        initialItems = await TmdbApiService.fetchTopRatedSeries(page: 1);
      }

      setState(() {
        _allItems = initialItems;
        _isLoading = false;
      });
    } catch (e) {
      // Error loading initial items
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMore) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nextPage = _currentPage + 1;
      List<Map<String, dynamic>> newItems = [];

      if (widget.title.contains('Trending') && widget.mediaType == 'movie') {
        newItems = await TmdbApiService.fetchTrendingMovies(page: nextPage);
      } else if (widget.title.contains('Popular') &&
          widget.mediaType == 'movie') {
        newItems = await TmdbApiService.fetchPopularMovies(page: nextPage);
      } else if (widget.title.contains('Top Rated') &&
          widget.mediaType == 'movie') {
        newItems = await TmdbApiService.fetchTopRatedMovies(page: nextPage);
      } else if (widget.title.contains('Trending') &&
          widget.mediaType == 'tv') {
        newItems = await TmdbApiService.fetchTrendingSeries(page: nextPage);
      } else if (widget.title.contains('Popular') && widget.mediaType == 'tv') {
        newItems = await TmdbApiService.fetchPopularSeries(page: nextPage);
      } else if (widget.title.contains('Top Rated') &&
          widget.mediaType == 'tv') {
        newItems = await TmdbApiService.fetchTopRatedSeries(page: nextPage);
      }

      if (!mounted) return;
      final merged = uniqueTmdbItems(_allItems, newItems, widget.mediaType);
      setState(() {
        _hasMore = merged.length > _allItems.length;
        _allItems = merged;
        if (_hasMore) _currentPage = nextPage;
      });
    } catch (e) {
      // Error loading more items
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.6,
              ),
              itemCount: _allItems.length,
              itemBuilder: (context, index) {
                final item = _allItems[index];
                return GestureDetector(
                  key: ValueKey(tmdbItemKey(item, widget.mediaType)),
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            widget.mediaType == 'tv'
                            ? MaxStreamSeriesScreen(
                                seriesItem: Movie.fromJson(item),
                              )
                            : MaxStreamDetailsScreen(
                                item: Movie.fromJson(item),
                                mediaType: widget.mediaType,
                              ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(1.0, 0.0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.fastOutSlowIn,
                                      ),
                                    ),
                                child: child,
                              );
                            },
                        transitionDuration: const Duration(milliseconds: 250),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item['poster_path'] != null
                              ? Image.network(
                                  TmdbApiService.getPosterUrl(
                                    item['poster_path'],
                                  ),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: double.infinity,
                                  color: Colors.grey[800],
                                  child: Icon(
                                    widget.mediaType == 'tv'
                                        ? Icons.tv
                                        : Icons.movie,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title'] ?? item['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getYear(item),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CustomLoadingWidget(
                size: 30,
                color: Color(0xFFE50914),
                style: LoadingStyle.dots,
              ),
            ),
        ],
      ),
    );
  }

  String _getYear(Map<String, dynamic> item) {
    final date = item['release_date'] ?? item['first_air_date'];
    if (date != null && date.length >= 4) {
      return date.substring(0, 4);
    }
    return '';
  }
}
