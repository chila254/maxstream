import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/movie.dart';
import '../../models/series.dart';
import '../../services/tmdb_api_service.dart';
import '../../database/db_helper.dart';
import '../../utils/tv_utils.dart';
import 'tv_video_player_screen.dart';

class TvSeriesScreen extends StatefulWidget {
  final Movie seriesItem;

  const TvSeriesScreen({super.key, required this.seriesItem});

  @override
  State<TvSeriesScreen> createState() => _TvSeriesScreenState();
}

class _TvSeriesScreenState extends State<TvSeriesScreen> {
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
              .where((season) => season.seasonNumber > 0)
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
    }
  }

  void _playEpisode(Episode episode) {
    final season = seasons[selectedSeasonIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvVideoPlayerScreen(
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
        backgroundColor: const Color(0xFF121212),
        body: isLoading
            ? _buildLoadingShimmer()
            : CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailsSection(),
                        if (cast.isNotEmpty) _buildCastSection(),
                        _buildEpisodesSection(),
                        if (recommendations.isNotEmpty)
                          _buildRecommendationsSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
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

  Widget _buildSliverAppBar() {
    final backdropPath = seriesDetails?['backdrop_path'] ?? widget.seriesItem.backdropPath;

    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (backdropPath.isNotEmpty)
              Image.network(
                'https://image.tmdb.org/t/p/w1280$backdropPath',
                fit: BoxFit.cover,
              )
            else
              Container(color: Colors.grey[800]),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    final fontSize = TvUtils.responsiveFontSize(24, context, maxSize: 32);
    final padding = TvUtils.responsivePadding(24, context);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.seriesItem.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                getYear(),
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: TvUtils.responsiveFontSize(18, context),
                ),
              ),
              const SizedBox(width: 16),
              if (seriesDetails?['vote_average'] != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${seriesDetails!['vote_average'].toStringAsFixed(1)}/10',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TvUtils.responsiveFontSize(18, context),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  'Watch Now',
                  style: TextStyle(
                    fontSize: TvUtils.responsiveFontSize(18, context),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: padding * 0.6,
                  ),
                ),
                onPressed: currentEpisodes.isNotEmpty
                    ? () => _playEpisode(currentEpisodes[0])
                    : null,
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: Icon(
                  isInWatchlist ? Icons.favorite : Icons.favorite_border,
                ),
                label: Text(
                  'Watchlist',
                  style: TextStyle(
                    fontSize: TvUtils.responsiveFontSize(18, context),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: padding * 0.6,
                  ),
                ),
                onPressed: _toggleWatchlist,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (seriesDetails?['overview'] != null)
            Text(
              seriesDetails!['overview'],
              style: TextStyle(
                color: Colors.white,
                fontSize: TvUtils.responsiveFontSize(16, context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCastSection() {
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
          child: Text(
            'Cast',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: TvUtils.responsivePadding(24, context),
            ),
            itemCount: cast.take(10).length,
            itemBuilder: (context, index) {
              final actor = cast[index];
              return Container(
                width: 180,
                margin: EdgeInsets.only(
                  right: TvUtils.responsivePadding(20, context),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: actor['profile_path'] != null
                          ? Image.network(
                              TmdbApiService.getProfileUrl(actor['profile_path']),
                              width: 180,
                              height: 180,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 180,
                              height: 180,
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 60,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      actor['name'] ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TvUtils.responsiveFontSize(16, context),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
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

  Widget _buildEpisodesSection() {
    final padding = TvUtils.responsivePadding(24, context);
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Text(
            'Episodes',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: seasons.length,
              itemBuilder: (context, index) {
                final season = seasons[index];
                final isSelected = index == selectedSeasonIndex;

                return Padding(
                  padding: EdgeInsets.only(
                    right: TvUtils.responsivePadding(12, context),
                  ),
                  child: ChoiceChip(
                    label: Text(
                      'Season ${season.seasonNumber}',
                      style: TextStyle(
                        fontSize: TvUtils.responsiveFontSize(16, context),
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
                      fontSize: TvUtils.responsiveFontSize(16, context),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (isLoadingEpisodes)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.red),
            ),
          )
        else if (currentEpisodes.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Column(
              children: currentEpisodes
                  .map(
                    (episode) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () => _playEpisode(episode),
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
                                        borderRadius:
                                            const BorderRadius.horizontal(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${episode.episodeNumber}. ',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: TvUtils
                                                  .responsiveFontSize(18,
                                                      context),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              episode.name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                                fontSize: TvUtils
                                                    .responsiveFontSize(18,
                                                        context),
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
                                            fontSize: TvUtils
                                                .responsiveFontSize(14,
                                                    context),
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
                      ),
                    ),
                  )
                  .toList(),
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

  Widget _buildRecommendationsSection() {
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);
    final padding = TvUtils.responsivePadding(24, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Text(
            'More Like This',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: recommendations.take(10).length,
            itemBuilder: (context, index) {
              final item = recommendations[index];
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
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item['poster_path'] != null
                            ? Image.network(
                                TmdbApiService.getPosterUrl(
                                  item['poster_path'],
                                ),
                                width: 180,
                                height: 270,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 180,
                                height: 270,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.tv,
                                  color: Colors.grey,
                                  size: 60,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TvUtils.responsiveFontSize(14, context),
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
