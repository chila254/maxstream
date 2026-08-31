import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/tmdb_api_service.dart';
import '../widgets/custom_loading_widget.dart';
import '../widgets/profile_menu_button.dart';
import 'maxstream_details_screen.dart';
import 'maxstream_series_screen.dart';
import 'actor_details_screen.dart';
import '../widgets/app_network_image.dart';

class MaxStreamSearchScreen extends StatefulWidget {
  const MaxStreamSearchScreen({super.key});

  @override
  State<MaxStreamSearchScreen> createState() => _MaxStreamSearchScreenState();
}

class _MaxStreamSearchScreenState extends State<MaxStreamSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = false;
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> actorResults = [];

  final List<String> _searchTabs = ['All', 'Movies', 'TV Shows', 'Actors'];
  int _currentTabIndex = 0;
  int _searchGeneration = 0;

  // Top Searched / Most Watched (idle state when no query)
  List<Map<String, dynamic>> topSearched = [];
  List<Map<String, dynamic>> mostWatched = [];
  bool isLoadingRecommendations = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _searchTabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      }
    });
    _loadSearchRecommendations();
  }

  Future<void> _loadSearchRecommendations() async {
    setState(() => isLoadingRecommendations = true);
    try {
      final results = await Future.wait([
        TmdbApiService.fetchTrendingMovies().catchError((_) => <Map<String, dynamic>>[]),
        TmdbApiService.fetchTrendingSeries().catchError((_) => <Map<String, dynamic>>[]),
        TmdbApiService.fetchPopularMovies().catchError((_) => <Map<String, dynamic>>[]),
        TmdbApiService.fetchPopularSeries().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      final trending = [...results[0], ...results[1]]..shuffle();
      final popular = [...results[2], ...results[3]]..shuffle();
      setState(() {
        topSearched = trending.take(10).toList();
        mostWatched = popular.take(10).toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => isLoadingRecommendations = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final generation = ++_searchGeneration;
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      if (!mounted) return;
      setState(() {
        searchResults = [];
        actorResults = [];
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      switch (_currentTabIndex) {
        case 0: // All
          final results = await TmdbApiService.searchAll(trimmedQuery);
          if (!mounted || generation != _searchGeneration) return;
          setState(() {
            searchResults = results;
            actorResults = results
                .where((item) => item['media_type'] == 'person')
                .toList();
          });
          break;
        case 1: // Movies
          final results = await TmdbApiService.searchMovies(trimmedQuery);
          if (!mounted || generation != _searchGeneration) return;
          setState(() {
            searchResults = results;
            actorResults = [];
          });
          break;
        case 2: // TV Shows
          final results = await TmdbApiService.searchSeries(trimmedQuery);
          if (!mounted || generation != _searchGeneration) return;
          setState(() {
            searchResults = results;
            actorResults = [];
          });
          break;
        case 3: // Actors
          final results = await TmdbApiService.searchActors(trimmedQuery);
          if (!mounted || generation != _searchGeneration) return;
          setState(() {
            searchResults = [];
            actorResults = results;
          });
          break;
      }
    } catch (e) {
      // Error searching
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Search',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ProfileMenuButton(),
          ),
        ],
        bottom: _searchController.text.trim().isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.red,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: _searchTabs.map((tab) => Tab(text: tab)).toList(),
              ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _searchController.text.trim().isEmpty
                ? _buildSearchRecommendations()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllResults(), // All
                      _buildMovieResults(), // Movies
                      _buildTVResults(), // TV Shows
                      _buildActorResults(), // Actors
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRecommendations() {
    if (isLoadingRecommendations) return _buildRecommendationsShimmer();
    if (topSearched.isEmpty && mostWatched.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 48, color: Colors.grey[700]),
              const SizedBox(height: 12),
              Text('No recommendations yet', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadSearchRecommendations,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSearchRecommendations,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topSearched.isNotEmpty) ...[
              _buildSectionHeader('Top Searched'),
              _buildRecommendationCarousel(topSearched),
            ],
            if (mostWatched.isNotEmpty) ...[
              _buildSectionHeader('Most Watched'),
              _buildRecommendationCarousel(mostWatched),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsShimmer() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(width: 140, height: 18, color: Colors.grey[800]),
          ),
          SizedBox(
            height: 234,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (_, __) => Container(
                width: 152,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(width: 140, height: 18, color: Colors.grey[800]),
          ),
          SizedBox(
            height: 234,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (_, __) => Container(
                width: 152,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            const Icon(Icons.search_rounded, color: Colors.grey, size: 22),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Search movies, TV shows, actors...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {});
                  if (value.length >= 2) {
                    _performSearch(value);
                  } else {
                    _searchGeneration++;
                    setState(() {
                      searchResults = [];
                      actorResults = [];
                    });
                  }
                },
                onSubmitted: (v) {
                  if (v.trim().length >= 2) _performSearch(v);
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchGeneration++;
                  _searchController.clear();
                  setState(() {
                    searchResults = [];
                    actorResults = [];
                  });
                },
                icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                splashRadius: 18,
              ),
            Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.1)),
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voice search coming soon — tap to speak')),
                );
              },
              icon: const Icon(Icons.mic_rounded, color: Colors.red, size: 22),
              splashRadius: 18,
              tooltip: 'Voice search',
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildAllResults() {
    if (isLoading) return _buildLoadingIndicator();
    if (searchResults.isEmpty &&
        actorResults.isEmpty &&
        _searchController.text.isNotEmpty) {
      return _buildNoResults();
    }

    final movies = searchResults
        .where((item) => item['media_type'] == 'movie')
        .toList();
    final tvShows = searchResults
        .where((item) => item['media_type'] == 'tv')
        .toList();
    final actors = searchResults
        .where((item) => item['media_type'] == 'person')
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (movies.isNotEmpty) _buildSectionHeader('Movies'),
          if (movies.isNotEmpty) _buildMovieGrid(movies),
          if (tvShows.isNotEmpty) _buildSectionHeader('TV Shows'),
          if (tvShows.isNotEmpty) _buildMovieGrid(tvShows),
          if (actors.isNotEmpty) _buildSectionHeader('Actors'),
          if (actors.isNotEmpty) _buildActorGrid(actors),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMovieResults() {
    if (isLoading) return _buildLoadingIndicator();
    if (searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildNoResults();
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMovieGrid(searchResults),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTVResults() {
    if (isLoading) return _buildLoadingIndicator();
    if (searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildNoResults();
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMovieGrid(searchResults),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildActorResults() {
    if (isLoading) return _buildLoadingIndicator();
    if (actorResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildNoResults();
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildActorGrid(actorResults),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final icon = title == 'Top Searched'
        ? Icons.trending_up_rounded
        : title == 'Most Watched'
            ? Icons.local_fire_department_rounded
            : title == 'Movies'
                ? Icons.movie_rounded
                : title == 'TV Shows'
                    ? Icons.tv_rounded
                    : Icons.people_rounded;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildMovieCard(item, isRecommendation: false);
      },
    );
  }

  Widget _buildRecommendationCarousel(List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 268,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildMovieCard(items[index], isRecommendation: true),
      ),
    );
  }

  Widget _buildActorGrid(List<Map<String, dynamic>> actors) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: actors.length,
      itemBuilder: (context, index) {
        final actor = actors[index];
        return _buildActorCard(actor);
      },
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> item, {bool isRecommendation = false}) {
    final card = GestureDetector(
      onTap: () {
        if (!mounted) return;
        final mediaType =
            item['media_type'] ??
            (item['first_air_date'] != null ? 'tv' : 'movie');
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
                            curve: Curves.easeInOut,
                          ),
                        ),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    item['poster_path'] != null
                        ? AppNetworkImage(
                            url: TmdbApiService.getPosterUrl(item['poster_path']),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.grey[800],
                            child: const Icon(Icons.movie, color: Colors.grey, size: 32),
                          ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                          ),
                        ),
                      ),
                    ),
                    if (item['vote_average'] != null && (item['vote_average'] as num) > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 11),
                              const SizedBox(width: 3),
                              Text(
                                (item['vote_average'] as num).toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item['title'] ?? item['name'] ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    if (isRecommendation) {
      return Container(
        width: 152,
        margin: const EdgeInsets.only(right: 10),
        child: card,
      );
    }
    return card;
  }

  Widget _buildActorCard(Map<String, dynamic> actor) {
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ActorDetailsScreen(actorId: actor['id']),
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
                            curve: Curves.easeInOut,
                          ),
                        ),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: actor['profile_path'] != null
                  ? AppNetworkImage(
                      url: TmdbApiService.getProfileUrl(actor['profile_path']),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.person,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            actor['name'] ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (actor['known_for_department'] != null)
            Text(
              actor['known_for_department'],
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(child: SearchLoadingWidget());
  }

  Widget _buildNoResults() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
