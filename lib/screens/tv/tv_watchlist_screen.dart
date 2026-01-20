import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/movie.dart';
import '../../utils/tv_utils.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';

class TvWatchlistScreen extends StatefulWidget {
  const TvWatchlistScreen({super.key});

  @override
  State<TvWatchlistScreen> createState() => _TvWatchlistScreenState();
}

class _TvWatchlistScreenState extends State<TvWatchlistScreen>
    with SingleTickerProviderStateMixin {
  List<Movie> watchlistItems = [];
  List<Movie> movies = [];
  List<Movie> series = [];
  bool isLoading = true;
  bool _showVertical = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWatchlist();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWatchlist() async {
    setState(() => isLoading = true);
    try {
      final items = await DBHelper.getWatchlistItems();
      setState(() {
        watchlistItems = items;
        movies = items.where((item) => item.mediaType != 'tv').toList();
        series = items.where((item) => item.mediaType == 'tv').toList();
      });
    } catch (e) {
      print('Error loading watchlist: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeFromWatchlist(Movie item) async {
    try {
      await DBHelper.removeFromWatchlist(item.id);
      await _loadWatchlist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('${item.title} removed from watchlist'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error removing from watchlist: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = TvUtils.responsiveFontSize(24, context, maxSize: 32);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'My Watchlist',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadWatchlist,
            icon: Icon(
              Icons.refresh,
              color: Colors.white,
              size: TvUtils.responsiveFontSize(24, context),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showVertical = !_showVertical;
              });
            },
            icon: Icon(
              _showVertical ? Icons.view_module : Icons.view_list,
              color: Colors.white,
              size: TvUtils.responsiveFontSize(24, context),
            ),
          ),
          SizedBox(width: TvUtils.responsivePadding(16, context)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              text: 'All (${watchlistItems.length})',
              child: Text(
                'All (${watchlistItems.length})',
                style: TextStyle(
                  fontSize: TvUtils.responsiveFontSize(16, context),
                ),
              ),
            ),
            Tab(
              text: 'Movies (${movies.length})',
              child: Text(
                'Movies (${movies.length})',
                style: TextStyle(
                  fontSize: TvUtils.responsiveFontSize(16, context),
                ),
              ),
            ),
            Tab(
              text: 'Series (${series.length})',
              child: Text(
                'Series (${series.length})',
                style: TextStyle(
                  fontSize: TvUtils.responsiveFontSize(16, context),
                ),
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : TabBarView(
              controller: _tabController,
              children: [
                watchlistItems.isEmpty
                    ? _buildEmptyState()
                    : (_showVertical
                          ? _buildWatchlistGrid(watchlistItems)
                          : _buildHorizontalList(watchlistItems)),
                movies.isEmpty
                    ? _buildEmptyState()
                    : (_showVertical
                          ? _buildWatchlistGrid(movies)
                          : _buildHorizontalList(movies)),
                series.isEmpty
                    ? _buildEmptyState()
                    : (_showVertical
                          ? _buildWatchlistGrid(series)
                          : _buildHorizontalList(series)),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: TvUtils.responsiveFontSize(64, context, maxSize: 100),
            color: Colors.grey,
          ),
          SizedBox(height: TvUtils.responsivePadding(24, context)),
          Text(
            'Your watchlist is empty',
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(24, context, maxSize: 32),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(12, context)),
          Text(
            'Add movies and TV shows to keep track of what you want to watch',
            style: TextStyle(
              color: Colors.grey,
              fontSize: TvUtils.responsiveFontSize(16, context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistGrid(List<Movie> items) {
    return GridView.builder(
      padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.6,
        crossAxisSpacing: TvUtils.responsivePadding(16, context),
        mainAxisSpacing: TvUtils.responsivePadding(16, context),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildWatchlistItem(item);
      },
    );
  }

  Widget _buildHorizontalList(List<Movie> items) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _buildSeeAllButton();
        }
        final item = items[index];
        return Container(
          width: 200,
          margin: EdgeInsets.only(
            right: TvUtils.responsivePadding(16, context),
          ),
          child: _buildWatchlistItem(item),
        );
      },
    );
  }

  Widget _buildWatchlistItem(Movie item) {
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => item.mediaType == 'tv'
                ? TvSeriesScreen(seriesItem: item)
                : TvDetailsScreen(item: item, mediaType: item.mediaType),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.thumbnail.isNotEmpty
                      ? Image.network(
                          item.thumbnail,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.grey,
                                  size: 60,
                                ),
                              ),
                        )
                      : Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.movie,
                            color: Colors.grey,
                            size: 60,
                          ),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeFromWatchlist(item),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                if (item.rating > 0)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
          SizedBox(height: TvUtils.responsivePadding(8, context)),
          Text(
            item.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(14, context),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.year.isNotEmpty)
            Text(
              item.year,
              style: TextStyle(
                color: Colors.grey,
                fontSize: TvUtils.responsiveFontSize(12, context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeeAllButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showVertical = true;
        });
      },
      child: Container(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
            SizedBox(height: TvUtils.responsivePadding(8, context)),
            Text(
              'See All',
              style: TextStyle(
                color: Colors.white,
                fontSize: TvUtils.responsiveFontSize(14, context),
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
}
