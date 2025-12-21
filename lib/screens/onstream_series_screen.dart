import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../services/tmdb_api_service.dart';
import '../database/db_helper.dart';
import 'inapp_video_player_screen.dart';

class OnStreamSeriesScreen extends StatefulWidget {
  final Movie seriesItem;

  const OnStreamSeriesScreen({super.key, required this.seriesItem});

  @override
  State<OnStreamSeriesScreen> createState() => _OnStreamSeriesScreenState();
}

class _OnStreamSeriesScreenState extends State<OnStreamSeriesScreen> {
  YoutubePlayerController? _youtubeController;
  Map<String, dynamic>? seriesDetails;
  List<Season> seasons = [];
  int selectedSeasonIndex = 0;
  List<Episode> currentEpisodes = [];
  bool isLoading = true;
  bool isInWatchlist = false;
  bool isLoadingEpisodes = false;
  String? trailerUrl;
  List<Map<String, dynamic>> cast = [];
  List<Map<String, dynamic>> recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadSeriesDetails();
    _checkWatchlistStatus();
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

  Future<void> _loadSeriesDetails() async {
    setState(() => isLoading = true);

    try {
      final details = await TmdbApiService.getSeriesDetails(
        int.parse(widget.seriesItem.id),
      );
      if (details != null && mounted) {
        setState(() {
          seriesDetails = details;
          seasons = (details['seasons'] as List)
              .map((season) => Season.fromJson(season))
              .where((season) => season.seasonNumber > 0) // Filter out specials
              .toList();
          cast = List<Map<String, dynamic>>.from(
            details['credits']?['cast'] ?? [],
          );
          recommendations = List<Map<String, dynamic>>.from(
            details['recommendations']?['results'] ?? [],
          );
        });

        if (seasons.isNotEmpty) {
          _loadSeasonEpisodes(seasons[0].seasonNumber);
        }

        // Load trailer
        final trailerUrlFromApi = await TmdbApiService.getTrailerUrl(
          int.parse(widget.seriesItem.id),
          isMovie: false,
        );
        if (trailerUrlFromApi.isNotEmpty) {
          _initializeYouTubePlayer(trailerUrlFromApi);
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
        int.parse(widget.seriesItem.id),
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

  Future<void> _checkWatchlistStatus() async {
    final watchlist = await DBHelper.getWatchlistItems();
    if (mounted) {
      setState(() {
        isInWatchlist = watchlist.any(
          (item) => item.id == widget.seriesItem.id,
        );
      });
    }
  }

  Future<void> _toggleWatchlist() async {
    try {
      final wasAdded = !isInWatchlist;

      if (isInWatchlist) {
        await DBHelper.removeFromWatchlist(widget.seriesItem.id);
      } else {
        await DBHelper.addToWatchlist(widget.seriesItem);
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

  void _playEpisode(Episode episode) {
    final season = seasons[selectedSeasonIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InAppVideoPlayerScreen(
          title:
              '${widget.seriesItem.title} - S${season.seasonNumber}E${episode.episodeNumber}: ${episode.name}',
          tmdbId: widget.seriesItem.id.toString(),
          isMovie: false,
          season: season.seasonNumber,
          episode: episode.episodeNumber,
        ),
      ),
    );
  }

  String getYear() {
    final firstAirDate = seriesDetails?['first_air_date'];
    if (firstAirDate != null && firstAirDate.toString().length >= 4) {
      return firstAirDate.toString().substring(0, 4);
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
                slivers: [
                  buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildDetailsSection(),
                        if (cast.isNotEmpty) buildCastSection(),
                        if (seasons.isNotEmpty) buildSeasonsSection(),
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
            expandedHeight: 350,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.grey[800]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster and title skeleton
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 150,
                        color: Colors.grey[800],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 24, width: 150, color: Colors.grey[800]),
                            const SizedBox(height: 8),
                            Container(height: 16, width: 100, color: Colors.grey[800]),
                            const SizedBox(height: 8),
                            Container(height: 16, width: 80, color: Colors.grey[800]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Overview skeleton
                  Container(height: 24, width: 100, color: Colors.grey[800]),
                  const SizedBox(height: 12),
                  ...List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(height: 12, color: Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Cast section skeleton
                  Container(height: 24, width: 80, color: Colors.grey[800]),
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
                        child: Container(
                          height: 160,
                          color: Colors.grey[800],
                        ),
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

  Widget buildSliverAppBar() {
    final backdropPath =
        seriesDetails?['backdrop_path'] ?? widget.seriesItem.backdropPath;
    final posterPath =
        seriesDetails?['poster_path'] ?? widget.seriesItem.posterPath;

    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (backdropPath != null && backdropPath.isNotEmpty)
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
                    child: posterPath != null && posterPath.isNotEmpty
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
                            child: const Icon(Icons.tv),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          seriesDetails?['name'] ?? widget.seriesItem.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                              '${seriesDetails?['vote_average']?.toStringAsFixed(1) ?? widget.seriesItem.rating.toStringAsFixed(1)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            if (seriesDetails?['number_of_seasons'] != null)
                              Text(
                                '${seriesDetails!['number_of_seasons']} Seasons',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: _toggleWatchlist,
                              icon: Icon(
                                isInWatchlist
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: isInWatchlist
                                    ? Colors.red
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: currentEpisodes.isNotEmpty
                                ? () => _playEpisode(currentEpisodes.first)
                                : null,
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
            seriesDetails?['overview'] ??
                widget.seriesItem.overview ??
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
    final firstAirDate = seriesDetails?['first_air_date'];
    final lastAirDate = seriesDetails?['last_air_date'];
    final genres = (seriesDetails?['genres'] as List<dynamic>?)
        ?.map((g) => g['name'].toString())
        .join(', ');

    return Column(
      children: [
        if (firstAirDate != null)
          buildInfoRow('First Air Date', formatDate(firstAirDate)),
        if (lastAirDate != null && lastAirDate != firstAirDate)
          buildInfoRow('Last Air Date', formatDate(lastAirDate)),
        if (genres != null) buildInfoRow('Genres', genres),
        buildInfoRow(
          'Language',
          seriesDetails?['original_language']?.toUpperCase() ?? 'N/A',
        ),
        buildInfoRow('Status', seriesDetails?['status'] ?? 'Unknown'),
        if (seriesDetails?['episode_run_time'] != null &&
            (seriesDetails!['episode_run_time'] as List).isNotEmpty)
          buildInfoRow(
            'Episode Runtime',
            '~${seriesDetails!['episode_run_time'][0]} minutes',
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
            width: 120,
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

  Widget buildSeasonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Seasons & Episodes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: seasons.length,
              itemBuilder: (context, index) {
                final season = seasons[index];
                final isSelected = index == selectedSeasonIndex;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Text('Season ${season.seasonNumber}'),
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
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (isLoadingEpisodes)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.red),
            ),
          )
        else if (currentEpisodes.isNotEmpty)
          ...currentEpisodes.map(
            (episode) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () => _playEpisode(episode),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 120,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(8),
                          ),
                          color: const Color(0xFF2A2A2A),
                        ),
                        child: episode.stillPath.isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(8),
                                ),
                                child: Image.network(
                                  'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.play_circle_outline,
                                color: Colors.white54,
                                size: 40,
                              ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${episode.episodeNumber}. ',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      episode.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (episode.overview.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  episode.overview,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No episodes available',
                style: TextStyle(color: Colors.grey),
              ),
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
                OnStreamSeriesScreen(
                    seriesItem: Movie.fromJson(item),
                    ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                           position: Tween<Offset>(
                             begin: const Offset(1.0, 0.0),
                             end: Offset.zero,
                           ).animate(CurvedAnimation(
                             parent: animation,
                             curve: Curves.fastOutSlowIn,
                           )),
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
                                child: const Icon(Icons.tv, color: Colors.grey),
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
}
