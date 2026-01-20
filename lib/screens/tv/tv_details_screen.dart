import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../database/db_helper.dart';
import '../../models/movie.dart';
import '../../models/series.dart';
import '../../services/tmdb_api_service.dart';
import '../../utils/tv_utils.dart';
import 'tv_video_player_screen.dart';

class TvDetailsScreen extends StatefulWidget {
  final Movie item;
  final String mediaType;

  const TvDetailsScreen({
    super.key,
    required this.item,
    required this.mediaType,
  });

  @override
  State<TvDetailsScreen> createState() => _TvDetailsScreenState();
}

class _TvDetailsScreenState extends State<TvDetailsScreen> {
  YoutubePlayerController? _youtubeController;
  bool isSaved = false;
  bool isLoading = true;
  String? trailerUrl;
  Map<String, dynamic>? details;
  List<Map<String, dynamic>> cast = [];
  List<Map<String, dynamic>> recommendations = [];
  List<Season> seasons = [];
  List<Episode> currentEpisodes = [];
  int selectedSeasonIndex = 0;
  bool isLoadingEpisodes = false;
  String? seriesStatus;

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
      final isMovie = widget.mediaType == 'movie';
      final detailsData = isMovie
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
          
          // Load seasons for TV series
          if (!isMovie && detailsData['seasons'] != null) {
            seasons = (detailsData['seasons'] as List)
                .map((season) => Season.fromJson(season))
                .where((season) => season.seasonNumber > 0)
                .toList();
            seriesStatus = detailsData['status'] ?? 'Unknown';
            selectedSeasonIndex = 0;
            
            // Load episodes for first season
            if (seasons.isNotEmpty) {
              _loadSeasonEpisodes(seasons[0].seasonNumber);
            }
          }
        });

        final trailerUrlFromApi = await TmdbApiService.getTrailerUrl(
          id,
          isMovie: isMovie,
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

  Future<void> _loadSeasonEpisodes(int seasonNumber) async {
    setState(() {
      isLoadingEpisodes = true;
    });

    try {
      final episodesData = await TmdbApiService.getSeasonEpisodes(
        int.parse(widget.item.id),
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

  Future<void> _toggleWatchlist() async {
    try {
      final wasAdded = !isSaved;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTvSeries = widget.mediaType == 'tv';
    
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
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                        if (isTvSeries && seasons.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildSeasonsSection(),
                          const SizedBox(height: 24),
                          _buildEpisodesSection(),
                        ],
                        const SizedBox(height: 32),
                        _buildInfoSection(),
                        if (cast.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildCastSection(),
                        ],
                        if (recommendations.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildRecommendationsSection(),
                        ],
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
    final backdropPath = details?['backdrop_path'] ?? widget.item.backdropPath;

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
    final fontSize = TvUtils.responsiveFontSize(28, context, maxSize: 36);
    final padding = TvUtils.responsivePadding(24, context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.item.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Rating and Year
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.item.rating.toStringAsFixed(1)}/10',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: TvUtils.responsiveFontSize(14, context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                getYear(),
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: TvUtils.responsiveFontSize(14, context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          if (details?['overview'] != null)
            Text(
              details!['overview'],
              style: TextStyle(
                color: Colors.white,
                fontSize: TvUtils.responsiveFontSize(16, context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final padding = TvUtils.responsivePadding(24, context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
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
                horizontal: padding * 0.8,
                vertical: padding * 0.5,
              ),
            ),
            onPressed: () => playContent(),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: Icon(
              isSaved ? Icons.favorite : Icons.favorite_border,
            ),
            label: Text(
              'Add to My List',
              style: TextStyle(
                fontSize: TvUtils.responsiveFontSize(18, context),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              padding: EdgeInsets.symmetric(
                horizontal: padding * 0.8,
                vertical: padding * 0.5,
              ),
            ),
            onPressed: _toggleWatchlist,
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonsSection() {
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);
    final padding = TvUtils.responsivePadding(24, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Text(
            'Seasons',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
              seasons.length,
              (index) {
                final season = seasons[index];
                final isSelected = index == selectedSeasonIndex;
                return FilterChip(
                  label: Text(
                    season.name,
                    style: TextStyle(
                      fontSize:
                          TvUtils.responsiveFontSize(14, context),
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
                    fontSize:
                        TvUtils.responsiveFontSize(14, context),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodesSection() {
    final padding = TvUtils.responsivePadding(24, context);
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);

    if (isLoadingEpisodes) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: Colors.red),
          ),
        ),
      );
    }

    if (currentEpisodes.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No episodes available',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Episodes',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...currentEpisodes.map((episode) {
            return _buildEpisodeCard(episode);
          }),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(Episode episode) {
    final padding = TvUtils.responsivePadding(16, context);
    final hasAirDate = episode.stillPath.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Episode still/poster with play overlay
            Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                color: const Color(0xFF2A2A2A),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasAirDate)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      child: Image.network(
                        'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      child: Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white54,
                          size: 60,
                        ),
                      ),
                    ),
                  // Play overlay - only show if aired
                  if (hasAirDate)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Episode info
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
                            fontSize:
                                TvUtils.responsiveFontSize(18, context),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            episode.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize:
                                  TvUtils.responsiveFontSize(16, context),
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
                          fontSize:
                              TvUtils.responsiveFontSize(14, context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Play icon or coming soon date
            Padding(
              padding: const EdgeInsets.all(16),
              child: hasAirDate
                  ? Icon(
                      Icons.play_arrow,
                      color: Colors.red,
                      size: TvUtils.responsiveFontSize(32, context),
                    )
                  : Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize:
                            TvUtils.responsiveFontSize(12, context),
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final padding = TvUtils.responsivePadding(24, context);
    final isTvSeries = widget.mediaType == 'tv';

    final infoItems = <String>[];
    
    if (cast.isNotEmpty) {
      final castNames = cast.take(3).map((c) => c['name']).join(', ');
      infoItems.add('Cast: $castNames');
    }
    
    if (widget.item.genres.isNotEmpty) {
      infoItems.add('Genre: ${widget.item.genres.join(', ')}');
    }
    
    if (details?['production_companies'] != null) {
      final companies = (details!['production_companies'] as List)
          .take(2)
          .map((c) => c['name'])
          .join(', ');
      if (companies.isNotEmpty) {
        infoItems.add('Production: $companies');
      }
    }
    
    if (widget.item.country.isNotEmpty) {
      infoItems.add('Country: ${widget.item.country}');
    }
    
    if (isTvSeries && seriesStatus != null) {
      infoItems.add('Status: $seriesStatus');
    }

    if (infoItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (String info in infoItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                info,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: TvUtils.responsiveFontSize(14, context),
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCastSection() {
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);
    final padding = TvUtils.responsivePadding(24, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
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
            padding: EdgeInsets.symmetric(horizontal: padding),
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
                              TmdbApiService.getProfileUrl(
                                actor['profile_path'],
                              ),
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
                      builder: (context) => TvDetailsScreen(
                        item: Movie.fromJson(item),
                        mediaType: item['media_type'] ?? widget.mediaType,
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
                                  Icons.movie,
                                  color: Colors.grey,
                                  size: 60,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['title'] ?? item['name'] ?? 'Unknown',
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

  String getYear() {
    final date = details?['release_date'] ?? details?['first_air_date'];
    if (date != null && date.length >= 4) {
      return date.substring(0, 4);
    }
    return 'N/A';
  }

  void playContent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvVideoPlayerScreen(
          title: widget.item.title,
          tmdbId: widget.item.id.toString(),
          isMovie: widget.mediaType == 'movie',
        ),
      ),
    );
  }
}
