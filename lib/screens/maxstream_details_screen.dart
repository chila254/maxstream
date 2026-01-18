import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../database/db_helper.dart';
import '../models/movie.dart';
import '../services/tmdb_api_service.dart';
import 'm3u8_video_player_screen.dart';

class MaxStreamDetailsScreen extends StatefulWidget {
  final Movie item;
  final String mediaType;

  const MaxStreamDetailsScreen({
    super.key,
    required this.item,
    required this.mediaType,
  });

  @override
  State<MaxStreamDetailsScreen> createState() => _MaxStreamDetailsScreenState();
}

class _MaxStreamDetailsScreenState extends State<MaxStreamDetailsScreen> {
  YoutubePlayerController? _youtubeController;
  bool isSaved = false;
  bool isLoading = true;
  String? trailerUrl;
  Map<String, dynamic>? details;
  List<Map<String, dynamic>> cast = [];
  List<Map<String, dynamic>> recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  void _initializeYouTubePlayer(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null) {
      setState(() {
        trailerUrl = url;
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
          ),
        );
      });
    }
  }

  Future<void> _loadDetails() async {
    setState(() => isLoading = true);

    try {
      final id = int.parse(widget.item.id);
      final detailsData = widget.mediaType == 'movie'
          ? await TmdbApiService.getMovieDetails(id)
          : await TmdbApiService.getSeriesDetails(id);

      if (detailsData != null) {
        setState(() {
          details = detailsData;
          cast = List<Map<String, dynamic>>.from(
            detailsData['credits']?['cast'] ?? [],
          );
          recommendations = List<Map<String, dynamic>>.from(
            detailsData['recommendations']?['results'] ?? [],
          );
        });

        // Load trailer
        final trailerUrlFromApi = await TmdbApiService.getTrailerUrl(
          id,
          isMovie: widget.mediaType == 'movie',
        );
        if (trailerUrlFromApi.isNotEmpty) {
          _initializeYouTubePlayer(trailerUrlFromApi);
        }
      }
      _checkWatchlistStatus();
    } catch (e) {
      print('Error loading details: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkWatchlistStatus() async {
    final watchlist = await DBHelper.getWatchlistItems();
    if (mounted) {
      setState(() {
        isSaved = watchlist.any((item) => item.id == widget.item.id);
      });
    }
  }

  Future<void> _toggleWatchlist() async {
    try {
      final wasAdded = !isSaved; // Store the action before state changes

      if (isSaved) {
        await DBHelper.removeFromWatchlist(widget.item.id);
      } else {
        await DBHelper.addToWatchlist(widget.item);
      }
      await _checkWatchlistStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  wasAdded ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  wasAdded ? 'Added to Watchlist' : 'Removed from Watchlist',
                ),
              ],
            ),
            backgroundColor: wasAdded
                ? Colors.green.shade600
                : Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error toggling watchlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Error updating watchlist: $e'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _youtubeController?.pause();
        }
      },
      child: Scaffold(
        body: isLoading
            ? buildLoadingShimmer()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildDetailsSection(),
                        if (cast.isNotEmpty) buildCastSection(),
                        if (recommendations.isNotEmpty)
                          buildRecommendationsSection(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            flexibleSpace: Container(color: Colors.grey[800]),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 24, width: 200, color: Colors.grey[800]),
                  const SizedBox(height: 8),
                  Container(height: 16, width: 150, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  ...List.generate(
                    5,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(height: 16, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSliverAppBar() {
    final backdropPath = details?['backdrop_path'] ?? widget.item.backdropPath;
    final posterPath = details?['poster_path'] ?? widget.item.posterPath;

    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (backdropPath != null)
              Image.network(
                TmdbApiService.getBackdropUrl(backdropPath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.broken_image,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              )
            else
              Container(color: Colors.grey[900]),

            Container(
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

            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: posterPath != null
                        ? Image.network(
                            TmdbApiService.getPosterUrl(posterPath),
                            width: 100,
                            height: 150,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 100,
                            height: 150,
                            color: Colors.grey[800],
                            child: const Icon(Icons.movie),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          details?['title'] ??
                              details?['name'] ??
                              widget.item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (details?['release_date'] != null ||
                            details?['first_air_date'] != null)
                          Text(
                            getYear(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${details?['vote_average']?.toStringAsFixed(1) ?? 'N/A'}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: _toggleWatchlist,
                              icon: Icon(
                                isSaved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: isSaved ? Colors.red : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Watch Now button with modern player
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => playContent(),
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Watch Now',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
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

  Widget buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_youtubeController != null) ...[
            const Text(
              'Trailer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: IgnorePointer(
                ignoring: false,
                child: YoutubePlayer(
                  controller: _youtubeController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.red,
                  progressColors: const ProgressBarColors(
                    playedColor: Colors.red,
                    handleColor: Colors.redAccent,
                  ),
                  onReady: () {
                    _youtubeController?.pause();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details?['overview'] ??
                widget.item.overview ??
                widget.item.description ??
                'No overview available.',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),
          buildInfoGrid(),
        ],
      ),
    );
  }

  Widget buildInfoGrid() {
    final releaseDate = details?['release_date'] ?? details?['first_air_date'];
    final runtime = details?['runtime']?.toString();
    final genres = (details?['genres'] as List<dynamic>?)
        ?.map((g) => g['name'].toString())
        .join(', ');

    return Column(
      children: [
        if (releaseDate != null)
          buildInfoRow('Release Date', formatDate(releaseDate)),
        if (runtime != null) buildInfoRow('Runtime', '$runtime minutes'),
        if (genres != null) buildInfoRow('Genres', genres),
        buildInfoRow(
          'Language',
          details?['original_language']?.toUpperCase() ?? 'N/A',
        ),
        buildInfoRow('Status', details?['status'] ?? 'Unknown'),
        const SizedBox(height: 24),
        buildWatchProvidersSection(),
      ],
    );
  }

  Widget buildWatchProvidersSection() {
    final watchProviders =
        details?['watch/providers']?['results']?['US']?['flatrate'] as List?;

    if (watchProviders == null || watchProviders.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<int, Map<String, dynamic>> providerMap = {
      8: {'name': 'Netflix', 'color': const Color(0xFFE50914)},
      9: {'name': 'Prime Video', 'color': const Color(0xFF00A8E1)},
      337: {'name': 'Disney+', 'color': const Color(0xFF113CCF)},
      15: {'name': 'Hulu', 'color': const Color(0xFF1CE783)},
      179: {'name': 'Apple TV', 'color': const Color(0xFF555555)},
    };

    final availableProviders = <Map<String, dynamic>>[];
    for (var provider in watchProviders) {
      final providerId = provider['provider_id'] as int;
      if (providerMap.containsKey(providerId)) {
        availableProviders.add({
          'id': providerId,
          'name': providerMap[providerId]!['name'],
          'color': providerMap[providerId]!['color'],
          'logo': provider['logo_path'] ?? '',
        });
      }
    }

    if (availableProviders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where to Watch',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: availableProviders.map((provider) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (provider['color'] as Color).withValues(alpha: 0.3),
                    (provider['color'] as Color).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (provider['color'] as Color).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((provider['logo'] as String).isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        'https://image.tmdb.org/t/p/original${provider['logo']}',
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.play_circle,
                            color: provider['color'] as Color,
                            size: 20,
                          );
                        },
                      ),
                    )
                  else
                    Icon(
                      Icons.play_circle,
                      color: provider['color'] as Color,
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    provider['name'] as String,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCastSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Cast',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cast.take(10).length,
            itemBuilder: (context, index) {
              final actor = cast[index];
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: actor['profile_path'] != null
                          ? Image.network(
                              TmdbApiService.getProfileUrl(
                                actor['profile_path'],
                              ),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      actor['name'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      actor['character'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'More Like This',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommendations.take(10).length,
            itemBuilder: (context, index) {
              final item = recommendations[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          MaxStreamDetailsScreen(
                            item: Movie.fromJson(item),
                            mediaType: item['media_type'] ?? widget.mediaType,
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
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item['poster_path'] != null
                            ? Image.network(
                                TmdbApiService.getPosterUrl(
                                  item['poster_path'],
                                ),
                                width: 120,
                                height: 160,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 120,
                                height: 160,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.grey,
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
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String getYear() {
    final date = details?['release_date'] ?? details?['first_air_date'];
    if (date != null && date.length >= 4) {
      return date.substring(0, 4);
    }
    return 'N/A';
  }

  String formatDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }

  void playContent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => M3U8VideoPlayerScreen(
          title: widget.item.title,
          tmdbId: widget.item.id.toString(),
          isMovie: widget.mediaType == 'movie',
        ),
      ),
    );
  }
}
