import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/tmdb_api_service.dart';
import '../widgets/series_hero_banner.dart';
import 'onstream_series_screen.dart';

class OnStreamSeriesListScreen extends StatefulWidget {
  const OnStreamSeriesListScreen({super.key});

  @override
  State<OnStreamSeriesListScreen> createState() => _OnStreamSeriesListScreenState();
}

class _OnStreamSeriesListScreenState extends State<OnStreamSeriesListScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> trendingSeries = [];
  List<Map<String, dynamic>> popularSeries = [];
  List<Map<String, dynamic>> topRatedSeries = [];

  @override
  void initState() {
    super.initState();
    _loadContent();
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
              _buildSection('Trending TV Shows', trendingSeries, 'tv'),
              _buildSection('Popular TV Shows', popularSeries, 'tv'),
              _buildSection('Top Rated TV Shows', topRatedSeries, 'tv'),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ],
        ),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tv,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'TV Series',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(50.0),
        child: CircularProgressIndicator(color: Colors.red),
      ),
    );
  }

  Widget _buildHeroBannerSection() {
    return const SliverToBoxAdapter(
      child: SeriesHeroBanner(),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items, String mediaType) {
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
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
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
                return _buildSeriesCard(item, mediaType);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(Map<String, dynamic> item, String mediaType) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OnStreamSeriesScreen(seriesItem: Movie.fromJson(item)),
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
                          child: const Icon(Icons.tv, color: Colors.grey),
                        ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
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
              item['name'] ?? 'Unknown',
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
      ),
    );
  }

  void _showFullList(String title, String mediaType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullListScreen(
          title: title,
          mediaType: mediaType,
        ),
      ),
    );
  }

  String _getYear(Map<String, dynamic> item) {
    final date = item['first_air_date'];
    if (date != null && date.length >= 4) {
      return date.substring(0, 4);
    }
    return '';
  }
}

class _FullListScreen extends StatefulWidget {
  final String title;
  final String mediaType;

  const _FullListScreen({
    required this.title,
    required this.mediaType,
  });

  @override
  _FullListScreenState createState() => _FullListScreenState();
}

class _FullListScreenState extends State<_FullListScreen> {
  List<Map<String, dynamic>> _allItems = [];
  bool _isLoading = false;
  int _currentPage = 1;
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
      
      // Determine which API method to call based on the title
      if (widget.title.contains('Trending') && widget.mediaType == 'tv') {
        initialItems = await TmdbApiService.fetchTrendingSeries(page: 1);
      } else if (widget.title.contains('Popular') && widget.mediaType == 'tv') {
        initialItems = await TmdbApiService.fetchPopularSeries(page: 1);
      } else if (widget.title.contains('Top Rated') && widget.mediaType == 'tv') {
        initialItems = await TmdbApiService.fetchTopRatedSeries(page: 1);
      }

      setState(() {
        _allItems = initialItems;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading initial items: $e');
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
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isLoading) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      _currentPage++;
      List<Map<String, dynamic>> newItems = [];

      // Determine which API method to call based on the title
      if (widget.title.contains('Trending') && widget.mediaType == 'tv') {
        newItems = await TmdbApiService.fetchTrendingSeries(page: _currentPage);
      } else if (widget.title.contains('Popular') && widget.mediaType == 'tv') {
        newItems = await TmdbApiService.fetchPopularSeries(page: _currentPage);
      } else if (widget.title.contains('Top Rated') && widget.mediaType == 'tv') {
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading && _allItems.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.6,
              ),
              itemCount: _allItems.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _allItems.length) {
                  final item = _allItems[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OnStreamSeriesScreen(seriesItem: Movie.fromJson(item)),
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
                                    TmdbApiService.getPosterUrl(item['poster_path']),
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: double.infinity,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.tv, color: Colors.grey, size: 40),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['name'] ?? 'Unknown',
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
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                }
              },
            ),
    );
  }

  String _getYear(Map<String, dynamic> item) {
    final date = item['first_air_date'];
    if (date != null && date.length >= 4) {
      return date.substring(0, 4);
    }
    return '';
  }
}
